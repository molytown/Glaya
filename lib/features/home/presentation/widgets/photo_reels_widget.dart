import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../shared/services/config_service.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/utils/responsive_helper.dart';
import '../../../../shared/widgets/verification_badge.dart';
import '../../../reels/data/models/reel_model.dart';
import '../../../reels/data/repositories/reel_repository.dart';
import '../../../../shared/providers/location_provider.dart';

/// Widget for displaying photo-only reels in a vertical 1-column layout on tablet
/// or horizontal carousel on mobile
class PhotoReelsWidget extends ConsumerStatefulWidget {
  final String? categoryName;
  final String? serviceId;

  const PhotoReelsWidget({
    super.key,
    this.categoryName,
    this.serviceId,
  });

  @override
  ConsumerState<PhotoReelsWidget> createState() => _PhotoReelsWidgetState();
}

class _PhotoReelsWidgetState extends ConsumerState<PhotoReelsWidget> {
  final ReelRepository _reelRepository = ReelRepository();
  final ScrollController _scrollController = ScrollController();
  List<Reel> _photoReels = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPhotoReels();
  }

  Future<void> _loadPhotoReels() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final locationState = ref.read(locationProvider);
      final reels = await _reelRepository.getReels(
        zoneParams: zoneQueryParams(locationState),
      );

      if (mounted) {
        setState(() {
          // Filter for photo-only reels
          _photoReels = reels.where((r) => r.isPhoto).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_photoReels.isEmpty) {
      return const SizedBox.shrink();
    }

    final isTablet = ResponsiveHelper.isTablet(context);

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
                      text: 'Photos',
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
        if (isTablet)
          _GridPhotoRow(reels: _photoReels)
        else
          _HorizontalPhotoCarousel(reels: _photoReels),
      ],
    );
  }
}

class _HorizontalPhotoCarousel extends StatelessWidget {
  final List<Reel> reels;

  const _HorizontalPhotoCarousel({required this.reels});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: reels.length,
        itemBuilder: (context, index) {
          return _PhotoCard(reel: reels[index]);
        },
      ),
    );
  }
}

/// Horizontally-scrollable grid row for tablet: ~5 photo cards visible at
/// a time, sized to fill the row width, more revealed on scroll.
class _GridPhotoRow extends StatelessWidget {
  final List<Reel> reels;

  const _GridPhotoRow({required this.reels});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        const visibleCount = 5;
        // Desktop-only: cards are 20% taller than tablet.
        final isDesktop = ResponsiveHelper.isDesktop(context);
        final rowHeight = isDesktop ? 264.0 : 220.0;
        final cardHeight = isDesktop ? 252.0 : 210.0;
        // Each _PhotoCard carries a 12px right margin, so reserve gap space
        // for every visible card (including the trailing one).
        final cardWidth =
            ((constraints.maxWidth - 32 - gap * visibleCount) / visibleCount)
                .clamp(150.0, 240.0);

        return SizedBox(
          height: rowHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: reels.length,
            itemBuilder: (context, index) {
              return _PhotoCard(
                reel: reels[index],
                width: cardWidth,
                height: cardHeight,
              );
            },
          ),
        );
      },
    );
  }
}

class _PhotoCard extends StatelessWidget {
  final Reel reel;
  final double? width;
  final double? height;

  const _PhotoCard({
    required this.reel,
    this.width = 120,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    final configService = ConfigService();
    final professionalName = reel.isUserReel
        ? (reel.user?.name?.split(' ').first ?? 'User')
        : (reel.taggedProfessional?.user?.name?.split(' ')[0] ??
            'Professional');
    final uploaderPhoto = reel.isUserReel
        ? reel.user?.photoUrl
        : reel.taggedProfessional?.user?.photoUrl;

    return GestureDetector(
      onTap: () {
        // TODO: Navigate to reel viewer or gallery viewer
      },
      child: Container(
        width: width,
        height: height,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey[200],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: configService.replaceLocalhost(reel.videoUrl),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorWidget: (_, __, ___) => Container(
                color: Colors.grey[300],
                child: const Icon(Icons.broken_image, color: Colors.grey),
              ),
            ),
            Container(
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
            ),
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (reel.title != null)
                    Text(
                      reel.title!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (uploaderPhoto != null) ...[
                        CircleAvatar(
                          radius: 10,
                          backgroundImage: NetworkImage(
                            configService.replaceLocalhost(uploaderPhoto),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          'by $professionalName',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!reel.isUserReel &&
                          reel.taggedProfessional != null) ...[
                        const SizedBox(width: 6),
                        VerificationBadge(
                          subscriptionType:
                              reel.taggedProfessional!.subscriptionType,
                        ),
                      ],
                    ],
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
