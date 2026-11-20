import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../discovery/data/professional_model.dart';
import 'professional_card.dart';
import 'home_utils.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/utils/haptic_feedback.dart';
import '../../../../shared/utils/responsive_helper.dart';
import '../../../../shared/widgets/verification_badge.dart';

class HomeServiceCarousel extends StatelessWidget {
  final List<ProfessionalModel> professionals;

  const HomeServiceCarousel({super.key, required this.professionals});

  @override
  Widget build(BuildContext context) {
    if (professionals.isEmpty) {
      return const SizedBox.shrink();
    }

    // Tablet (side-by-side column): show 2 cards at a time in a fixed-height
    // vertically-scrollable list so more professionals can be revealed.
    if (ResponsiveHelper.isTablet(context)) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          height: 232, // 2 x 110px cards + 12px gap
          child: ListView.builder(
            itemCount: professionals.length,
            itemBuilder: (context, index) {
              final professional = professionals[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _HomeServiceListCard(
                  professional: professional,
                  rating: professional.avgRating ?? 0.0,
                ),
              );
            },
          ),
        ),
      );
    }

    final displayProfessionals = professionals.take(3).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: displayProfessionals.map((professional) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _HomeServiceListCard(
              professional: professional,
              rating: professional.avgRating ?? 0.0,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _HomeServiceListCard extends ConsumerWidget {
  final ProfessionalModel professional;
  final double rating;

  const _HomeServiceListCard({
    required this.professional,
    required this.rating,
  });

  Color _getStatusColor() {
    if (professional.cardStatus == 'offline' ||
        professional.cardStatus == 'closed') {
      return Colors.red;
    } else if (professional.totalBookings >= 5) {
      return Colors.yellow;
    } else {
      return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.light();
        context.push('/professional/${professional.id}');
      },
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: GlayaColors.softShadow,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left: Image
            Padding(
              padding: const EdgeInsets.all(12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 76,
                  height: 76,
                  child: professional.photoUrl?.isNotEmpty == true
                      ? CachedNetworkImage(
                          imageUrl: professional.photoUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            color:
                                GlayaColors.vibrantPink.withValues(alpha: 0.25),
                            child: const Icon(Icons.person,
                                size: 32, color: GlayaColors.berry),
                          ),
                        )
                      : Container(
                          color:
                              GlayaColors.vibrantPink.withValues(alpha: 0.25),
                          child: const Icon(Icons.person,
                              size: 32, color: GlayaColors.berry),
                        ),
                ),
              ),
            ),
            // Middle: Details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            professional.businessName ?? professional.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF000000),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        VerificationBadge(
                            subscriptionType: professional.subscriptionType),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.person_outline,
                          size: 12,
                          color: Color(0xFF000000),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            professional.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF000000),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.work_outline,
                          size: 12,
                          color: Color(0xFF000000),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            professional.category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF000000),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          size: 14,
                          color: Color(0xFF000000),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF000000),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _getStatusColor(),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Right: Book button
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.light();
                  context.push('/professional/${professional.id}');
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD6006E),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD6006E).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Book',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
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
