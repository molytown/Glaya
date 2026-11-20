import 'package:flutter/material.dart';
import '../../../../shared/theme/colors.dart';

class TrustBanner extends StatelessWidget {
  final int trustScore;
  final int totalBookings;
  final double avgRating;

  const TrustBanner(
      {super.key,
      required this.trustScore,
      required this.totalBookings,
      required this.avgRating});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GlayaColors.berry.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Trust metrics',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A1A))),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _metric('Trust Score', '$trustScore%'),
              _metric('Bookings', '$totalBookings'),
              _metric('Rating', avgRating.toStringAsFixed(1)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B6B6B))),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: GlayaColors.berry)),
      ],
    );
  }
}
