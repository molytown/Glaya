import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../../../shared/services/api_service.dart';
import '../../../../shared/services/config_service.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/text_styles.dart';
import '../../../../shared/widgets/bottom_nav.dart';
import '../../auth/presentation/providers/auth_notifier.dart';
import '../../reels/presentation/widgets/reel_upload_dialog.dart';

class Album {
  final String id;
  final String title;
  final String? coverUrl;
  final int mediaCount;
  final bool isDefault;
  final DateTime createdAt;

  Album({
    required this.id,
    required this.title,
    this.coverUrl,
    required this.mediaCount,
    required this.isDefault,
    required this.createdAt,
  });

  factory Album.fromJson(Map<String, dynamic> json) {
    final configService = ConfigService();
    final media = json['media'] as List<dynamic>?;
    final rawCoverUrl = json['coverMedia']?['mediaUrl'] as String?;
    // Transform relative URLs to absolute URLs
    final coverUrl = rawCoverUrl != null
        ? configService.replaceLocalhost(rawCoverUrl)
        : null;
    return Album(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Untitled',
      coverUrl: coverUrl,
      mediaCount: media?.length ?? 0,
      isDefault: json['isDefault'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class PortfolioScreen extends ConsumerStatefulWidget {
  const PortfolioScreen({super.key});

  @override
  ConsumerState<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends ConsumerState<PortfolioScreen> {
  List<Album> _albums = [];
  bool _isLoading = true;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();
  String _mediaType = 'photo';
  String? _selectedAlbumId;
  XFile? _pickedFile;
  Uint8List? _pickedFileBytes;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    print('DEBUG: PortfolioScreen initState called');
    _loadAlbums();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _loadAlbums() async {
    print('DEBUG: Loading albums...');
    try {
      final response = await ApiService.dio.get('/professionals/me/albums');
      print('DEBUG: Response received: ${response.data}');
      final data = response.data['data'] as List<dynamic>?;
      print('DEBUG: Albums data: $data');
      final albums = (data ?? []).map((json) => Album.fromJson(json)).toList();
      print('DEBUG: Parsed albums: $albums');
      setState(() => _albums = albums);
    } catch (e) {
      print('DEBUG: Error loading albums: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load albums: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickMedia() async {
    if (_mediaType == 'photo') {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _pickedFile = picked;
          _pickedFileBytes = bytes;
          _videoController?.dispose();
          _videoController = null;
          _isVideoInitialized = false;
        });
      }
    } else {
      final picked = await _picker.pickVideo(source: ImageSource.gallery);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        _videoController?.dispose();
        _videoController = VideoPlayerController.networkUrl(
          Uri.file(picked.path),
        );
        await _videoController?.initialize();
        setState(() {
          _pickedFile = picked;
          _pickedFileBytes = bytes;
          _isVideoInitialized = true;
        });
      }
    }
  }

  Future<void> _addMedia() async {
    if (_pickedFile == null || _selectedAlbumId == null) return;

    setState(() => _isUploading = true);
    try {
      // Upload directly to album
      final formData = ApiService.buildMultipart(
        fields: {'mediaType': _mediaType},
        filePath: _pickedFile!.path,
        fileBytes: _pickedFileBytes,
        fileName: _pickedFile!.name,
        fileField: 'media',
      );

      await ApiService.dio.post(
        '/professionals/me/albums/$_selectedAlbumId/media',
        data: formData,
        options: ApiService.multipartOptions(),
      );

      await _loadAlbums();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Media added successfully')),
        );
        setState(() {
          _pickedFile = null;
          _pickedFileBytes = null;
          _videoController?.dispose();
          _videoController = null;
          _isVideoInitialized = false;
          _selectedAlbumId = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add media: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _createAlbum() async {
    final controller = TextEditingController();
    String? title;
    String? selectedCategory;

    if (!mounted) return;

    title = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create New Album'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'Album title',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              const Text('Category (optional):',
                  style: TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Select category',
                ),
                items: const [
                  DropdownMenuItem(value: 'hair', child: Text('Hair')),
                  DropdownMenuItem(value: 'nails', child: Text('Nails')),
                  DropdownMenuItem(value: 'makeup', child: Text('Makeup')),
                  DropdownMenuItem(value: 'skincare', child: Text('Skincare')),
                  DropdownMenuItem(value: 'spa', child: Text('Spa')),
                  DropdownMenuItem(value: 'barber', child: Text('Barber')),
                  DropdownMenuItem(
                      value: 'brows & lashes', child: Text('Brows & Lashes')),
                ],
                onChanged: (value) => setState(() => selectedCategory = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (title != null && title.isNotEmpty) {
      try {
        await ApiService.dio.post(
          '/professionals/me/albums',
          data: {
            'title': title,
            if (selectedCategory != null) 'category': selectedCategory,
          },
        );
        await _loadAlbums();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Album created successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          String errorMessage = 'Failed to create album';
          if (e.toString().contains('401')) {
            errorMessage = 'Please log in to create albums';
          } else if (e.toString().contains('network')) {
            errorMessage = 'Network error. Please check your connection';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$errorMessage: ${e.toString()}')),
          );
        }
      }
    }
  }

  Future<void> _deleteAlbum(String albumId) async {
    try {
      await ApiService.dio.delete('/professionals/me/albums/$albumId');
      await _loadAlbums();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Album deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete album: ${e.toString()}')),
        );
      }
    }
  }

  void _showAddMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_photo_alternate),
              title: const Text('Upload to Album'),
              onTap: () {
                Navigator.pop(context);
                _showUploadDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder),
              title: const Text('Create Album'),
              onTap: () {
                Navigator.pop(context);
                _createAlbum();
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Upload Reel'),
              onTap: () {
                Navigator.pop(context);
                _showReelUploadDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showReelUploadDialog() {
    showDialog(
      context: context,
      builder: (context) => const ReelUploadDialog(isProfessional: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Portfolio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddMenu,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _albums.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.photo_library_outlined,
                        size: 64,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No albums yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _createAlbum,
                        child: const Text('Create Your First Album'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAlbums,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1,
                    ),
                    itemCount: _albums.length,
                    itemBuilder: (context, index) {
                      final album = _albums[index];
                      return GestureDetector(
                        onLongPress: () => _showAlbumOptions(album),
                        onTap: () => _viewAlbum(album),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: GlayaColors.berry.withOpacity(0.3),
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (album.coverUrl != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    album.coverUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, error, stack) {
                                      return Container(
                                        color: Colors.grey.withOpacity(0.1),
                                        child: const Icon(
                                          Icons.broken_image,
                                          color: Colors.grey,
                                        ),
                                      );
                                    },
                                  ),
                                )
                              else
                                Container(
                                  color: Colors.grey.withOpacity(0.1),
                                  child: const Icon(
                                    Icons.photo_library,
                                    color: Colors.grey,
                                  ),
                                ),
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withOpacity(0.7),
                                      ],
                                    ),
                                    borderRadius: const BorderRadius.only(
                                      bottomLeft: Radius.circular(12),
                                      bottomRight: Radius.circular(12),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        album.title,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '${album.mediaCount} photos',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (album.isDefault)
                                Positioned(
                                  top: 8,
                                  left: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: GlayaColors.berry,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Default',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
      bottomNavigationBar: user?.role == 'customer'
          ? null
          : GlayaBottomNav(currentIndex: 0, userRole: user?.role),
    );
  }

  void _showAlbumOptions(Album album) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility),
              title: const Text('View Album'),
              onTap: () {
                Navigator.pop(context);
                _viewAlbum(album);
              },
            ),
            if (!album.isDefault)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Delete Album',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteAlbum(album);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _viewAlbum(Album album) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AlbumDetailScreen(album: album)),
    );
  }

  Future<void> _showUploadDialog() async {
    if (_albums.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please create an album first')),
      );
      return;
    }

    // Show album selection dialog
    if (!mounted) return;

    _selectedAlbumId = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Album'),
        content: SizedBox(
          width: double.maxFinite,
          // Viewports can't answer AlertDialog's IntrinsicWidth query —
          // SingleChildScrollView + Column instead.
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final album in _albums) _albumTile(context, album),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (_selectedAlbumId != null) {
      _pickMedia();
    }
  }

