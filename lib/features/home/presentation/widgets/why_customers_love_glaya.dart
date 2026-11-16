import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/theme/colors.dart';

class WhyCustomersLoveGlayaSection extends StatefulWidget {
  const WhyCustomersLoveGlayaSection({super.key});

  @override
  State<WhyCustomersLoveGlayaSection> createState() => _WhyCustomersLoveGlayaSectionState();
}

class _WhyCustomersLoveGlayaSectionState extends State<WhyCustomersLoveGlayaSection> {
  int _reviewIndex = 0;
  late final List<CustomerReview> _reviews;

  @override
  void initState() {
    super.initState();
    _reviews = _getFallbackReviews();
    _startAutoRotate();
  }

  void _startAutoRotate() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 5));
      if (mounted) {
        setState(() {
          _reviewIndex = (_reviewIndex + 1) % _reviews.length;
        });
        return true;
      }
      return false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final review = _reviews[_reviewIndex];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Why Customers Love Glaya',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              GestureDetector(
                onTap: () => context.push('/reviews'),
                child: Row(
                  children: [
                    const Text(
                      'View all',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: GlayaColors.berry,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      size: 13,
                      color: GlayaColors.berry,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ReviewCard(review: review),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _NavButton(
                icon: Icons.chevron_left,
                onTap: () {
                  setState(() {
                    _reviewIndex = (_reviewIndex - 1 + _reviews.length) % _reviews.length;
                  });
                },
              ),
              Row(
                children: List.generate(_reviews.length, (index) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _reviewIndex = index;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2.5),
                      width: index == _reviewIndex ? 20 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: index == _reviewIndex ? GlayaColors.berry : const Color(0xFFEEEEEE),
                        borderRadius: BorderRadius.circular(index == _reviewIndex ? 4 : 3.5),
                      ),
                    ),
                  );
                }),
              ),
              _NavButton(
                icon: Icons.chevron_right,
                onTap: () {
                  setState(() {
                    _reviewIndex = (_reviewIndex + 1) % _reviews.length;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<CustomerReview> _getFallbackReviews() {
    return const [
      CustomerReview(
        reviewerName: 'Adaeze N.',
        rating: 5,
        comment: "The best beauty app I've used! Found amazing professionals and the booking process is so easy.",
        createdAt: '2 days ago',
      ),
      CustomerReview(
        reviewerName: 'Fatima K.',
        rating: 5,
        comment: 'Booked a makeup artist in 5 minutes. She was professional and on time. Glaya is amazing!',
        createdAt: '3 days ago',
      ),
      CustomerReview(
        reviewerName: 'Chioma B.',
        rating: 5,
        comment: 'My nails look fantastic! Great service and very affordable. Will definitely book again.',
        createdAt: '1 week ago',
      ),
    ];
  }
}

class _ReviewCard extends StatelessWidget {
  final CustomerReview review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: GlayaColors.berry,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    review.reviewerName[0],
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.reviewerName,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        ...List.generate(5, (index) {
                          return Icon(
                            Icons.star,
                            size: 14,
                            color: index < review.rating ? const Color(0xFFF59E0B) : const Color(0xFFD1D5DB),
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                review.createdAt,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF9E9E9E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '"${review.comment}"',
            style: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF6B7280),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _NavButton({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
        child: Icon(
          icon,
          size: 14,
          color: const Color(0xFF9E9E9E),
        ),
      ),
    );
  }
}

class CustomerReview {
  final String reviewerName;
  final int rating;
  final String comment;
  final String createdAt;

  const CustomerReview({
    required this.reviewerName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });
}
