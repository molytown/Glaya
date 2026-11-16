import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/services/config_service.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/utils/num_utils.dart';
import '../../../shared/widgets/verification_badge.dart';
import '../../auth/data/models/user_model.dart';
import '../../auth/presentation/providers/auth_notifier.dart';
import '../../discovery/data/professional_model.dart';
import '../data/models/reel_model.dart';
import '../data/repositories/reel_repository.dart';

class ReelScreen extends ConsumerStatefulWidget {
  final List<Reel> reels;
  final int initialIndex;
  final Map<String, ReelEngagement> engagement;
  final void Function(Map<String, ReelEngagement>)? onEngagementChanged;

  const ReelScreen({
    super.key,
    required this.reels,
    this.initialIndex = 0,
    this.engagement = const {},
    this.onEngagementChanged,
  });

  @override
  ConsumerState<ReelScreen> createState() => _ReelScreenState();
}

class _ReelScreenState extends ConsumerState<ReelScreen> {
  late PageController _pageController;
  late VideoPlayerController _videoController;
  bool _hasVideoController = false;
  bool _videoFailed = false;
  int _currentIndex = 0;
  bool _isPlaying = true;
  bool _isMuted = false;
  bool _isLoadingRelated = false;
  List<Reel> _allReels = [];
  DateTime? _lastTap;
  double _startX = 0;
  double _startY = 0;
  final ReelRepository _reelRepository = ReelRepository();
  final Map<String, ReelEngagement> _engagement = {};
  final Set<String> _countedViewIds = {};
  bool _showHeart = false;
  Timer? _heartTimer;

  bool get _isAuthenticated {
    final authState = ref.watch(authNotifierProvider);
    return authState.valueOrNull != null;
  }

  @override
  void initState() {
    super.initState();
    // The tapped reel plays first; the rest of the feed follows
    // priority scoring (boost > bookings > shares > likes > views > date).
    if (widget.reels.isEmpty) {
      _allReels = [];
      _currentIndex = 0;
    } else {
      final tappedIndex = widget.initialIndex.clamp(0, widget.reels.length - 1);
      final tapped = widget.reels[tappedIndex];
      final rest = List<Reel>.of(widget.reels)..removeAt(tappedIndex);
      _allReels = [tapped, ..._applyPriorityOrdering(rest)];
      _currentIndex = 0;
    }
    _pageController = PageController(initialPage: _currentIndex);
    widget.engagement.forEach((key, value) {
      _engagement[key] = value.copy();
    });
    _initializeVideo(_currentIndex);
    // onPageChanged doesn't fire for the initial page — count it here
    if (_allReels.isNotEmpty) {
      _incrementView(_allReels[_currentIndex]);
    }
  }

  ReelEngagement _statsFor(Reel reel) => _engagement.putIfAbsent(
        reel.id,
        () => ReelEngagement.fromReel(reel),
      );

  void _notifyEngagement() {
    widget.onEngagementChanged?.call(Map.fromEntries(
      _engagement.entries.map((e) => MapEntry(e.key, e.value.copy())),
    ));
  }

