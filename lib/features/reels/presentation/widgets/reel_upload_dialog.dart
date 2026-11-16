import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../shared/theme/colors.dart';
import '../../data/models/reel_model.dart';
import '../reel_screen.dart';

/// Upload dialog for reels (video) and photo posts.
/// - [isPhoto] switches to the photo endpoint and image picker.
/// - [professionalId] set → professional self-upload (unchanged behaviour).
/// - Otherwise → customer upload: requires completed-booking options loaded
///   from GET /reels/upload-options (professionals + services).
class ReelUploadDialog extends StatefulWidget {
  final String? professionalId;
  final bool isPhoto;
  final bool isProfessional;

  const ReelUploadDialog({
    super.key,
    this.professionalId,
    this.isPhoto = false,
    this.isProfessional = false,
  });

  /// Customer-facing entry point: verifies the user has at least one
  /// completed booking before opening the upload form.
  static Future<void> openForCustomer(
    BuildContext context, {
    bool isPhoto = false,
  }) async {
    try {
      final res = await ApiService.dio
          .get('/reels/upload-options')
          .timeout(const Duration(seconds: 20));
      final pros = (res.data['data']?['professionals'] as List? ?? []);
      if (pros.isEmpty) {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Upload unavailable'),
              content: const Text('you have no complete Booking yet'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(_),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return;
      }
    } catch (_) {
      // If the check fails, still open the dialog — the backend enforces
      // the rule server-side anyway.
    }
    if (context.mounted) {
      showDialog(
        context: context,
        builder: (_) => ReelUploadDialog(isPhoto: isPhoto),
      );
    }
  }

  @override
  State<ReelUploadDialog> createState() => _ReelUploadDialogState();
}

class _ReelUploadDialogState extends State<ReelUploadDialog> {
  final ImagePicker _picker = ImagePicker();
  XFile? _mediaFile;
  VideoPlayerController? _controller;
  bool _videoFailed = false;
  bool _isUploading = false;
  double _uploadProgress = 0;
  bool _isLoadingOptions = false;
  bool _optionsError = false;
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  List<Map<String, dynamic>> _professionals = [];
  List<Map<String, dynamic>> _services = [];
  Map<String, dynamic>? _selectedPro;
  Map<String, dynamic>? _selectedService;
  bool _serviceDropdownOpen = false;

  bool get _isProSelfUpload =>
      widget.professionalId != null || widget.isProfessional;

  @override
  void initState() {
    super.initState();
    if (!_isProSelfUpload) _loadOptions();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    setState(() {
      _isLoadingOptions = true;
      _optionsError = false;
    });
    try {
      // Hard timeout: dio's connect/receive timeouts don't cover DNS stalls,
      // which left this dialog on a spinner forever ("blank white dialog").
      final res = await ApiService.dio
          .get('/reels/upload-options')
          .timeout(const Duration(seconds: 20));
      final data = res.data['data'] as Map<String, dynamic>?;
      if (mounted) {
        setState(() {
          _professionals = (data?['professionals'] as List? ?? [])
              .cast<Map<String, dynamic>>();
          _services =
              (data?['services'] as List? ?? []).cast<Map<String, dynamic>>();
        });
      }
    } catch (_) {
      if (mounted) setState(() => _optionsError = true);
    } finally {
      if (mounted) setState(() => _isLoadingOptions = false);
    }
  }

  Future<void> _pickMedia() async {
    try {
      if (widget.isPhoto) {
        final file = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
        );
        if (file != null) {
          setState(() => _mediaFile = file);
          _controller?.dispose();
          _controller = null;
        }
      } else {
        final video = await _picker.pickVideo(source: ImageSource.gallery);
        if (video != null) {
          setState(() {
            _mediaFile = video;
            _videoFailed = false;
          });
          _initializeVideo(video);
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the photo picker')),
        );
      }
    }
  }

