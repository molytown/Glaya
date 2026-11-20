import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/providers/location_provider.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../data/professional_model.dart';

// Currency code to symbol mapping
const _currencySymbols = <String, String>{
  'USD': '\$',
  'EUR': '€',
  'GBP': '£',
  'XAF': 'XAF',
  'XOF': 'CFA',
  'NGN': '₦',
  'GHS': '₵',
  'KES': 'KSh',
  'ZAR': 'R',
  'EGP': 'E£',
  'MAD': 'DH',
  'ETB': 'Br',
  'TZS': 'TSh',
  'UGX': 'USh',
  'CDF': 'FC',
  'AED': 'د.إ',
  'SAR': '﷼',
  'INR': '₹',
  'CNY': '¥',
  'JPY': '¥',
  'CAD': 'C\$',
};

String _getCurrencySymbol(String currencyCode) {
  return _currencySymbols[currencyCode] ?? currencyCode;
}

class BottomStickyBookingBar extends ConsumerWidget {
  final ProfessionalModel professional;

  const BottomStickyBookingBar({super.key, required this.professional});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = professional.services ?? [];
    final minPrice = services.isEmpty
        ? 0.0
        : services
            .map((s) => (s as ServiceItem).price)
            .reduce((a, b) => a < b ? a : b);

    final currencyCode = professional.currency ?? 'XAF';
    final currencySymbol = _getCurrencySymbol(currencyCode);
    final converted = ref.watch(
        convertedPriceProvider((amount: minPrice, fromCurrency: currencyCode)));
    final displayPrice =
        NumberFormat('#,##0').format(converted.value ?? minPrice);
    final authState = ref.watch(authNotifierProvider);
    final isAuthenticated = authState.valueOrNull != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Color(0xFF000000).withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, -2))
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Starting from',
                    style: TextStyle(fontSize: 11, color: Color(0xFF000000))),
                Text('$currencySymbol $displayPrice',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A1A))),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: 180,
              child: ElevatedButton(
                onPressed: () {
                  if (!isAuthenticated) {
                    context.push(
                        '/login?from=${Uri.encodeComponent('/book/${professional.id}')}');
                  } else {
                    context.push('/book/${professional.id}');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlayaColors.berry,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Book Appointment',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