  void _showHeartAnimation() {
    _heartTimer?.cancel();
    setState(() => _showHeart = true);
    _heartTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showHeart = false);
    });
  }

  List<Reel> _applyPriorityOrdering(List<Reel> reels) {
    return reels.toList()
      ..sort((a, b) {
        // Priority: Boost > Bookings > Shares > Likes > Views > Date
        final aBoost = a.taggedProfessional?.boost?.isActive == true
            ? (a.taggedProfessional?.boost?.rank ?? 0)
            : 0;
        final bBoost = b.taggedProfessional?.boost?.isActive == true
            ? (b.taggedProfessional?.boost?.rank ?? 0)
            : 0;

        if (aBoost != bBoost) return bBoost - aBoost;

        final aBookings = a.taggedProfessional?.totalBookings ?? 0;
        final bBookings = b.taggedProfessional?.totalBookings ?? 0;
        if (aBookings != bBookings) return bBookings - aBookings;

        if (a.shares != b.shares) return b.shares - a.shares;
        if (a.likes != b.likes) return b.likes - a.likes;
        if (a.views != b.views) return b.views - a.views;

        return b.createdAt.compareTo(a.createdAt);
      });
  }

  void _initializeVideo(int index) {
    if (_allReels.isEmpty || index < 0 || index >= _allReels.length) return;
    if (_hasVideoController) {
      _videoController.dispose();
      _hasVideoController = false;
    }
    _videoFailed = false;
    final reel = _allReels[index];
    if (reel.isPhoto) {
      setState(() {});
      return;
    }
    final configService = ConfigService();
    final videoUrl = configService.replaceLocalhost(reel.videoUrl);

    final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    _videoController = controller;
    _hasVideoController = true;
    controller.initialize().then((_) {
      if (!mounted || _videoController != controller) return;
      setState(() {});
      controller.play();
      _isPlaying = true;
    }).catchError((_) {
      // Decoder/network failure — drop the controller so the UI shows a
      // fallback instead of a broken player or an unhandled async error.
      if (mounted && _videoController == controller) {
        setState(() {
          _hasVideoController = false;
          _videoFailed = true;
          controller.dispose();
        });
      }
    });
  }

  void _navigateToUserProfile(String userId) {
    context.push('/user/$userId');
  }

  Future<void> _loadRelatedReels() async {
    if (_isLoadingRelated) return;
    final currentReel = _allReels[_currentIndex];
    final professional = currentReel.taggedProfessional;

    if (professional?.categoryId != null && professional?.id != null) {
      setState(() => _isLoadingRelated = true);
      try {
        final response = await ApiService.dio.get(
          '/reels/related/${professional!.categoryId}/${professional!.id}',
        );
        final relatedReels = (response.data['data'] as List<dynamic>?)
                ?.map((json) => Reel.fromJson(json as Map<String, dynamic>))
                .toList() ??
            [];

        if (relatedReels.isNotEmpty && mounted) {
          setState(() {
            _allReels = [..._allReels, ..._applyPriorityOrdering(relatedReels)];
          });
        }
      } catch (e) {
        print('Error loading related reels: $e');
      } finally {
        if (mounted) {
          setState(() => _isLoadingRelated = false);
        }
      }
    }
  }

  @override
  void dispose() {
    _heartTimer?.cancel();
    _pageController.dispose();
    if (_hasVideoController) _videoController.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_allReels.isEmpty || _allReels[_currentIndex].isPhoto) return;
    if (!_hasVideoController || !_videoController.value.isInitialized) return;
    setState(() {
      if (_isPlaying) {
        _videoController.pause();
      } else {
        _videoController.play();
      }
      _isPlaying = !_isPlaying;
    });
  }

  void _toggleMute() {
    if (!_hasVideoController || !_videoController.value.isInitialized) return;
    setState(() {
      _videoController.setVolume(_isMuted ? 1.0 : 0.0);
      _isMuted = !_isMuted;
    });
  }

  void _toggleLike() async {
    if (_allReels.isEmpty) return;
    final currentReel = _allReels[_currentIndex];
    final stats = _statsFor(currentReel);
    final liked = !stats.liked;
    setState(() {
      stats.liked = liked;
      stats.likes += liked ? 1 : -1;
    });
    if (liked) {
      _showHeartAnimation();
      await _reelRepository.likeReel(currentReel.id);
    } else {
      _heartTimer?.cancel();
      if (_showHeart) setState(() => _showHeart = false);
      await _reelRepository.unlikeReel(currentReel.id);
    }
    _notifyEngagement();
  }

  void _handleDoubleTap() {
    final now = DateTime.now();
    if (_lastTap != null &&
        now.difference(_lastTap!) < const Duration(milliseconds: 300)) {
      _toggleLike();
    }
    _lastTap = now;
  }

  void _shareReel() async {
    if (_allReels.isEmpty) return;
    final currentReel = _allReels[_currentIndex];
    setState(() {
      _statsFor(currentReel).shares += 1;
    });
    await _reelRepository.incrementShare(currentReel.id);
    _notifyEngagement();

    // Share the reel URL — opens the web watch page
    final reelUrl = 'https://glaya.space/reel/${currentReel.id}';
    final title = currentReel.title ?? 'Check out this reel on Glaya';
    await Share.share(
      '$title\n$reelUrl',
      subject: title,
    );
  }

  void _navigateToProfile(String professionalId) {
    context.push('/professional/$professionalId');
  }

  void _handleBookNow(String professionalId) {
    context.push('/professional/$professionalId');
  }

  Future<void> _incrementView(Reel reel) async {
    if (reel.id.isEmpty || _countedViewIds.contains(reel.id)) return;
    _countedViewIds.add(reel.id);
    try {
      final response = await ApiService.dio.post('/reels/${reel.id}/view');
      final serverViews = response.data?['data']?['views'];
      if (mounted) {
        setState(() {
          final stats = _statsFor(reel);
          stats.views = serverViews is int ? serverViews : stats.views + 1;
        });
        _notifyEngagement();
      }
    } catch (e) {
      print('Error incrementing view: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _allReels.isEmpty
            ? const Center(
                child: Text(
                  'No reels available',
                  style: TextStyle(color: Colors.white),
                ),
              )
            : PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                  _initializeVideo(index);
                  _incrementView(_allReels[index]);

                  // Load related reels when reaching the end
                  if (index == _allReels.length - 1) {
                    _loadRelatedReels();
                  }
                },
                itemCount: _allReels.length,
                itemBuilder: (context, index) {
                  return _buildReelItem(_allReels[index]);
                },
              ),
      ),
    );
  }

  Widget _buildReelItem(Reel reel) {
    final professional = reel.taggedProfessional;
    final stats = _statsFor(reel);
    final configService = ConfigService();
    final videoUrl = configService.replaceLocalhost(reel.videoUrl);
    final isUserReel = reel.isUserReel;
    final displayName = isUserReel
        ? (reel.user?.name?.split(' ').first ?? 'User')
        : (professional?.user?.name?.split(' ')[0] ?? 'Professional');
    final displayPhoto =
        isUserReel ? reel.user?.photoUrl : professional?.user?.photoUrl;
    final displayPhotoUrl = displayPhoto != null
        ? configService.replaceLocalhost(displayPhoto)
        : null;

    return GestureDetector(
      onDoubleTap: _handleDoubleTap,
      onTap: _togglePlayPause,
      onHorizontalDragStart: (details) {
        _startX = details.globalPosition.dx;
      },
      onHorizontalDragEnd: (details) {
        final dx = details.globalPosition.dx - _startX;
        if (dx > 50) {
          // Swipe right - previous
          if (_currentIndex > 0) {
            _pageController.animateToPage(_currentIndex - 1,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut);
          }
        } else if (dx < -50) {
          // Swipe left - next
          if (_currentIndex < _allReels.length - 1) {
            _pageController.animateToPage(_currentIndex + 1,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut);
          }
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video Player / Photo
          Center(
            child: reel.isPhoto
                ? Image.network(
                    videoUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.broken_image,
                      color: Colors.white54,
                      size: 64,
                    ),
                  )
                : _videoFailed
                    ? const Icon(
                        Icons.broken_image,
                        color: Colors.white54,
                        size: 64,
                      )
                    : _hasVideoController
                        ? _videoController.value.isInitialized
                            ? AspectRatio(
                                aspectRatio: _videoController.value.aspectRatio,
                                child: VideoPlayer(_videoController),
                              )
                            : const CircularProgressIndicator(
                                color: Colors.white,
                              )
                        : const CircularProgressIndicator(
                            color: Colors.white,
                          ),
          ),

          // Play/Pause Overlay
          if (!_isPlaying)
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 60,
                ),
              ),
            ),

          // Double-tap like animation
          if (_showHeart)
            Center(
              child: Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: GlayaColors.berry.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.favorite,
                  color: GlayaColors.berry,
                  size: 80,
                ),
              ),
            ),

          // Actions
          Positioned(
            right: 16,
            bottom: 200,
            child: Column(
              children: [
                // Like Button
                _buildActionButton(
                  icon: Icons.favorite,
                  count: stats.likes,
                  isActive: stats.liked,
                  onTap: _toggleLike,
                ),
                const SizedBox(height: 20),
                // Share Button
                _buildActionButton(
                  icon: Icons.share,
                  count: stats.shares,
                  onTap: _shareReel,
                ),
                const SizedBox(height: 20),
                // Mute Button (video only)
                if (!reel.isPhoto)
                  _buildActionButton(
                    icon: _isMuted ? Icons.volume_off : Icons.volume_up,
                    onTap: _toggleMute,
                  ),
              ],
            ),
          ),

          // Bottom Actions
          Positioned(
            left: 16,
            right: 16,
            bottom: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Uploader / Professional Info
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: displayPhotoUrl != null
                          ? NetworkImage(displayPhotoUrl)
                          : null,
                      child: displayPhotoUrl == null
                          ? const Icon(Icons.person, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              if (!isUserReel && professional != null) ...[
                                const SizedBox(width: 6),
                                VerificationBadge(
                                  subscriptionType:
                                      professional.subscriptionType,
                                ),
                              ],
                            ],
                          ),
                          Text(
                            '${formatCompactCount(stats.views)} views',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Title
                if (reel.title != null)
                  Text(
                    reel.title!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(height: 8),
                // Description
                if (reel.description != null)
                  Text(
                    reel.description!,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                const SizedBox(height: 16),
                // Action Buttons
                Row(
                  children: [
                    if (professional != null)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isAuthenticated
                              ? () => _handleBookNow(professional.id)
                              : () => context.push('/login'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: GlayaColors.berry,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child:
                              Text(_isAuthenticated ? 'Book Now' : 'Sign In'),
                        ),
                      ),
                    if (professional != null) const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          if (isUserReel &&
                              reel.user?.id != null &&
                              reel.user!.id.isNotEmpty) {
                            _navigateToUserProfile(reel.user!.id);
                          } else if (professional != null) {
                            _navigateToProfile(professional.id);
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('View Profile'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Close Button
          Positioned(
            top: 16,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    int? count,
    bool isActive = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isActive ? GlayaColors.berry : Colors.white,
              size: 28,
            ),
          ),
          if (count != null)
            Text(
              formatCompactCount(count),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }
}
