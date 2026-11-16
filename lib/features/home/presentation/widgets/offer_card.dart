import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../shared/theme/colors.dart';

class OfferCard extends StatelessWidget {
  final String title;
  final String description;
  final String discountLabel;
  final String ctaText;
  final VoidCallback? onTap;

  const OfferCard({
    super.key,
    required this.title,
    required this.description,
    required this.discountLabel,
    this.ctaText = 'Book Now',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: GlayaColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GlayaColors.vibrantPink),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: GlayaColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(fontSize: 11, color: GlayaColors.textGray, height: 1.4),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: GlayaColors.berry,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      ctaText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(color: GlayaColors.berry, shape: BoxShape.circle),
            child: Center(
              child: Text(
                discountLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideX(begin: 0.08, end: 0);
  }
}

class OfferCardRow extends StatelessWidget {
  final List<Map<String, dynamic>> offers;

  const OfferCardRow({super.key, required this.offers});

  @override
  Widget build(BuildContext context) {
    final items = offers.isEmpty
        ? [
            {
              'title': 'Weekend Glow Deal',
              'description': 'Get 5% OFF on all services this weekend only!',
              'discountLabel': '5%\nOFF',
              'ctaText': 'Book Now',
            },
          ]
        : offers;

    return SizedBox(
      height: 130,
      child: ListView.builder(
        padding: const EdgeInsets.only(left: 16),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        itemBuilder: (_, index) {
          final offer = items[index];
          return OfferCard(
            title: offer['title'] as String? ?? '',
            description: offer['description'] as String? ?? '',
            discountLabel: offer['discountLabel'] as String? ?? '%',
            ctaText: offer['ctaText'] as String? ?? 'Book Now',
          );
        },
      ),
    );
  }
}
