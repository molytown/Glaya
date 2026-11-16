import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import '../../../../shared/services/config_service.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/utils/num_utils.dart';
import '../../../../shared/widgets/verification_badge.dart';
import '../../data/models/reel_model.dart';
import '../../data/repositories/reel_repository.dart';
import '../reel_screen.dart';

class ReelsWidget extends StatefulWidget {
  final List<Reel> reels;

  const ReelsWidget({
    super.key,
    required this.reels,
  });

  @override
  State<ReelsWidget> createState() => _ReelsWidgetState();
}

class _ReelsWidgetState extends State<ReelsWidget> {
  final ReelRepository _reelRepository = ReelRepository();
  final ScrollController _scrollController = ScrollController();
  final Set<String> _countedViewIds = {};
  final Map<String, ReelEngagement> _engagement = {};
  int _activeIndex = 0;
  static const double _cardWidth = 120;
  static const double _cardGap = 12;
  static const double _cardStride = _cardWidth + _cardGap;

  @override
  void initState() {
    super.initState();
    _activeIndex = widget.reels.isEmpty ? 0 : 0;
  }

  @override
  void didUpdateWidget(ReelsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reels != widget.reels) {
      _countedViewIds.clear();
      _activeIndex = 0;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handlePreviewEnded(int index) {
    final next = index + 1;
    if (next >= widget.reels.length) return;
    setState(() => _activeIndex = next);
    if (_scrollController.hasClients) {
      final offset = (next * _cardStride - 16).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _handlePlayedTwoSeconds(Reel reel) async {
    if (reel.id.isEmpty || _countedViewIds.contains(reel.id)) return;
    _countedViewIds.add(reel.id);
    final newViews = await _reelRepository.incrementView(reel.id);
    if (!mounted) return;
    setState(() {
      final stats = _engagementFor(reel);
      stats.views = newViews ?? stats.views + 1;
    });
  }

  ReelEngagement _engagementFor(Reel reel) => _engagement.putIfAbsent(
        reel.id,
        () => ReelEngagement.fromReel(reel),
      );

  Future<void> _toggleLike(Reel reel) async {
    final stats = _engagementFor(reel);
    final liked = !stats.liked;
    setState(() {
      stats.liked = liked;
      stats.likes += liked ? 1 : -1;
    });
    if (liked) {
      await _reelRepository.likeReel(reel.id);
    } else {
      await _reelRepository.unlikeReel(reel.id);
    }
  }

  void _openReelScreen(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReelScreen(
          reels: widget.reels,
          initialIndex: index,
          engagement: Map.fromEntries(
            _engagement.entries
                .map((e) => MapEntry(e.key, e.value.copy())),
          ),
          onEngagementChanged: (updated) {
            if (!mounted) return;
            setState(() {
              _engagement
                ..clear()
                ..addAll(updated.map((k, v) => MapEntry(k, v.copy())));
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reels.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Glam ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: GlayaColors.textPrimary,
                      ),
                    ),
                    TextSpan(
                      text: 'Reels',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: GlayaColors.accentPurple,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => context.push('/reels'),
                child: const Text(
                  'View all',
                  style: TextStyle(
                    color: GlayaColors.berry,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: widget.reels.length,
            itemBuilder: (context, index) {
              return _ReelCard(
                reel: widget.reels[index],
                isActive: index == _activeIndex,
                // Preload the next card's first frame so auto-advance doesn't
                // show a loading gap — still only ~2 decoders alive at once.
                preload: index == _activeIndex + 1,
                engagement: _engagementFor(widget.reels[index]),
                onEnded: () => _handlePreviewEnded(index),
                onPlayedTwoSeconds: () =>
                    _handlePlayedTwoSeconds(widget.reels[index]),
                onTap: () => _openReelScreen(index),
                onLikeTap: () => _toggleLike(widget.reels[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ReelCard extends StatefulWidget {
  final Reel reel;
  final bool isActive;
  final bool preload;
  final ReelEngagement engagement;
  final VoidCallback onEnded;
  final VoidCallback onPlayedTwoSeconds;
  final VoidCallback onTap;
  final VoidCallback onLikeTap;

  const _ReelCard({
    super.key,
    required this.reel,
    required this.isActive,
    this.preload = false,
    required this.engagement,
    required this.onEnded,
    required this.onPlayedTwoSeconds,
    required this.onTap,
    required this.onLikeTap,
  });

  @override
  State<_ReelCard> createState() => _ReelCardState();
}

class _ReelCardState extends State<_ReelCard> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _viewCounted = false;
  bool _endedFired = false;

  /// Only the active card and the next (preloaded) card own a video
  /// controller. Initializing every card spawned N ExoPlayer instances and
  /// exhausted the hardware decoder on device (OMX decoder crash → corrupted
  /// render tree → semantics.parentDataDirty spam).
  bool get _wantsController => widget.isActive || widget.preload;

  @override
  void initState() {
    super.initState();
    if (_wantsController) _initializeVideo();
  }

  @override
  void didUpdateWidget(_ReelCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reel.id != widget.reel.id) {
      _teardown();
      _isInitialized = false;
      _viewCounted = false;
      _endedFired = false;
      if (_wantsController) _initializeVideo();
      return;
    }
    if (_wantsController !=
        (oldWidget.isActive || oldWidget.preload)) {
      if (_wantsController) {
        _initializeVideo();
      } else {
        // Scrolled out of the active/preload window — free the decoder.
        _teardown();
        _isInitialized = false;
      }
    }
    if (widget.isActive != oldWidget.isActive) {
      _syncPlayback();
    }
  }

  void _teardown() {
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    _controller = null;
  }

  Future<void> _initializeVideo() async {
    if (widget.reel.isPhoto || _controller != null) return;
    final configService = ConfigService();
    final videoUrl = configService.replaceLocalhost(widget.reel.videoUrl);
    final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    _controller = controller;
    controller.addListener(_onTick);
    try {
      await controller.initialize();
    } catch (_) {
      // Only tear down if we still own this controller — dispose() may have
      // already run _teardown while initialize() was in flight.
      if (_controller == controller) _teardown();
      return;
    }
    // If _controller changed, _teardown already disposed this controller —
    // disposing again here would double-free the native texture.
    if (!mounted || _controller != controller) return;
    setState(() => _isInitialized = true);
    controller.setLooping(false);
    controller.setVolume(0);
    // Seek to beginning and pause to show first frame as thumbnail
    await controller.seekTo(Duration.zero);
    controller.pause();
    _syncPlayback();
  }

  void _syncPlayback() {
    final c = _controller;
    if (c == null || !_isInitialized) return;
    if (widget.isActive) {
      c.play();
    } else {
      c.pause();
    }
  }

  void _onTick() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final pos = c.value.position;
    if (!_viewCounted && pos >= const Duration(seconds: 2)) {
      _viewCounted = true;
      widget.onPlayedTwoSeconds();
    }
    final dur = c.value.duration;
    if (!_endedFired && dur > Duration.zero && pos >= dur) {
      _endedFired = true;
      c.pause();
      widget.onEnded();
    }
  }

  @override
  void dispose() {
    _teardown();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final professionalName = widget.reel.isUserReel
        ? (widget.reel.user?.name?.split(' ').first ?? 'User')
        : (widget.reel.taggedProfessional?.user?.name?.split(' ')[0] ??
            'Professional');
    final uploaderPhoto = widget.reel.isUserReel
        ? widget.reel.user?.photoUrl
        : widget.reel.taggedProfessional?.user?.photoUrl;
    final isNew = DateTime.now().difference(widget.reel.createdAt) <
        const Duration(hours: 2);

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey[200],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.reel.isPhoto)
              Image.network(
                ConfigService().replaceLocalhost(widget.reel.videoUrl),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
              )
            else if (_isInitialized && _controller != null)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller!.value.size.width,
                  height: _controller!.value.size.height,
                  child: VideoPlayer(_controller!),
                ),
              )
            else if (!widget.reel.isPhoto && _wantsController)
              const Center(child: CircularProgressIndicator())
            else if (!widget.reel.isPhoto)
              Container(
                color: Colors.grey[300],
                child: const Center(
                  child: Icon(Icons.play_circle_outline,
                      color: Colors.grey, size: 40),
                ),
              ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
            ),
            if (isNew)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFE91E8C), Color(0xFFFF4081)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0x66E91E8C),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    'NEW',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.isActive ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.visibility,
                        color: Colors.white,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        formatCompactCount(widget.engagement.views),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: widget.onLikeTap,
                        child: Row(
                          children: [
                            Icon(
                              Icons.favorite,
                              color: widget.engagement.liked
                                  ? GlayaColors.berry
                                  : Colors.white,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              formatCompactCount(widget.engagement.likes),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (widget.reel.title != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        widget.reel.title!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        if (uploaderPhoto != null) ...[
                          CircleAvatar(
                            radius: 8,
                            backgroundImage: NetworkImage(
                              ConfigService().replaceLocalhost(uploaderPhoto),
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Flexible(
                          child: Text(
                            'by $professionalName',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!widget.reel.isUserReel &&
                            widget.reel.taggedProfessional != null) ...[
                          const SizedBox(width: 4),
                          VerificationBadge(
                            subscriptionType: widget
                                .reel.taggedProfessional!.subscriptionType,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
