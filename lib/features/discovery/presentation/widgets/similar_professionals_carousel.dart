import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../shared/theme/colors.dart';
import '../../data/professional_model.dart';
import '../discovery_provider.dart';

class SimilarProfessionalsCarousel extends ConsumerWidget {
  final String category;
  final String? excludeId;

  const SimilarProfessionalsCarousel({
    super.key,
    required this.category,
    this.excludeId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final similarAsync = ref.watch(similarProfessionalsProvider(category));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('You May Also Like',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A1A))),
          const SizedBox(height: 12),
          similarAsync.when(
            data: (professionals) {
              final filtered = excludeId == null
                  ? professionals
                  : professionals.where((p) => p.id != excludeId).toList();
              if (filtered.isEmpty) {
                return const Text('No similar professionals found',
                    style: TextStyle(fontSize: 14, color: Color(0xFF000000)));
              }
              return SizedBox(
                height: 160,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) {
                    final prof = filtered[i];
                    return _ProfessionalCard(professional: prof);
                  },
                ),
              );
            },
            loading: () => const Center(
                child: CircularProgressIndicator(color: GlayaColors.berry)),
            error: (_, __) => const Text('Failed to load similar professionals',
                style: TextStyle(fontSize: 14, color: Color(0xFF000000))),
          ),
        ],
      ),
    );
  }
}

class _ProfessionalCard extends StatelessWidget {
  final ProfessionalModel professional;

  const _ProfessionalCard({required this.professional});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/professional/${professional.id}'),
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEEEEEE)),
          boxShadow: [
            BoxShadow(
                color: Color(0xFF000000).withValues(alpha: 0.04), blurRadius: 8)
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: CachedNetworkImage(
                imageUrl: professional.photoUrl ?? '',
                height: 90,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    Container(color: GlayaColors.berry.withValues(alpha: 0.1)),
                errorWidget: (_, __, ___) =>
                    Container(color: GlayaColors.berry.withValues(alpha: 0.1)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(professional.name,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(professional.category,
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFF000000))),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star,
                          color: Color(0xFFF59E0B), size: 11),
                      const SizedBox(width: 2),
                      Text(
                        (professional.avgRating ?? 0.0).toStringAsFixed(1),
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A)),
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
