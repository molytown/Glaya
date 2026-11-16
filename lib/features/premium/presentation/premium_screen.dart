import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../discovery/presentation/discovery_provider.dart';
import '../../../../shared/theme/colors.dart';

class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  bool _yearly = false;

  Color _colorFromHex(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  String _formatPrice(num? price) {
    if (price == null) return '₦0';
    return '₦${price.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',')}';
  }

  @override
  Widget build(BuildContext context) {
    final premiumAsync = ref.watch(premiumPlansProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: GlayaColors.berry,
        foregroundColor: Colors.white,
        title: const Text('Glaya Premium'),
        elevation: 0,
      ),
      body: premiumAsync.when(
        data: (plans) {
          final displayPlans = plans.isEmpty
              ? [
                  {
                    'name': 'Glaya Premium',
                    'description': 'More Glow. More Benefits.',
                    'priceMonthly': 5000,
                    'priceYearly': 48000,
                    'discountPercent': 20,
                    'features': const [
                      'Up to 20% off on all services',
                      'Priority booking with top pros',
                      'Exclusive offers & early access',
                      'Free reschedule (1x per month)',
                    ],
                    'badgeColor': '#E91E8C',
                  }
                ]
              : plans;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose your plan',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Unlock exclusive benefits and save on every booking.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _billingChip('Monthly', !_yearly, () => setState(() => _yearly = false)),
                        _billingChip('Yearly', _yearly, () => setState(() => _yearly = true)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ...displayPlans.map((plan) => _buildPlanCard(plan)),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Failed to load premium plans')),
      ),
    );
  }

  Widget _billingChip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: active ? GlayaColors.berry : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    final name = plan['name'] as String? ?? 'Glaya Premium';
    final description = plan['description'] as String? ?? '';
    final price = _yearly
        ? (plan['priceYearly'] as num? ?? 0)
        : (plan['priceMonthly'] as num? ?? 0);
    final cycle = _yearly ? 'year' : 'month';
    final features = (plan['features'] as List<dynamic>?)?.cast<String>() ?? const [];
    final badgeColor = _colorFromHex(plan['badgeColor'] as String? ?? '#E91E8C');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GlayaColors.pinkBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GlayaColors.pinkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium, color: badgeColor, size: 24),
              const SizedBox(width: 8),
              Text(
                name,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: badgeColor),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(description, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          ],
          const SizedBox(height: 12),
          Text(
            '${_formatPrice(price)}/$cycle',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...features.map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle, color: GlayaColors.berry, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(f, style: const TextStyle(fontSize: 14))),
              ],
            ),
          )),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: badgeColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Subscribe Now', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
