import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../shared/services/config_service.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/widgets/content_actions.dart';
import '../../data/professional_model.dart';
import 'booking_modal.dart';

class ServicesReviewsGrid extends ConsumerStatefulWidget {
  final ProfessionalModel professional;

  const ServicesReviewsGrid({super.key, required this.professional});

  @override
  ConsumerState<ServicesReviewsGrid> createState() =>
      _ServicesReviewsGridState();
}

class _ServicesReviewsGridState extends ConsumerState<ServicesReviewsGrid> {
  bool _showAllReviews = false;

  void _showBookingModal(ServiceItem? service) {
    showDialog(
      context: context,
      builder: (context) => BookingModal(
        professional: widget.professional,
        initialService: service,
        onClose: () => Navigator.of(context).pop(),
        onSuccess: () {
          // Refresh data if needed
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final services = (widget.professional.services ?? []).cast<ServiceItem>();
    final reviews = (widget.professional.reviews ?? []).cast<ReviewItem>();
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildServicesColumn(services)),
          const SizedBox(width: 20),
          Expanded(child: _buildReviewsColumn(reviews)),
        ],
      );
    }

    return Column(
      children: [
        _buildServicesColumn(services),
        const SizedBox(height: 16),
        _buildReviewsColumn(reviews),
      ],
    );
  }

  Widget _buildServicesColumn(List<ServiceItem> services) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Services',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A)),
          ),
          const SizedBox(height: 16),
          if (services.isEmpty)
            _buildEmptyState(Icons.content_cut, 'No services listed yet')
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.0,
              ),
              itemCount: services.length,
              itemBuilder: (context, index) =>
                  _buildServiceCard(services[index]),
            ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(ServiceItem service) {
    final configService = ConfigService();
    final imageUrl = service.imageUrl != null
        ? configService.replaceLocalhost(service.imageUrl!)
        : null;
    final rating = widget.professional.avgRating ?? 0.0;
    final currency = widget.professional.currency ?? 'XAF';

    return GestureDetector(
      onTap: () => _showBookingModal(service),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFFF5F5F5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image or placeholder
              if (imageUrl != null)
                CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => _buildServicePlaceholder(),
                  errorWidget: (_, __, ___) => _buildServicePlaceholder(),
                )
              else
                _buildServicePlaceholder(),
              // Rating badge (top left)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Color(0xFF000000).withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star,
                          size: 11, color: Color(0xFFFBBF24)),
                      const SizedBox(width: 3),
                      Text(
                        rating > 0 ? rating.toStringAsFixed(1) : 'New',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              // Price badge (top right)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Color(0xFF000000).withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${NumberFormat('#,##0').format(service.price)} $currency',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
                ),
              ),
              // Bottom overlay with name and book button
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Color(0xFF000000).withValues(alpha: 0.75),
                        Color(0xFF000000).withValues(alpha: 0.35),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          service.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _showBookingModal(service),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: GlayaColors.berry,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Book',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServicePlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFCE7F3), Color(0xFFFDF2F8)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.content_cut, size: 28, color: GlayaColors.berry),
      ),
    );
  }

  Widget _buildReviewsColumn(List<ReviewItem> reviews) {
    final sorted = [...reviews]
      ..sort((a, b) => (DateTime.tryParse(b.createdAt ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(DateTime.tryParse(a.createdAt ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0)));
    final visible = _showAllReviews ? sorted : sorted.take(4).toList();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reviews',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A)),
          ),
          const SizedBox(height: 16),
          if (reviews.isEmpty)
            _buildEmptyState(Icons.star_outline, 'No reviews yet')
          else ...[
            ...visible.map((review) => _buildReviewCard(review)),
            if (reviews.length > 4)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () =>
                      setState(() => _showAllReviews = !_showAllReviews),
                  child: Text(
                    _showAllReviews
                        ? 'Show less'
                        : 'See all ${reviews.length} reviews',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: GlayaColors.berry),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewCard(ReviewItem review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(10),
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
                  child: Text(
                    review.reviewerName.isNotEmpty
                        ? review.reviewerName[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(review.reviewerName,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A))),
                    Row(
                      children: List.generate(
                          5,
                          (i) => Icon(
                                i < review.rating
                                    ? Icons.star
                                    : Icons.star_border,
                                size: 12,
                                color: i < review.rating
                                    ? const Color(0xFFF59E0B)
                                    : const Color(0xFFE5E7EB),
                              )),
                    ),
                  ],
                ),
              ),
              if (review.id != null && review.reviewerId != null)
                GestureDetector(
                  onTap: () => ContentActions.show(
                    context,
                    targetType: 'review',
                    targetId: review.id!,
                    reportedUserId: review.reviewerId,
                    displayName: review.reviewerName,
                  ),
                  child: const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.more_vert,
                        color: Color(0xFF000000), size: 18),
                  ),
                ),
              if (review.createdAt != null)
                Text(
                  _formatDate(review.createdAt!),
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF000000)),
                ),
            ],
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '"${review.comment}"',
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF555555), height: 1.5),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('MMM d').format(dt);
    } catch (_) {
      return '';
    }
  }

  Widget _buildEmptyState(IconData icon, String message) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(icon, size: 32, color: const Color(0xFFCCCCCC)),
          const SizedBox(height: 12),
          Text(message,
              style: const TextStyle(fontSize: 14, color: Color(0xFF000000))),
        ],
      ),
    );
  }
}
