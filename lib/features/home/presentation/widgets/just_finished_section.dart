import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../shared/services/api_service.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/providers/location_provider.dart';
import '../../../../shared/services/portfolio_websocket_service.dart';
import '../../../../shared/services/config_service.dart';
import '../../../../shared/services/location_service.dart';
import '../../../../shared/widgets/verification_badge.dart';

class JustFinishedCard {
  final String id;
  final String? title;
  final String coverMediaUrl;
  final String coverMediaType;
  final String? coverThumbnailUrl;
  final int mediaCount;
  final List<GalleryMediaItem> mediaItems;
  final String professionalName;
  final String professionalId;
  final String? professionalSubscriptionType;
  final String? serviceName;
  final String? category;
  final DateTime createdAt;
  final DateTime? updatedAt;

  JustFinishedCard({
    required this.id,
    this.title,
    required this.coverMediaUrl,
    required this.coverMediaType,
    this.coverThumbnailUrl,
    required this.mediaCount,
    required this.mediaItems,
    required this.professionalName,
    required this.professionalId,
    this.professionalSubscriptionType,
    this.serviceName,
    this.category,
    required this.createdAt,
    this.updatedAt,
  });

  factory JustFinishedCard.fromJson(Map<String, dynamic> json) {
    final configService = ConfigService();
    final coverMedia = json['coverMedia'] as Map<String, dynamic>?;

    // Normalize cover media URL
    String normalizedCoverUrl = coverMedia?['mediaUrl'] as String? ?? '';
    if (normalizedCoverUrl.isNotEmpty &&
        !normalizedCoverUrl.startsWith('http')) {
      normalizedCoverUrl = '${configService.socketUrl}$normalizedCoverUrl';
    }

    // Normalize thumbnail URL
    String? normalizedThumbnailUrl = coverMedia?['thumbnailUrl'] as String?;
    if (normalizedThumbnailUrl != null && normalizedThumbnailUrl.isNotEmpty) {
      if (!normalizedThumbnailUrl.startsWith('http')) {
        normalizedThumbnailUrl =
            '${configService.socketUrl}$normalizedThumbnailUrl';
      }
    }

    // Normalize media items URLs
    final mediaItems = (json['media'] as List?)?.map((item) {
          final mediaItem = GalleryMediaItem.fromJson(
            item as Map<String, dynamic>,
          );
          String normalizedMediaUrl = mediaItem.mediaUrl;
          if (!normalizedMediaUrl.startsWith('http')) {
            normalizedMediaUrl =
                '${configService.socketUrl}$normalizedMediaUrl';
          }

          String? normalizedItemThumbnailUrl = mediaItem.thumbnailUrl;
          if (normalizedItemThumbnailUrl != null &&
              normalizedItemThumbnailUrl.isNotEmpty) {
            if (!normalizedItemThumbnailUrl.startsWith('http')) {
              normalizedItemThumbnailUrl =
                  '${configService.socketUrl}$normalizedItemThumbnailUrl';
            }
          }

          return GalleryMediaItem(
            id: mediaItem.id,
            mediaUrl: normalizedMediaUrl,
            mediaType: mediaItem.mediaType,
            thumbnailUrl: normalizedItemThumbnailUrl,
          );
        }).toList() ??
        [];

    // Albums without an explicit coverMedia still have media — use the
    // first item so the card renders an image and taps open the viewer.
    if (normalizedCoverUrl.isEmpty && mediaItems.isNotEmpty) {
      normalizedCoverUrl = mediaItems.first.mediaUrl;
      normalizedThumbnailUrl ??= mediaItems.first.thumbnailUrl;
    }
    final coverType = coverMedia?['mediaType']?.toString() ??
        (mediaItems.isNotEmpty ? mediaItems.first.mediaType : 'photo');

    return JustFinishedCard(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString(),
      coverMediaUrl: normalizedCoverUrl,
      coverMediaType: coverType,
      coverThumbnailUrl: normalizedThumbnailUrl,
      mediaCount: (json['mediaCount'] as num?)?.toInt() ?? mediaItems.length,
      mediaItems: mediaItems,
      professionalName: json['professional']?['name']?.toString() ??
          json['professional']?['businessName']?.toString() ??
          'Professional',
      professionalId: json['professional']?['id']?.toString() ?? '',
      professionalSubscriptionType:
          json['professional']?['subscriptionType']?.toString(),
      serviceName: json['service']?['name']?.toString(),
      category: json['category']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
    );
  }
}

