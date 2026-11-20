import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/theme/colors.dart';
import '../../../../shared/utils/haptic_feedback.dart';
import '../../../../shared/widgets/verification_badge.dart';
import '../../home/presentation/widgets/home_utils.dart';
import '../data/professional_model.dart';
import 'discovery_provider.dart';

class CategoryProfessionalsPage extends ConsumerWidget {
  final String slug;
  final String? name;

  const CategoryProfessionalsPage({super.key, required this.slug, this.name});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final professionalsAsync = ref.watch(professionalsProvider(slug));

    return Scaffold(
      backgroundColor: GlayaColors.background,
      appBar: AppBar(
        backgroundColor: GlayaColors.berry,
        foregroundColor: Colors.white,
        title: Text(name ?? _titleFor(slug)),
      ),
      body: professionalsAsync.when(
        data: (professionals) {
          if (professionals.isEmpty) {
            return const _EmptyState();
          }
          return RefreshIndicator(
            color: GlayaColors.berry,
            onRefresh: () async => ref.invalidate(professionalsProvider(slug)),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: professionals.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, index) =>
                  _ProfessionalTile(professional: professionals[index]),
            ),
          );
        },
        loading: () => const Center(
            child: CircularProgressIndicator(color: GlayaColors.berry)),
        error: (e, _) => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Could not load professionals. Pull down to retry.',
              textAlign: TextAlign.center,
              style: TextStyle(color: GlayaColors.textSecondary),
            ),
          ),
        ),
      ),
    );
  }

  static String _titleFor(String slug) => slug
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

class _ProfessionalTile extends StatelessWidget {
  final ProfessionalModel professional;

  const _ProfessionalTile({required this.professional});

  @override
  Widget build(BuildContext context) {
    final rating = professionalRating(professional.trustScore);
    final priceLabel = professionalPriceLabel(professional);
    return GestureDetector(
      onTap: () {
        HapticFeedback.light();
        context.push('/professional/${professional.id}');
      },
      child: Container(
        padding: const EdgeInsets.all(12),
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
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 72,
                height: 72,
                child: professional.photoUrl != null
                    ? CachedNetworkImage(
                        imageUrl: professional.photoUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _placeholder(),
                      )
                    : _placeholder(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
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
                            fontSize: 15,
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
                    professional.category.isNotEmpty
                        ? professional.category
                        : 'Professional',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: GlayaColors.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.star,
                          size: 14, color: GlayaColors.warning),
                      const SizedBox(width: 4),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: GlayaColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        priceLabel,
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
            const Icon(Icons.chevron_right, color: GlayaColors.textGray),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: GlayaColors.vibrantPink.withValues(alpha: 0.25),
        child: const Icon(Icons.person, size: 32, color: GlayaColors.berry),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.content_cut, size: 56, color: GlayaColors.textGray),
          SizedBox(height: 12),
          Text(
            'No professionals in this category yet',
            style: TextStyle(fontSize: 15, color: GlayaColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
