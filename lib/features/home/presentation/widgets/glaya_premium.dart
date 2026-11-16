import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/theme/colors.dart';

class GlayaPremiumSection extends StatelessWidget {
  const GlayaPremiumSection({super.key});

  @override
  Widget build(BuildContext context) {
    final premium = _getFallbackPremium();

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFD6006E),
            Color(0xFF880E4F),
            Color(0xFF7209B7),
            Color(0xFFB5179E),
            Color(0xFFD6006E),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: GlayaColors.berry.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        '👑',
                        style: TextStyle(fontSize: 18),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        premium.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withOpacity(0.92),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    premium.description,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...premium.features.map((feature) => Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            feature,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.white.withOpacity(0.92),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () => context.push('/premium'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Upgrade Now',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: GlayaColors.berry,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Icon(
                            Icons.arrow_forward,
                            size: 14,
                            color: GlayaColors.berry,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: 110,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withOpacity(0.08),
                  Colors.white.withOpacity(0.04),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Premium _getFallbackPremium() {
    return const Premium(
      name: 'Glaya Premium',
      description: 'More Glow. More Benefits.',
      features: [
        'Up to 20% off on all services',
        'Priority booking with top pros',
        'Exclusive offers & early access',
        'Free reschedule (1x per month)',
      ],
      badgeColor: Color(0xFFD6006E),
    );
  }
}

class Premium {
  final String name;
  final String description;
  final List<String> features;
  final Color badgeColor;

  const Premium({
    required this.name,
    required this.description,
    required this.features,
    required this.badgeColor,
  });
}
