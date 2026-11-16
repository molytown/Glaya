import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../shared/services/config_service.dart';
import '../../../../shared/theme/colors.dart';
import '../../../features/home/models/category.dart';

class PortfolioUploadDialog extends ConsumerStatefulWidget {
  const PortfolioUploadDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const PortfolioUploadDialog(),
    );
  }

  @override
  ConsumerState<PortfolioUploadDialog> createState() =>
      _PortfolioUploadDialogState();
}

class _PortfolioUploadDialogState extends ConsumerState<PortfolioUploadDialog> {
  final ImagePicker _picker = ImagePicker();
  List<XFile> _pickedFiles = [];
  List<Uint8List> _pickedFileBytes = [];
  List<VideoPlayerController?> _videoControllers = [];
  List<bool> _isVideoInitialized = [];
  String? _selectedCategory;
  bool _categoryDropdownOpen = false;
  List<Map<String, dynamic>> _selectedCustomers = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _isUploading = false;
  double _uploadProgress = 0;
  int _lastProgressPercent = -1;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (var controller in _videoControllers) {
      controller?.dispose();
    }
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    try {
      final response = await ApiService.dio
          .get('/users/search', queryParameters: {'q': query});
      setState(() => _searchResults =
          (response.data['data'] as List).cast<Map<String, dynamic>>());
    } catch (e) {
      // Silently fail on search errors
    }
  }

  Future<void> _pickMedia() async {
    final picked = await _picker.pickMultipleMedia();
    if (picked.isEmpty) return;

    final newFiles = <XFile>[];
    final newBytes = <Uint8List>[];
    final newControllers = <VideoPlayerController?>[];
    final newInitialized = <bool>[];

    for (var file in picked) {
      if (_pickedFiles.length + newFiles.length >= 6)
        break; // Max 6 files total

      final bytes = await file.readAsBytes();
      final isVideo = file.mimeType?.startsWith('video/') ?? false;

      newFiles.add(file);
      newBytes.add(bytes);

      if (isVideo) {
        // file.path is a local path — must use a file controller, and a
        // decoder failure must not abort picking the remaining files.
        try {
          final controller = VideoPlayerController.file(File(file.path));
          await controller.initialize();
          newControllers.add(controller);
          newInitialized.add(true);
        } catch (_) {
          newControllers.add(null);
          newInitialized.add(false);
        }
      } else {
        newControllers.add(null);
        newInitialized.add(false);
      }
    }

    setState(() {
      _pickedFiles.addAll(newFiles);
      _pickedFileBytes.addAll(newBytes);
      _videoControllers.addAll(newControllers);
      _isVideoInitialized.addAll(newInitialized);
    });
  }

  void _removeFile(int index) {
    _videoControllers[index]?.dispose();
    setState(() {
      _pickedFiles.removeAt(index);
      _pickedFileBytes.removeAt(index);
      _videoControllers.removeAt(index);
      _isVideoInitialized.removeAt(index);
    });
  }

  void _addCustomer(Map<String, dynamic> customer) {
    if (_selectedCustomers.any((c) => c['id'] == customer['id'])) return;
    setState(() {
      _selectedCustomers.add(customer);
      _searchResults = [];
      _searchController.clear();
    });
  }

  void _removeCustomer(String customerId) {
    setState(() {
      _selectedCustomers.removeWhere((c) => c['id'] == customerId);
    });
  }

  Widget _categoryOptionTile(HomeCategory category) {
    final selected = _selectedCategory == category.label;
    return ListTile(
      dense: true,
      selected: selected,
      leading: Icon(category.icon, size: 20, color: Colors.grey[700]),
      title: Text(category.label, style: const TextStyle(fontSize: 14)),
      trailing: selected
          ? const Icon(Icons.check, color: GlayaColors.berry, size: 18)
          : null,
      onTap: () {
        setState(() {
          _selectedCategory = category.label;
          _categoryDropdownOpen = false;
        });
      },
    );
  }

  Widget _customerResultTile(Map<String, dynamic> user) {
    return ListTile(
      leading: user['photoUrl'] != null
          ? CircleAvatar(
              backgroundImage: NetworkImage(
                  ConfigService().replaceLocalhost(user['photoUrl'])),
            )
          : const CircleAvatar(child: Icon(Icons.person)),
      title: Text(user['name']),
      subtitle: Text(user['email'] ?? ''),
      onTap: () => _addCustomer(user),
    );
  }

  Widget _previewTile(int index) {
    final file = _pickedFiles[index];
    final isVideo = file.mimeType?.startsWith('video/') ?? false;
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: isVideo && _isVideoInitialized[index]
                ? AspectRatio(
                    aspectRatio: _videoControllers[index]!.value.aspectRatio,
                    child: VideoPlayer(_videoControllers[index]!),
                  )
                : Image.memory(
                    _pickedFileBytes[index],
                    fit: BoxFit.cover,
                    // Thumbnail-sized decode — full-res bitmaps OOM.
                    cacheWidth: 300,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.videocam, color: Colors.grey),
                    ),
                  ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => _removeFile(index),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ),
        if (isVideo)
          const Positioned(
            bottom: 4,
            right: 4,
            child: Icon(Icons.play_circle, color: Colors.white, size: 24),
          ),
      ],
    );
  }

  Future<void> _uploadGallery() async {
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    if (_pickedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one file')),
      );
      return;
    }

    print('DEBUG: Starting gallery upload');
    print('DEBUG: Selected category: $_selectedCategory');
    print('DEBUG: Number of files: ${_pickedFiles.length}');
    print(
        'DEBUG: Selected customers: ${_selectedCustomers.map((c) => c['id']).toList()}');

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
      _lastProgressPercent = -1;
    });
    try {
      // Create gallery first
      print('DEBUG: Creating gallery...');
      final galleryResponse = await ApiService.dio.post(
        '/professionals/me/portfolio/galleries',
        data: {
          'serviceId': _selectedCategory?.toLowerCase(),
          'customerIds': _selectedCustomers.map((c) => c['id']).toList(),
        },
      );
      print('DEBUG: Gallery creation response: ${galleryResponse.data}');
      final galleryId = galleryResponse.data['data']['id'];
      print('DEBUG: Gallery ID: $galleryId');

      // Upload all media files
      for (int i = 0; i < _pickedFiles.length; i++) {
        final file = _pickedFiles[i];
        final mediaType =
            file.mimeType?.startsWith('video/') ?? false ? 'video' : 'photo';
        print(
            'DEBUG: Uploading file $i/${_pickedFiles.length}: ${file.name}, type: $mediaType');

        final formData = await ApiService.buildMultipart(
          fields: {
            'galleryId': galleryId,
            'mediaType': mediaType,
          },
          filePath: file.path,
          fileBytes: _pickedFileBytes[i],
          fileName: file.name,
          fileField: 'media',
        );

        print(
            'DEBUG: Form data fields: galleryId=$galleryId, mediaType=$mediaType');
        print('DEBUG: File size: ${_pickedFileBytes[i].length} bytes');

        final fileIndex = i;
        final mediaResponse = await ApiService.dio.post(
          '/professionals/me/portfolio/galleries/$galleryId/media',
          data: formData,
          options: ApiService.multipartOptions(),
          onSendProgress: (sent, total) {
            if (total <= 0 || !mounted) return;
            // Aggregate: completed files + fraction of the current file.
            final overall = (fileIndex + sent / total) / _pickedFiles.length;
            final percent = (overall * 100).floor();
            if (percent != _lastProgressPercent) {
              _lastProgressPercent = percent;
              setState(() => _uploadProgress = overall);
            }
          },
        );
        print('DEBUG: Media upload response: ${mediaResponse.data}');
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gallery created successfully')),
        );
      }
    } catch (e) {
      print('DEBUG: Error during gallery upload: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create gallery: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  int get _photoCount => _pickedFiles
      .where((f) => !(f.mimeType?.startsWith('video/') ?? false))
      .length;
  int get _videoCount => _pickedFiles
      .where((f) => f.mimeType?.startsWith('video/') ?? false)
      .length;

  @override
  Widget build(BuildContext context) {
    // AlertDialog measures content via intrinsics, which LayoutBuilder
    // cannot answer — derive the preview grid width from the screen.
    const previewCols = 3;
    const previewSpacing = 8.0;
    final previewWidth =
        (MediaQuery.sizeOf(context).width - 128).clamp(200.0, 600.0).toDouble();
    final previewCell =
        (previewWidth - previewSpacing * (previewCols - 1)) / previewCols;
    return AlertDialog(
      title: const Text('Create Portfolio Gallery'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Dropdown (Required)
              const Text('Category *',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              // Custom dropdown — DropdownButtonFormField's shrink-wrapping
              // menu crashes inside dialogs when the keyboard opens/closes.
              GestureDetector(
                onTap: () => setState(
                    () => _categoryDropdownOpen = !_categoryDropdownOpen),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedCategory ?? 'Select a category',
                          style: TextStyle(
                            fontSize: 14,
                            color: _selectedCategory != null
                                ? Colors.black
                                : Colors.black38,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        _categoryDropdownOpen
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 20,
                        color: Colors.black54,
                      ),
                    ],
                  ),
                ),
              ),
              if (_categoryDropdownOpen) ...[
                const SizedBox(height: 4),
                Builder(builder: (context) {
                  final categories = HomeCategory.defaults
                      .where((c) => c.label != 'More')
                      .toList();
                  return Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    // Viewports can't answer AlertDialog's IntrinsicWidth
                    // query — SingleChildScrollView + Column instead.
                    child: SizedBox(
                      height:
                          (categories.length * 56).clamp(56, 224).toDouble(),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final category in categories)
                              _categoryOptionTile(category),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
              const SizedBox(height: 16),

              // Customer Search
              const Text('Customers (Optional)',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.black),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Search customers by name',
                  hintStyle: TextStyle(color: Colors.black38),
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => _searchUsers(value),
              ),
              const SizedBox(height: 8),

              // Selected Customers
              if (_selectedCustomers.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _selectedCustomers.map((customer) {
                    return Chip(
                      avatar: customer['photoUrl'] != null
                          ? CircleAvatar(
                              backgroundImage: NetworkImage(ConfigService()
                                  .replaceLocalhost(customer['photoUrl'])),
                            )
                          : null,
                      label: Text(customer['name']),
                      deleteIcon: const Icon(Icons.close),
                      onDeleted: () => _removeCustomer(customer['id']),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
              ],

              // Search Results
              if (_searchResults.isNotEmpty) ...[
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SizedBox(
                    height:
                        (_searchResults.length * 72).clamp(72, 216).toDouble(),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final user in _searchResults)
                            _customerResultTile(user),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Upload Counter
              Text(
                '$_photoCount photos / 5, $_videoCount videos / 1',
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: GlayaColors.vibrantPink),
              ),
              const SizedBox(height: 8),

              // Pick Media Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _pickedFiles.length < 6 ? _pickMedia : null,
                  icon: const Icon(Icons.add_photo_alternate),
                  label: Text(_pickedFiles.length >= 6
                      ? 'Maximum files reached'
                      : 'Add Photos/Videos'),
                ),
              ),
              const SizedBox(height: 16),

              // File Previews Grid
              if (_pickedFiles.isNotEmpty) ...[
                // Wrap instead of GridView: viewports can't answer
                // AlertDialog's IntrinsicWidth query.
                Wrap(
                  spacing: previewSpacing,
                  runSpacing: previewSpacing,
                  children: [
                    for (var i = 0; i < _pickedFiles.length; i++)
                      SizedBox(
                        width: previewCell,
                        height: previewCell,
                        child: _previewTile(i),
                      ),
                  ],
                ),
                if (_isUploading) ...[
                  const SizedBox(height: 12),
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
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isUploading ? null : _uploadGallery,
          child: _isUploading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Create Gallery'),
        ),
      ],
    );
  }
}
