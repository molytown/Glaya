import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../../shared/theme/colors.dart';

class PortfolioCard extends StatefulWidget {
  final Map<String, dynamic> gallery;
  final VoidCallback onTap;

  const PortfolioCard({
    super.key,
    required this.gallery,
    required this.onTap,
  });

  @override
  State<PortfolioCard> createState() => _PortfolioCardState();
}

class _PortfolioCardState extends State<PortfolioCard> {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _shouldAutoPlay = false;

  @override
  void initState() {
    super.initState();
    _checkForVideo();
  }

  void _checkForVideo() {
    final coverMedia = widget.gallery['coverMedia'];
    if (coverMedia != null && coverMedia['mediaType'] == 'video') {
      _shouldAutoPlay = true;
      _initializeVideo(coverMedia['mediaUrl'] as String);
    }
  }

  Future<void> _initializeVideo(String url) async {
    try {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
      await _videoController!.initialize();
      await _videoController!.setVolume(0.0); // Muted
      setState(() => _isVideoInitialized = true);

      // Auto-play after 5 seconds
      await Future.delayed(const Duration(seconds: 5));
      if (mounted && _isVideoInitialized) {
        await _videoController!.play();
        _videoController!.setLooping(true);
      }
    } catch (e) {
      // If video fails, fall back to showing thumbnail or placeholder
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coverMedia = widget.gallery['coverMedia'];
    final professional =
        widget.gallery['professional'] as Map<String, dynamic>?;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (coverMedia != null)
                _shouldAutoPlay &&
                        _isVideoInitialized &&
                        _videoController != null
                    ? FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _videoController!.value.size.width,
                          height: _videoController!.value.size.height,
                          child: VideoPlayer(_videoController!),
                        ),
                      )
                    : Image.network(
                        coverMedia['mediaUrl'] as String,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.broken_image,
                              color: Colors.grey),
                        ),
                      )
              else
                Container(
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.photo_library, color: Colors.grey),
                ),
              // Video indicator
              if (coverMedia != null && coverMedia['mediaType'] == 'video')
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow, color: Colors.white, size: 12),
                        SizedBox(width: 2),
                        Text('Video',
                            style:
                                TextStyle(color: Colors.white, fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              // Professional info overlay
              if (professional != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          professional['name'] as String? ?? 'Professional',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (professional['businessName'] != null)
                          Text(
                            professional['businessName'] as String? ?? '',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 9,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ),
              // Media count indicator
              if (widget.gallery['mediaCount'] != null &&
                  widget.gallery['mediaCount'] > 1)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '+${widget.gallery['mediaCount'] - 1}',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
