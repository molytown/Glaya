import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/utils/haptic_feedback.dart';
import '../../../../shared/widgets/price_display.dart';
import '../../../../shared/widgets/verification_badge.dart';
import '../../../discovery/data/professional_model.dart';
import 'home_utils.dart';

class ProfessionalCard extends ConsumerWidget {
  final ProfessionalModel professional;
  final double rating;
  final String? priceLabel;
  final String distanceLabel;

  const ProfessionalCard({
    super.key,
    required this.professional,
    required this.rating,
    this.priceLabel,
    this.distanceLabel = '2.3 km away',
  });

  Color _getStatusColor() {
    final status = professional.cardStatus;
    if (status == 'offline' || status == 'closed') {
      return Colors.red;
    } else if (status == 'busy') {
      return Colors.orange;
    } else if (status == 'traveling') {
      return Colors.blue;
    } else {
      return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get the minimum price from services if available
    final minPrice = professional.services?.isNotEmpty == true
        ? professional.services!
            .map((s) => (s as dynamic).price as double? ?? 0)
            .reduce((a, b) => a < b ? a : b)
        : 25.0; // Default fallback price

    return GestureDetector(
      onTap: () {
        HapticFeedback.light();
        context.push('/professional/${professional.id}');
      },
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: GlayaColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: GlayaColors.softShadow,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  child: professional.photoUrl?.isNotEmpty == true
                      ? CachedNetworkImage(
                          imageUrl: professional.photoUrl!,
                          height: 90,
                          width: 150,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _photoPlaceholder(),
                        )
                      : _photoPlaceholder(),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: GlayaColors.surface.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: GlayaColors.softShadow,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star,
                            color: GlayaColors.warning, size: 13),
                        const SizedBox(width: 3),
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _getStatusColor(),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF000000).withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            professional.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: GlayaColors.textPrimary,
                            ),
                          ),
                        ),
                        VerificationBadge(
                            subscriptionType: professional.subscriptionType),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      professional.category,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF000000)),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            size: 12, color: Color(0xFF000000)),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            distanceLabel,
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF000000)),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        if (priceLabel != null)
                          Text(
                            priceLabel!,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: GlayaColors.berry,
                            ),
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

  Widget _photoPlaceholder() => Container(
        height: 120,
        width: 140,
        color: GlayaColors.vibrantPink.withValues(alpha: 0.25),
        child: const Icon(Icons.person, size: 48, color: GlayaColors.berry),
      );
}

class ProfessionalCardRow extends StatelessWidget {
  final List<ProfessionalModel> professionals;

  const ProfessionalCardRow({super.key, required this.professionals});

  @override
  Widget build(BuildContext context) {
    final items = professionals.isEmpty
        ? List<ProfessionalModel?>.filled(3, null)
        : professionals.take(6).toList();

    return SizedBox(
      height: 220,
      child: ListView.builder(
        padding: const EdgeInsets.only(left: 16),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        itemBuilder: (_, index) {
          final pro = items[index];
          if (pro == null) return _placeholderCard();
          return ProfessionalCard(
            professional: pro,
            rating: professionalRating(pro.trustScore),
            priceLabel: professionalPriceLabel(pro),
          );
        },
      ),
    );
  }

  Widget _placeholderCard() => Container(
        width: 150,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: GlayaColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: GlayaColors.softShadow,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              height: 130,
              decoration: const BoxDecoration(
                color: GlayaColors.blushPink,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Container(
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ),
      );
}

class TopRatedProfessionalsCarousel extends StatefulWidget {
  final List<ProfessionalModel> professionals;

  /// Desktop mode: show exactly this many cards and let the user drag-scroll.
  /// Null keeps the legacy auto-scrolling mobile/tablet behavior.
  final int? visibleCount;

  /// Card width/height ratio used in [visibleCount] mode (e.g. 9/16).
  final double? cardAspectRatio;

  const TopRatedProfessionalsCarousel({
    super.key,
    required this.professionals,
    this.visibleCount,
    this.cardAspectRatio,
  });