  Future<void> _initializeVideo(XFile video) async {
    _controller?.dispose();
    final controller = VideoPlayerController.file(File(video.path));
    _controller = controller;
    try {
      await controller.initialize();
      if (mounted && _controller == controller) setState(() {});
    } catch (_) {
      // Decoder failures (e.g. MediaCodec) must not leave a broken
      // controller mounted or surface as an unhandled async error.
      controller.dispose();
      if (mounted && _controller == controller) {
        setState(() {
          _controller = null;
          _videoFailed = true;
        });
      }
    }
  }

  Future<String?> _resolveProfessionalId() async {
    if (widget.professionalId != null) return widget.professionalId;
    if (widget.isProfessional) {
      try {
        final response = await ApiService.dio.get('/professionals/me');
        final data = response.data['data'];
        final id = data is Map
            ? (data['id'] ?? data['professional']?['id'])?.toString()
            : null;
        if (id != null) return id;
      } catch (_) {}
      return null;
    }
    return _selectedPro?['id']?.toString();
  }

  // Services limited to bookings with the selected professional
  List<Map<String, dynamic>> get _servicesForSelectedPro {
    if (_selectedPro == null) return const [];
    final proId = _selectedPro!['id']?.toString();
    return _services
        .where((s) => s['professionalId']?.toString() == proId)
        .toList();
  }

  Widget _serviceOptionTile(Map<String, dynamic> s) {
    final selected = _selectedService?['id'] == s['id'];
    return ListTile(
      dense: true,
      selected: selected,
      title: Text(
        s['name']?.toString() ?? 'Service',
        style: const TextStyle(fontSize: 14),
      ),
      trailing: selected
          ? const Icon(Icons.check, color: GlayaColors.berry, size: 18)
          : null,
      onTap: () {
        setState(() {
          _selectedService = s;
          _serviceDropdownOpen = false;
        });
      },
    );
  }

  bool get _canUpload {
    if (_mediaFile == null) return false;
    if (_titleController.text.trim().isEmpty) return false;
    if (_descriptionController.text.trim().isEmpty) return false;
    if (_isProSelfUpload) return true;
    return _selectedPro != null && _selectedService != null;
  }

