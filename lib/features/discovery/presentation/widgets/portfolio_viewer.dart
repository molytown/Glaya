import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../../shared/theme/colors.dart';

class PortfolioViewer extends StatefulWidget {
  final Map<String, dynamic> gallery;

  const PortfolioViewer({super.key, required this.gallery});

  @override
  State<PortfolioViewer> createState() => _PortfolioViewerState();
}

class _PortfolioViewerState extends State<PortfolioViewer> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  List<Map<String, dynamic>> _media = [];
  Map<String, VideoPlayerController>? _videoControllers;

  @override
  void initState() {
    super.initState();
    _media =
        (widget.gallery['media'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    _initializeVideos();
  }

  void _initializeVideos() {
    _videoControllers = {};
    for (int i = 0; i < _media.length; i++) {
      final item = _media[i];
      if (item['mediaType'] == 'video') {
        final controller = VideoPlayerController.networkUrl(
            Uri.parse(item['mediaUrl'] as String));
        controller.initialize().then((_) {
          if (mounted) setState(() {});
        });
        _videoControllers![item['id'] as String] = controller;
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _videoControllers?.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);

    // Pause all videos
    _videoControllers?.forEach((_, controller) => controller.pause());

    // Play current video if it's a video
    final currentItem = _media[_currentIndex];
    if (currentItem['mediaType'] == 'video') {
      final controller = _videoControllers?[currentItem['id'] as String];
      if (controller != null && controller.value.isInitialized) {
        controller.play();
        controller.setLooping(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_media.isEmpty) {
      return _buildEmptyState();
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          // Background
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              color: Color(0xFF000000).withValues(alpha: 0.9),
            ),
          ),
          // Content
          Center(
            child: Container(
              width: 300,
              height: 400, // 3:4 aspect ratio
              decoration: BoxDecoration(
                color: Color(0xFF000000),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    // Image/Video viewer
                    PageView.builder(
                      controller: _pageController,
                      onPageChanged: _onPageChanged,
                      itemCount: _media.length,
                      itemBuilder: (context, index) {
                        final item = _media[index];
                        return _buildMediaItem(item);
                      },
                    ),
                    // Close button
                    Positioned(
                      top: 12,
                      right: 12,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Color(0xFF000000).withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    // Page indicators
                    if (_media.length > 1)
                      Positioned(
                        bottom: 12,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            _media.length,
                            (index) => Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: index == _currentIndex
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ),
                    // Video indicator
                    if (_media[_currentIndex]['mediaType'] == 'video')
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Color(0xFF000000).withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_arrow,
                                  color: Colors.white, size: 16),
                              SizedBox(width: 4),
                              Text('Video',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaItem(Map<String, dynamic> item) {
    if (item['mediaType'] == 'video') {
      final controller = _videoControllers?[item['id'] as String];
      if (controller != null && controller.value.isInitialized) {
        return FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller.value.size.width,
            height: controller.value.size.height,
            child: VideoPlayer(controller),
          ),
        );
      }
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Image.network(
      item['mediaUrl'] as String,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: Colors.grey.shade800,
        child: const Icon(Icons.broken_image, color: Colors.grey),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 300,
        height: 400,
        decoration: BoxDecoration(
          color: Color(0xFF000000),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.photo_library_outlined, size: 48, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No media available',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
