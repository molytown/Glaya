import 'package:flutter/material.dart';
import '../../../../shared/theme/colors.dart';

/// Placeholder section for "How Glaya Works"
/// TODO: Connect to backend API when ready
class HowItWorksSection extends StatelessWidget {
  const HowItWorksSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: GlayaColors.berry.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How Glaya Works',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: GlayaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _StepItem(
            icon: Icons.search,
            title: 'Find',
            description: 'Search for beauty professionals near you',
          ),
          const SizedBox(height: 12),
          _StepItem(
            icon: Icons.calendar_today,
            title: 'Book',
            description: 'Schedule your appointment instantly',
          ),
          const SizedBox(height: 12),
          _StepItem(
            icon: Icons.check_circle,
            title: 'Glow',
            description: 'Enjoy your beauty service',
          ),
        ],
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _StepItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: GlayaColors.berry.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: GlayaColors.berry,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: GlayaColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF000000),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