  Widget _albumTile(BuildContext dialogContext, Album album) {
    return ListTile(
      leading: album.coverUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                album.coverUrl!,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 50,
                  height: 50,
                  color: Colors.grey.withOpacity(0.1),
                  child: const Icon(Icons.photo_library, size: 24),
                ),
              ),
            )
          : Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.photo_library, size: 24),
            ),
      title: Text(album.title),
      subtitle: Text('${album.mediaCount} photos'),
      onTap: () => Navigator.pop(dialogContext, album.id),
    );
  }

  void _confirmDeleteAlbum(Album album) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Album'),
        content: Text('Are you sure you want to delete "${album.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAlbum(album.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class AlbumDetailScreen extends StatefulWidget {
  final Album album;

  const AlbumDetailScreen({super.key, required this.album});

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  List<dynamic> _media = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAlbumMedia();
  }

  Future<void> _loadAlbumMedia() async {
    try {
      final response = await ApiService.dio.get(
        '/professionals/albums/${widget.album.id}',
      );
      final data = response.data['data'] as Map<String, dynamic>;
      setState(() {
        _media = data['media'] as List<dynamic>? ?? [];
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading album media: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.album.title)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _media.isEmpty
              ? const Center(child: Text('No photos in this album'))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _media.length,
                  itemBuilder: (context, index) {
                    final media = _media[index];
                    final rawUrl = media['mediaUrl'] as String?;
                    final configService = ConfigService();
                    final url = rawUrl != null
                        ? configService.replaceLocalhost(rawUrl)
                        : null;
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: url != null
                          ? Image.network(
                              url,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey.withOpacity(0.1),
                                child: const Icon(
                                  Icons.broken_image,
                                  color: Colors.grey,
                                ),
                              ),
                            )
                          : Container(
                              color: Colors.grey.withOpacity(0.1),
                              child: const Icon(
                                Icons.broken_image,
                                color: Colors.grey,
                              ),
                            ),
                    );
                  },
                ),
    );
  }
}