  Future<void> _upload() async {
    if (!_canUpload || _isUploading) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
    });
    try {
      final professionalId = await _resolveProfessionalId();
      final endpoint = widget.isPhoto ? '/reels/upload-photo' : '/reels/upload';
      final fileField = widget.isPhoto ? 'photo' : 'video';
      final formData = await ApiService.buildMultipart(
        fields: {
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          if (professionalId != null) 'taggedProfessionalId': professionalId,
          if (_selectedService != null)
            'serviceId': _selectedService!['id'].toString(),
        },
        filePath: _mediaFile!.path,
        fileField: fileField,
      );

      final response = await ApiService.dio.post(
        endpoint,
        data: formData,
        options: ApiService.multipartOptions(),
        onSendProgress: (sent, total) {
          if (total > 0 && mounted) {
            setState(() => _uploadProgress = sent / total);
          }
        },
      );

      if (mounted) {
        // Parse the created reel so we can open it in the viewer.
        Reel? reel;
        try {
          final raw = response.data;
          final payload = raw is Map
              ? (raw['data'] is Map ? raw['data'] : raw)
              : null;
          if (payload is Map) {
            final map = Map<String, dynamic>.from(payload);
            // Ensure the viewer treats photo uploads as photos even if
            // the API response omits mediaType.
            if (widget.isPhoto && map['mediaType'] == null) {
              map['mediaType'] = 'photo';
            }
            // Cleartext URLs fail on Android — upgrade to https.
            final u = map['videoUrl'];
            if (u is String && u.startsWith('http://')) {
              map['videoUrl'] = 'https://${u.substring(7)}';
            }
            reel = Reel.fromJson(map);
          }
        } catch (_) {}

        // Capture messenger/navigator before popping — the dialog's
        // context is deactivated by Navigator.pop.
        final messenger = ScaffoldMessenger.of(context);
        final navigator = Navigator.of(context);
        navigator.pop();
        messenger.showSnackBar(
          SnackBar(
            content: Text(widget.isPhoto
                ? 'Photo uploaded successfully'
                : 'Reel uploaded successfully'),
          ),
        );
        if (reel != null && reel.id.isNotEmpty && reel.videoUrl.isNotEmpty) {
          navigator.push(
            MaterialPageRoute(
              builder: (_) => ReelScreen(reels: [reel!], initialIndex: 0),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final noun = widget.isPhoto ? 'Photo' : 'Reel';
    // AlertDialog measures content via intrinsics, which LayoutBuilder
    // cannot answer — derive the options width from the screen instead.
    final optionsWidth =
        (MediaQuery.sizeOf(context).width - 96).clamp(240.0, 480.0).toDouble();
    // Finite width for the photo preview — width: double.infinity makes
    // RenderImage report an infinite intrinsic width, which crashes
    // AlertDialog's IntrinsicWidth layout pass.
    final mediaWidth =
        (MediaQuery.sizeOf(context).width - 128).clamp(200.0, 600.0).toDouble();
    return AlertDialog(
      title: Text('Upload $noun'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Media picker
            if (_mediaFile != null && !widget.isPhoto && _videoFailed)
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 40, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('Could not preview this video',
                          style: TextStyle(color: Colors.black54)),
                    ],
                  ),
                ),
              )
            else if (_mediaFile != null &&
                !widget.isPhoto &&
                _controller != null &&
                _controller!.value.isInitialized)
              AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              )
            else if (_mediaFile != null &&
                !widget.isPhoto &&
                _controller != null)
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(child: CircularProgressIndicator()),
              )
            else if (_mediaFile != null && widget.isPhoto)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(_mediaFile!.path),
                  height: 200,
                  width: mediaWidth,
                  fit: BoxFit.cover,
                  // Decode at preview size — full-res decode of a modern
                  // photo can OOM the app.
                  cacheWidth: 800,
                  errorBuilder: (_, __, ___) => Container(
                    height: 200,
                    width: mediaWidth,
                    color: Colors.grey[300],
                    child: const Icon(Icons.broken_image,
                        color: Colors.grey, size: 40),
                  ),
                ),
              )
            else
              GestureDetector(
                onTap: _pickMedia,
                child: Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          widget.isPhoto ? Icons.photo : Icons.videocam,
                          size: 48,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 8),
                        Text(widget.isPhoto
                            ? 'Tap to select photo'
                            : 'Tap to select video'),
                      ],
                    ),
                  ),
                ),
              ),
            if (_isUploading) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _uploadProgress,
                  minHeight: 6,
                  color: GlayaColors.berry,
                  backgroundColor: Colors.grey[300],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Uploading… ${(_uploadProgress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.black),
              decoration: const InputDecoration(
                labelText: 'Title *',
                labelStyle: TextStyle(color: Colors.black54),
                hintStyle: TextStyle(color: Colors.black38),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              style: const TextStyle(color: Colors.black),
              decoration: const InputDecoration(
                labelText: 'Description *',
                labelStyle: TextStyle(color: Colors.black54),
                hintStyle: TextStyle(color: Colors.black38),
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            // Professional picker (customer uploads only)
            if (!_isProSelfUpload) ...[
              const SizedBox(height: 16),
              if (_isLoadingOptions)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('Loading professionals...',
                            style:
                                TextStyle(fontSize: 13, color: Colors.black54)),
                      ],
                    ),
                  ),
                )
              else if (_optionsError)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Could not load professionals. Check your connection.',
                          style: TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                      ),
                      TextButton(
                        onPressed: _loadOptions,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              else ...[
                const Text(
                  'Professional *',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                // Autocomplete renders options in an overlay anchored under
                // the field — a real dropdown — instead of growing an inline
                // list inside the dialog's scroll view.
                Autocomplete<Map<String, dynamic>>(
                  displayStringForOption: (p) =>
                      p['name']?.toString() ?? 'Professional',
                  optionsBuilder: (value) {
                    final q = value.text.trim().toLowerCase();
                    if (q.isEmpty) return _professionals;
                    return _professionals.where((p) =>
                        (p['name']?.toString() ?? '')
                            .toLowerCase()
                            .contains(q));
                  },
                  onSelected: (p) {
                    setState(() {
                      _selectedPro = p;
                      _selectedService = null;
                      _serviceDropdownOpen = false;
                    });
                  },
                  fieldViewBuilder:
                      (context, controller, focusNode, onFieldSubmitted) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onChanged: (v) {
                        final selName = _selectedPro?['name']?.toString();
                        if (selName != null && v.trim() != selName) {
                          setState(() => _selectedPro = null);
                        }
                      },
                      style: const TextStyle(color: Colors.black, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search professionals...',
                        hintStyle: const TextStyle(color: Colors.black38),
                        prefixIcon: const Icon(Icons.search, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        isDense: true,
                      ),
                    );
                  },
                  optionsViewBuilder: (context, onSelected, options) {
                    final list = options.toList();
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: optionsWidth,
                          child: list.isEmpty
                              ? const SizedBox(
                                  height: 48,
                                  child: Center(
                                    child: Text('No professionals found',
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.black54)),
                                  ),
                                )
                              : SizedBox(
                                  height: (list.length * 56)
                                      .clamp(56, 224)
                                      .toDouble(),
                                  child: ListView.builder(
                                    itemExtent: 56,
                                    itemCount: list.length,
                                    itemBuilder: (_, i) {
                                      final p = list[i];
                                      final selected =
                                          _selectedPro?['id'] == p['id'];
                                      return ListTile(
                                        dense: true,
                                        selected: selected,
                                        title: Text(
                                          p['name']?.toString() ??
                                              'Professional',
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                        trailing: selected
                                            ? const Icon(Icons.check,
                                                color: GlayaColors.berry,
                                                size: 18)
                                            : null,
                                        onTap: () => onSelected(p),
                                      );
                                    },
                                  ),
                                ),
                        ),
                      ),
                    );
                  },
                ),
                // Service picker — only services booked with selected pro.
                // Custom dropdown (no DropdownButtonFormField): its internal
                // shrink-wrapping viewport crashes inside dialogs when the
                // keyboard opens/closes (intrinsic-dimensions assertion).
                const SizedBox(height: 16),
                const Text(
                  'Service *',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: _selectedPro == null
                      ? null
                      : () => setState(() {
                            _serviceDropdownOpen = !_serviceDropdownOpen;
                          }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _selectedService?['name']?.toString() ??
                                (_selectedPro == null
                                    ? 'Select a professional first'
                                    : 'Select a service'),
                            style: TextStyle(
                              fontSize: 14,
                              color: _selectedService != null
                                  ? Colors.black
                                  : Colors.black38,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          _serviceDropdownOpen
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size: 20,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_serviceDropdownOpen && _selectedPro != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _servicesForSelectedPro.isEmpty
                        ? const SizedBox(
                            height: 48,
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: Text(
                                'No services booked with this professional',
                                style: TextStyle(
                                    fontSize: 13, color: Colors.black54),
                              ),
                            ),
                          )
                        : SizedBox(
                            height: (_servicesForSelectedPro.length * 56)
                                .clamp(56, 168)
                                .toDouble(),
                            // SingleChildScrollView + Column: viewports
                            // (ListView/GridView) cannot answer the
                            // IntrinsicWidth query AlertDialog performs.
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (final s in _servicesForSelectedPro)
                                    _serviceOptionTile(s),
                                ],
                              ),
                            ),
                          ),
                  ),
                ],
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        // Only the button listens to text changes — rebuilding the whole
        // dialog (and its focused EditableText) on every keystroke corrupts
        // the render tree while the keyboard animates view insets.
        AnimatedBuilder(
          animation:
              Listenable.merge([_titleController, _descriptionController]),
          builder: (context, _) => ElevatedButton(
            onPressed: (_canUpload && !_isUploading) ? _upload : null,
            child: _isUploading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Upload'),
          ),
        ),
      ],
    );
  }
}