class GalleryMediaItem {
  final String id;
  final String mediaUrl;
  final String mediaType;
  final String? thumbnailUrl;

  GalleryMediaItem({
    required this.id,
    required this.mediaUrl,
    required this.mediaType,
    this.thumbnailUrl,
  });

  factory GalleryMediaItem.fromJson(Map<String, dynamic> json) {
    final configService = ConfigService();
    final rawMediaUrl = json['mediaUrl']?.toString() ?? '';
    final rawThumbnailUrl = json['thumbnailUrl']?.toString();
    // Transform relative URLs to absolute URLs
    final mediaUrl = configService.replaceLocalhost(rawMediaUrl);
    final thumbnailUrl = rawThumbnailUrl != null
        ? configService.replaceLocalhost(rawThumbnailUrl)
        : null;
    return GalleryMediaItem(
      id: json['id']?.toString() ?? '',
      mediaUrl: mediaUrl,
      mediaType: json['mediaType']?.toString() ?? 'photo',
      thumbnailUrl: thumbnailUrl,
    );
  }
}

final justFinishedProvider = FutureProvider<List<JustFinishedCard>>((
  ref,
) async {
  final locationState = ref.watch(locationProvider);
  double lat;
  double lng;

  if (locationState.hasLocation) {
    lat = locationState.lat!;
    lng = locationState.lng!;
  } else {
    // Try to get default location from backend
    final defaultLocation = await LocationService.getDefaultLocation();
    if (defaultLocation != null) {
      lat = defaultLocation.latitude;
      lng = defaultLocation.longitude;
    } else {
      // Fallback to Douala, Cameroon
      lat = 3.8480;
      lng = 11.5021;
    }
  }

  try {
    final response = await ApiService.dio.get(
      '/professionals/portfolio/recent',
      queryParameters: {
        'lat': lat,
        'lng': lng,
        'limit': 9,
        ...zoneQueryParams(locationState)
      },
    );
    final data = response.data['data'] as List;
    final cards = data
        .map((json) => JustFinishedCard.fromJson(json as Map<String, dynamic>))
        .where((c) => c.mediaCount > 0 || c.coverMediaUrl.isNotEmpty)
        .toList()
      // Most recently updated first — an old album that receives new photos
      // surfaces as a "new" album (mirrors the React slider ordering)
      ..sort((a, b) =>
          (b.updatedAt ?? b.createdAt).compareTo(a.updatedAt ?? a.createdAt));
    return cards;
  } catch (e) {
    return [];
  }
});

class JustFinishedSection extends ConsumerStatefulWidget {
  const JustFinishedSection({super.key});

  @override
  ConsumerState<JustFinishedSection> createState() =>
      _JustFinishedSectionState();
}

