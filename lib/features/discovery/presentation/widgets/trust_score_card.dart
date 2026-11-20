import 'package:flutter/material.dart';
import '../../../../shared/theme/colors.dart';

class TrustScoreCard extends StatelessWidget {
  final int trustScore;
  final int totalBookings;
  final double avgRating;

  const TrustScoreCard(
      {super.key,
      required this.trustScore,
      required this.totalBookings,
      required this.avgRating});

  @override
  Widget build(BuildContext context) {
    final completionRate =
        (totalBookings > 0) ? (trustScore * 0.01).clamp(0.0, 1.0) : 0.0;
    final satisfactionRate = avgRating / 5.0;
    final onTimeRate = (trustScore / 100.0).clamp(0.0, 1.0);
    const acceptanceRate = 0.92;
    const cancellationRate = 0.05;
    const repeatRate = 0.45;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFEEEEEE))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Glaya Trust Score',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1A1A))),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: GlayaColors.berry.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star,
                            color: GlayaColors.berry, size: 16),
                        const SizedBox(width: 4),
                        Text(avgRating.toStringAsFixed(1),
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: GlayaColors.berry)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _metricRow(
                  'Completed Appointments', completionRate, '$totalBookings'),
              _metricRow('Customer Satisfaction', satisfactionRate,
                  '${(avgRating * 20).toInt()}%'),
              _metricRow('On-Time Performance', onTimeRate, '$trustScore%'),
              _metricRow('Acceptance Rate', acceptanceRate, '92%'),
              _metricRow('Cancellation Rate', cancellationRate, '5%'),
              _metricRow('Repeat Customers', repeatRate, '45%'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricRow(String label, double value, String displayValue) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style:
                      const TextStyle(fontSize: 13, color: Color(0xFF555555))),
              Text(displayValue,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A))),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: value,
            backgroundColor: const Color(0xFFEEEEEE),
            valueColor: const AlwaysStoppedAnimation<Color>(GlayaColors.berry),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }
}
