import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../shared/theme/colors.dart';
import '../../data/professional_model.dart';

class ReviewsSection extends StatelessWidget {
  final ProfessionalModel professional;

  const ReviewsSection({super.key, required this.professional});

  @override
  Widget build(BuildContext context) {
    final reviews = professional.reviews ?? [];
    final avgRating = professional.avgRating ?? 0.0;
    final totalReviews = professional.totalReviews;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Reviews', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
              const Spacer(),
              Row(
                children: [
                  const Icon(Icons.star, color: Color(0xFFF59E0B), size: 18),
                  const SizedBox(width: 4),
                  Text(
                    avgRating.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '($totalReviews)',
                    style: const TextStyle(fontSize: 14, color: Color(0xFF888888)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (reviews.isEmpty)
            const Text('No reviews yet', style: TextStyle(fontSize: 14, color: Color(0xFF888888)))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: reviews.take(3).length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final review = reviews[i] as dynamic;
                return _ReviewCard(
                  reviewerName: review.reviewerName ?? 'Anonymous',
                  rating: review.rating ?? 0,
                  comment: review.comment ?? '',
                  createdAt: review.createdAt,
                );
              },
            ),
          TextButton(
            onPressed: () => context.push('/reviews', extra: professional.id),
            child: const Text('See All Reviews →', style: TextStyle(color: GlayaColors.berry, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final String reviewerName;
  final int rating;
  final String comment;
  final String? createdAt;

  const _ReviewCard({required this.reviewerName, required this.rating, required this.comment, this.createdAt});

  @override
  Widget build(BuildContext context) {
    String dateStr = '';
    if (createdAt != null) {
      try {
        final dt = DateTime.parse(createdAt!);
        dateStr = DateFormat('MMM d, y').format(dt);
      } catch (_) {}
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: GlayaColors.berry,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(reviewerName[0].toUpperCase(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(reviewerName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A))),
                    if (dateStr.isNotEmpty) Text(dateStr, style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
                  ],
                ),
              ),
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < rating ? Icons.star : Icons.star_border,
                    color: const Color(0xFFF59E0B),
                    size: 14,
                  );
                }),
              ),
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(comment, style: const TextStyle(fontSize: 13, color: Color(0xFF555555))),
          ],
        ],
      ),
    );
  }
}