class _JustFinishedSectionState extends ConsumerState<JustFinishedSection>
    with SingleTickerProviderStateMixin {
  static const _moveMs = 600;
  static const _pauseMs = 2000;
  // Cards render at a 9:16 aspect ratio — height derives from slot width.
  // Cards are sized ~16% larger than their slot so neighbours overlap slightly.
  double _cardW = 0;
  double _cardH = 0;

  late final Ticker _ticker;
  final ValueNotifier<double> _effNotifier = ValueNotifier<double>(0);
  final PortfolioWebSocketService _wsService = PortfolioWebSocketService();
  StreamSubscription? _uploadSubscription;

  // Loop state — mirrors the React JustFinishedGallerySlider rAF cycle:
  // slide one card (600ms easeInOutCubic), hold 2s, repeat, wrapping mod half.
  double _pos = 0;
  double _target = 0;
  double _moveFrom = 0;
  int _phase = 0; // 0 = idle, 1 = move, 2 = pause
  Duration _phaseStart = Duration.zero;
  double _slotW = 0;
  double _halfW = 0;
  double _vw = 0;
  int _halfItemCount = 0;
  Duration _lastElapsed = Duration.zero;

  // Drag state
  bool _dragging = false;
  double _dragBaseEff = 0;
  double _dragDx = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    _wsService.connect();
    _uploadSubscription = _wsService.uploadStream.listen((_) {
      // Refresh the just finished provider when a new upload is received
      ref.invalidate(justFinishedProvider);
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _effNotifier.dispose();
    _uploadSubscription?.cancel();
    _wsService.disconnect();
    super.dispose();
  }

  static double _easeInOutCubic(double t) =>
      t < 0.5 ? 4 * t * t * t : 1 - math.pow(-2 * t + 2, 3) / 2;

  void _onTick(Duration elapsed) {
    _lastElapsed = elapsed;
    if (_slotW <= 0 || _halfW <= 0 || _halfItemCount == 0) return;

    if (_phase == 0) {
      _target = _slotW;
      _moveFrom = 0;
      _phase = 1;
      _phaseStart = elapsed;
    }

    if (!_dragging) {
      if (_phase == 1) {
        final t =
            ((elapsed - _phaseStart).inMicroseconds / 1e6) / (_moveMs / 1000);
        final clamped = t.clamp(0.0, 1.0);
        _pos = _moveFrom + (_target - _moveFrom) * _easeInOutCubic(clamped);
        if (clamped >= 1) {
          _phase = 2;
          _phaseStart = elapsed;
        }
      } else if (_phase == 2) {
        final held = (elapsed - _phaseStart).inMilliseconds;
        if (held >= _pauseMs) {
          _target += _slotW;
          _moveFrom = _pos;
          _phase = 1;
          _phaseStart = elapsed;
        }
      }
    }

    var eff = _pos % _halfW;
    if (eff < 0) eff += _halfW;
    if (_dragging) {
      var e = (_dragBaseEff - _dragDx) % _halfW;
      if (e < 0) e += _halfW;
      eff = e;
    }
    _effNotifier.value = eff;
  }

  void _onDragStart(DragStartDetails _) {
    setState(() => _dragging = true);
    _dragBaseEff = _effNotifier.value;
    _dragDx = 0;
    // Freeze the cycle at a pause boundary so it resumes cleanly
    _phase = 2;
    _phaseStart = _lastElapsed;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _dragDx += details.delta.dx;
  }

  void _onDragEnd(DragEndDetails _) => _finishDrag();

  void _finishDrag() {
    setState(() => _dragging = false);
    if (_halfW > 0) {
      // Rebase pos so pos % halfW equals the dragged position — no jump
      _pos = _pos - (_pos % _halfW) + _effNotifier.value;
      _phase = 2;
      _phaseStart = _lastElapsed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final justFinishedAsync = ref.watch(justFinishedProvider);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Just Finished',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              GestureDetector(
                onTap: () => context.push('/all-galleries'),
                child: const Text(
                  'See All',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: GlayaColors.berry,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          justFinishedAsync.when(
            data: (uploads) {
              if (uploads.isEmpty) {
                return SizedBox(
                  height: _estimatedCardHeight(context),
                  child: const Center(
                    child: Text(
                      'No recent uploads nearby',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                );
              }
              return _buildSlider(uploads);
            },
            loading: () => SizedBox(
              height: _estimatedCardHeight(context),
              child: const Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => SizedBox(
              height: _estimatedCardHeight(context),
              child: const Center(
                child: Text(
                  'Failed to load uploads',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Matches the slider's 9:16 card height for pre-layout states
  // (loading / error / empty) before LayoutBuilder has run.
  double _estimatedCardHeight(BuildContext context) {
    final vw = MediaQuery.of(context).size.width - 32; // 16px side margins
    final slotW = vw / 3;
    return (slotW - 8) * 1.164 * 16 / 9;
  }

  Widget _buildSlider(List<JustFinishedCard> uploads) {
    // Repeat the set enough times to fill ~3 visible slots, then duplicate —
    // translating by half the track width wraps seamlessly (React parity).
    final copies = (3 / uploads.length).ceil().clamp(1, 99);
    final half = <JustFinishedCard>[
      for (var c = 0; c < copies; c++) ...uploads,
    ];
    final items = [...half, ...half];
    _halfItemCount = half.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final vw = constraints.maxWidth;
        _vw = vw;
        _slotW = vw / 3;
        // 9:16 ratio, ~16% larger than the slot: card width is the slot minus
        // 4px horizontal padding per side, scaled up.
        _cardW = (_slotW - 8) * 1.164;
        _cardH = _cardW * 16 / 9;
        _halfW = _slotW * _halfItemCount;

        return ClipRect(
          child: SizedBox(
            height: _cardH,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: _onDragStart,
              onHorizontalDragUpdate: _onDragUpdate,
              onHorizontalDragEnd: _onDragEnd,
              onHorizontalDragCancel: _finishDrag,
              child: ValueListenableBuilder<double>(
                valueListenable: _effNotifier,
                builder: (context, eff, _) {
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: OverflowBox(
                          maxWidth: double.infinity,
                          alignment: Alignment.topLeft,
                          child: Transform.translate(
                            offset: Offset(-eff, 0),
                            child: Row(
                              children: [
                                for (var i = 0; i < items.length; i++)
                                  _buildCardSlot(items[i], i, eff),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardSlot(JustFinishedCard upload, int index, double eff) {
    // Center-pop: scale by distance from viewport center, wrapped modulo the
    // half period so cards in the duplicate half scale correctly.
    var cx = (index * _slotW + _slotW / 2 - eff) % _halfW;
    if (cx < 0) cx += _halfW;
    var dist = cx - _vw / 2;
    if (dist > _halfW / 2) {
      dist -= _halfW;
    } else if (dist < -_halfW / 2) {
      dist += _halfW;
    }
    final dd = dist.abs() / _slotW;
    final scale = (1 - dd * 0.09).clamp(0.82, 1.0);

    return SizedBox(
      width: _slotW,
      height: _cardH,
      child: Center(
        child: SizedBox(
          width: _cardW,
          height: _cardH,
          child: Transform.scale(
            scale: scale,
            child: _JustFinishedCard(upload: upload),
          ),
        ),
      ),
    );
  }
}

class _JustFinishedCard extends StatelessWidget {
  final JustFinishedCard upload;

  const _JustFinishedCard({required this.upload});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Albums can have a cover image but an empty media list (cover set
        // without media items) — fall back to the cover so the tap isn't dead.
        final items = upload.mediaItems.isNotEmpty
            ? upload.mediaItems
            : (upload.coverMediaUrl.isNotEmpty
                ? [
                    GalleryMediaItem(
                      id: upload.id,
                      mediaUrl: upload.coverMediaUrl,
                      mediaType: upload.coverMediaType,
                      thumbnailUrl: upload.coverThumbnailUrl,
                    ),
                  ]
                : const <GalleryMediaItem>[]);
        if (items.isNotEmpty) {
          _showGalleryViewer(context, upload, items);
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Media (photo or video thumbnail)
            upload.coverMediaType == 'video' &&
                    upload.coverThumbnailUrl?.isNotEmpty == true
                ? CachedNetworkImage(
                    imageUrl: upload.coverThumbnailUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.play_circle_outline, size: 48),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.broken_image),
                    ),
                  )
                : upload.coverMediaUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: upload.coverMediaUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(color: Colors.grey[300]),
                        errorWidget: (_, __, ___) => Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.broken_image),
                        ),
                      )
                    : Container(color: Colors.grey[300]),
            // Video indicator
            if (upload.coverMediaType == 'video')
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Color(0xFF000000).withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            // Media count badge
            if (upload.mediaCount > 1)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Color(0xFF000000).withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '+${upload.mediaCount - 1}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            // Gradient overlay
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Color(0xFF000000).withValues(alpha: 0.7),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (upload.title != null)
                      Text(
                        upload.title!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (upload.category != null) ...[
                      if (upload.title != null) const SizedBox(height: 2),
                      Text(
                        upload.category!,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (upload.serviceName != null) ...[
                      if (upload.title != null || upload.category != null)
                        const SizedBox(height: 2),
                      Text(
                        upload.serviceName!,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            upload.professionalName,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white70,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        VerificationBadge(
                          subscriptionType: upload.professionalSubscriptionType,
                          size: VerificationBadgeSize.small,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGalleryViewer(
    BuildContext context,
    JustFinishedCard upload,
    List<GalleryMediaItem> items,
  ) {
    showDialog(
      context: context,
      barrierColor: Color(0xFF000000).withValues(alpha: 0.9),
      builder: (context) => GalleryImageViewer(
        mediaItems: items,
        professionalId: upload.professionalId,
        initialIndex: 0,
      ),
    );
  }
}

class GalleryImageViewer extends StatefulWidget {
  final List<GalleryMediaItem> mediaItems;
  final String professionalId;
  final int initialIndex;

  const GalleryImageViewer({
    super.key,
    required this.mediaItems,
    required this.professionalId,
    this.initialIndex = 0,
  });

  @override
  State<GalleryImageViewer> createState() => _GalleryImageViewerState();
}

class _GalleryImageViewerState extends State<GalleryImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mediaItems.isEmpty) {
      return const SizedBox.shrink();
    }

    // 9:16 portrait frame — height ~88% of screen, width derived, capped
    // so it never exceeds the screen width.
    final screen = MediaQuery.of(context).size;
    var dialogH = screen.height * 0.88;
    var dialogW = dialogH * 9 / 16;
    final maxW = screen.width * 0.92;
    if (dialogW > maxW) {
      dialogW = maxW;
      dialogH = dialogW * 16 / 9;
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Container(
        width: dialogW,
        height: dialogH,
        decoration: BoxDecoration(
          color: Color(0xFF000000),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Header with close button
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  if (widget.mediaItems.length > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${_currentIndex + 1}/${widget.mediaItems.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Image/Video viewer
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                itemCount: widget.mediaItems.length,
                itemBuilder: (context, index) {
                  final item = widget.mediaItems[index];
                  return _MediaViewerItem(item: item);
                },
              ),
            ),
            // Footer with Book Now button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.push('/professional/${widget.professionalId}');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlayaColors.berry,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Book Now',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaViewerItem extends StatelessWidget {
  final GalleryMediaItem item;

  const _MediaViewerItem({required this.item});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: item.mediaType == 'video'
          ? _VideoPlayerItem(item: item)
          : _ImagePlayerItem(item: item),
    );
  }
}

class _ImagePlayerItem extends StatelessWidget {
  final GalleryMediaItem item;

  const _ImagePlayerItem({required this.item});

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: item.mediaUrl.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: item.mediaUrl,
              fit: BoxFit.contain,
              placeholder: (_, __) => const Center(
                  child: CircularProgressIndicator(color: Colors.white)),
              errorWidget: (_, __, ___) => const Center(
                child: Icon(Icons.broken_image, color: Colors.white, size: 48),
              ),
            )
          : const Center(
              child: Icon(Icons.broken_image, color: Colors.white, size: 48)),
    );
  }
}

class _VideoPlayerItem extends StatelessWidget {
  final GalleryMediaItem item;

  const _VideoPlayerItem({required this.item});

  @override
  Widget build(BuildContext context) {
    // For now, show video thumbnail with play indicator
    // In a full implementation, you would use a video player package
    final thumbUrl = item.thumbnailUrl?.isNotEmpty == true
        ? item.thumbnailUrl!
        : item.mediaUrl;
    if (thumbUrl.isEmpty) {
      return const Center(
          child: Icon(Icons.broken_image, color: Colors.white, size: 48));
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        CachedNetworkImage(
          imageUrl: thumbUrl,
          fit: BoxFit.contain,
          placeholder: (_, __) => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
          errorWidget: (_, __, ___) => const Center(
            child: Icon(Icons.broken_image, color: Colors.white, size: 48),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Color(0xFF000000).withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.play_arrow, color: Colors.white, size: 64),
        ),
      ],
    );
  }
}
