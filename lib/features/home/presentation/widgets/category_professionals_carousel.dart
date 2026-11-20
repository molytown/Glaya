import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../discovery/data/professional_model.dart';
import '../../../discovery/presentation/discovery_provider.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/utils/haptic_feedback.dart';
import '../../../../shared/widgets/verification_badge.dart';

class CategoryProfessionalsCarousel extends ConsumerWidget {
  final String categoryName;
  final String serviceId;

  const CategoryProfessionalsCarousel({
    super.key,
    required this.categoryName,
    required this.serviceId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final professionalsAsync =
        ref.watch(categoryProfessionalsProvider(categoryName));

    return professionalsAsync.when(
      data: (professionals) {
        if (professionals.isEmpty) {
          return const SizedBox.shrink();
        }

        return SizedBox(
          height: 250,
          child: ListView.builder(
            padding: const EdgeInsets.only(left: 16),
            scrollDirection: Axis.horizontal,
            itemCount: professionals.length,
            itemBuilder: (context, index) {
              final professional = professionals[index];
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _CategoryProfessionalCard(
                  professional: professional,
                  rating: professional.avgRating ?? 0.0,
                ),
              );
            },
          ),
        );
      },
      loading: () => const SizedBox(
        height: 250,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _CategoryProfessionalCard extends ConsumerWidget {
  final ProfessionalModel professional;
  final double rating;

  const _CategoryProfessionalCard({
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
        width: 160,
        height: 250,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: GlayaColors.softShadow,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image — 1:1 square
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: professional.photoUrl?.isNotEmpty == true
                    ? CachedNetworkImage(
                        imageUrl: professional.photoUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorWidget: (_, __, ___) => Container(
                          color:
                              GlayaColors.vibrantPink.withValues(alpha: 0.25),
                          child: const Icon(Icons.person,
                              size: 48, color: GlayaColors.berry),
                        ),
                      )
                    : Container(
                        color: GlayaColors.vibrantPink.withValues(alpha: 0.25),
                        child: const Icon(Icons.person,
                            size: 48, color: GlayaColors.berry),
                      ),
              ),
            ),
            // Details
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          professional.name.split(' ').first,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF000000),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      VerificationBadge(
                          subscriptionType: professional.subscriptionType),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    professional.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
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
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF000000),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 6,
                        height: 6,
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
          ],
        ),
      ),
    );
  }
}