  @override
  State<TopRatedProfessionalsCarousel> createState() =>
      _TopRatedProfessionalsCarouselState();
}

class _TopRatedProfessionalsCarouselState
    extends State<TopRatedProfessionalsCarousel> {
  final ScrollController _scrollController = ScrollController();
  Timer? _autoScrollTimer;
  double _scrollOffset = 0.0;

  @override
  void initState() {
    super.initState();
    // Auto-scroll only applies to the legacy (mobile/tablet) layout.
    if (widget.visibleCount == null) _startAutoScroll();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _autoScrollTimer?.cancel();
    super.dispose();
  }

  void _startAutoScroll() {
    _autoScrollTimer =
        Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (_scrollController.hasClients && widget.professionals.isNotEmpty) {
        setState(() {
          _scrollOffset += 0.5;
          final maxScroll = _scrollController.position.maxScrollExtent;
          if (_scrollOffset >= maxScroll) {
            _scrollOffset = 0;
            _scrollController.jumpTo(0);
          } else {
            _scrollController.jumpTo(_scrollOffset);
          }
        });
      }
    });
  }

  Widget _placeholderCard() => Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: GlayaColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: GlayaColors.softShadow,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: GlayaColors.blushPink,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final items = widget.professionals.isEmpty
        ? List<ProfessionalModel?>.filled(3, null)
        : widget.professionals.toList();

    if (items.isEmpty) {
      return const SizedBox(height: 220);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Breakpoint must use the real screen width — constraints.maxWidth
        // here is the half-column width inside SideBySideSection on tablet.
        final isMobile = MediaQuery.of(context).size.width < 600;
        final availableWidth = constraints.maxWidth;

        // Desktop: fixed count of 9:16 cards, drag-scrollable (mouse pull).
        if (widget.visibleCount != null) {
          const gap = 12.0;
          final count = widget.visibleCount!;
          final cardWidth = (availableWidth - gap * (count - 1)) / count;
          final cardHeight =
              cardWidth / (widget.cardAspectRatio ?? (9 / 16));
          return SizedBox(
            height: cardHeight,
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              itemBuilder: (context, index) {
                final pro = items[index % items.length];
                if (pro == null) {
                  return SizedBox(
                    width: cardWidth,
                    child: _placeholderCard(),
                  );
                }
                return Padding(
                  padding: EdgeInsets.only(
                      right: index == items.length - 1 ? 0 : gap),
                  child: SizedBox(
                    width: cardWidth,
                    child: _TopRatedFullImageCard(
                      professional: pro,
                      rating: professionalRating(pro.trustScore),
                      aspectRatio: widget.cardAspectRatio ?? (9 / 16),
                    ),
                  ),
                );
              },
            ),
          );
        }

        // Tablet: portrait 1:2 cards (~2.2 visible). Mobile: square cards.
        final cardWidth =
            isMobile ? (availableWidth - 32) / 2 : (availableWidth - 32) / 2.2;
        final cardHeight = isMobile ? cardWidth : cardWidth * 1.4;
        final cardPadding = isMobile ? 4.0 : 6.0;

        return SizedBox(
          height: cardHeight,
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length * 2,
            itemBuilder: (context, index) {
              final pro = items[index % items.length];
              if (pro == null) {
                return SizedBox(
                  width: cardWidth,
                  child: _placeholderCard(),
                );
              }
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: cardPadding),
                child: SizedBox(
                  width: cardWidth,
                  child: _TopRatedFullImageCard(
                    professional: pro,
                    rating: professionalRating(pro.trustScore),
                    aspectRatio: isMobile ? 1 : 1 / 1.4,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _TopRatedFullImageCard extends StatelessWidget {
  final ProfessionalModel professional;
  final double rating;
  final double aspectRatio;

  const _TopRatedFullImageCard({
    required this.professional,
    required this.rating,
    this.aspectRatio = 1,
  });

  Color _getStatusColor() {
    final status = professional.cardStatus;
    if (status == 'offline' || status == 'closed') {
      return Colors.red;
    } else if (status == 'busy') {
      return Colors.orange;
    } else if (status == 'traveling') {
      return Colors.blue;
    } else {
      return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/professional/${professional.id}'),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: GlayaColors.softShadow,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: Stack(
              children: [
                Positioned.fill(
                  child: professional.photoUrl?.isNotEmpty == true
                      ? CachedNetworkImage(
                          imageUrl: professional.photoUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            color:
                                GlayaColors.vibrantPink.withValues(alpha: 0.25),
                            child: const Icon(Icons.person,
                                size: 48, color: GlayaColors.berry),
                          ),
                        )
                      : Container(
                          color:
                              GlayaColors.vibrantPink.withValues(alpha: 0.25),
                          child: const Icon(Icons.person,
                              size: 48, color: GlayaColors.berry),
                        ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Color(0xFF000000).withValues(alpha: 0.3),
                          Color(0xFF000000).withValues(alpha: 0.7),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _getStatusColor(),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF000000).withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.star,
                          size: 12,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                professional.name.split(' ').first,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            VerificationBadge(
                                subscriptionType:
                                    professional.subscriptionType),
                          ],
                        ),
                        const SizedBox(height: 1),
                        Text(
                          professional.category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 14,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                professional.displayArea ??
                                    'Location not specified',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white70,
                                ),
                              ),
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
        ),
      ),
    );
  }
}

class RecommendedProfessionalRow extends StatelessWidget {
  final List<ProfessionalModel> professionals;

  const RecommendedProfessionalRow({super.key, required this.professionals});

  @override
  Widget build(BuildContext context) {
    final items = professionals.isEmpty
        ? List<ProfessionalModel?>.filled(4, null)
        : professionals.take(6).toList();

    return SizedBox(
      height: 168,
      child: ListView.builder(
        padding: const EdgeInsets.only(left: 16),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        itemBuilder: (_, index) {
          final pro = items[index];
          if (pro == null) {
            return Container(
              width: 105,
              margin: const EdgeInsets.only(right: 14),
              child: Column(
                children: [
                  Container(
                    height: 95,
                    decoration: BoxDecoration(
                      color: GlayaColors.blushPink,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: GlayaColors.softShadow,
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 12,
                    width: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            );
          }

          final rating = professionalRating(pro.trustScore);
          return GestureDetector(
            onTap: () {
              HapticFeedback.light();
              context.push('/professional/${pro.id}');
            },
            child: Container(
              width: 105,
              margin: const EdgeInsets.only(right: 14),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: pro.photoUrl?.isNotEmpty == true
                        ? CachedNetworkImage(
                            imageUrl: pro.photoUrl!,
                            height: 95,
                            width: 105,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            height: 95,
                            width: 105,
                            color: GlayaColors.blushPink,
                            child: const Icon(Icons.person,
                                color: GlayaColors.berry, size: 40),
                          ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    pro.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: GlayaColors.textPrimary,
                    ),
                  ),
                  Text(
                    pro.categories.isNotEmpty
                        ? pro.categories.take(2).join(' • ')
                        : pro.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: GlayaColors.textGray,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.star,
                          size: 11, color: GlayaColors.warning),
                      Text(
                        ' ${rating.toStringAsFixed(1)}',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF000000)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
