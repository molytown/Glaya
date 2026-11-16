import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/theme/colors.dart';
import 'home_utils.dart';

class PremiumBanner extends StatelessWidget {
  final Map<String, dynamic>? plan;

  const PremiumBanner({super.key, this.plan});

  @override
  Widget build(BuildContext context) {
    final data = plan ??
        {
          'name': 'Glaya Premium',
          'description': 'More Glow. More Benefits.',
          'features': const [
            'Up to 20% off on all services',
            'Priority booking with top pros',
            'Exclusive offers & early access',
            'Free reschedule (1x per month)',
          ],
          'badgeColor': '#8A1C4E',
        };

    final name = data['name'] as String? ?? 'Glaya Premium';
    final description = data['description'] as String? ?? 'More Glow. More Benefits.';
    final features = (data['features'] as List<dynamic>?)?.cast<String>() ??
        const ['Up to 20% off on all services', 'Priority booking with top pros'];
    final badgeColor = colorFromHex(data['badgeColor'] as String? ?? '#8A1C4E');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              GlayaColors.background,
              GlayaColors.vibrantPink.withValues(alpha: 0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: GlayaColors.vibrantPink),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.workspace_premium, color: badgeColor, size: 20),
                const SizedBox(width: 6),
                Text(
                  name,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: badgeColor),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: GlayaColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            ...features.take(4).map(
                  (feature) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: GlayaColors.berry, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            feature,
                            style: const TextStyle(fontSize: 12, color: GlayaColors.textGray),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => context.push('/premium'),
              style: ElevatedButton.styleFrom(
                backgroundColor: GlayaColors.berry,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 38),
              ),
              child: const Text('Upgrade Now', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
