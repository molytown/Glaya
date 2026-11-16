import 'package:cached_network_image/cached_network_image.dart';
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
  'XAF': 'FCFA',
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

class ServicesSection extends StatelessWidget {
  final ProfessionalModel professional;

  const ServicesSection({super.key, required this.professional});

  @override
  Widget build(BuildContext context) {
    final services = (professional.services ?? []).cast<ServiceItem>();
    final shown = services.take(4).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Services',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: GlayaColors.textPrimary)),
              ),
              if (services.length > 4)
                TextButton(
                  onPressed: () =>
                      context.push('/professional/${professional.id}/services'),
                  child: const Text('See All',
                      style: TextStyle(
                          color: GlayaColors.berry,
                          fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (shown.isEmpty)
            const Text('No services yet',
                style: TextStyle(
                    fontSize: 14, color: GlayaColors.textSecondary))
          else
            SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: shown.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) => ServiceCard(
                  service: shown[i],
                  professionalId: professional.id,
                ),
              ),
            ),
          const SizedBox(height: 8),
          Consumer(
            builder: (context, ref, _) {
              final authState = ref.watch(authNotifierProvider);
              final user = authState.valueOrNull;
              final isOwnProfile =
                  user?.professionalId == professional.id;

              if (!isOwnProfile) return const SizedBox.shrink();

              return SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/service-management'),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Add Service'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlayaColors.berry,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 2:1 landscape card: service image on the left, details + Book button on the right.
class ServiceCard extends ConsumerWidget {
  final ServiceItem service;
  final String professionalId;

  const ServiceCard(
      {super.key, required this.service, required this.professionalId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(userCurrencyProvider);
    final currencySymbol = _getCurrencySymbol(currency ?? 'XAF');
    final converted = ref.watch(convertedPriceProvider(
        (amount: service.price.toDouble(), fromCurrency: 'XAF')));
    final displayPrice =
        NumberFormat('#,##0').format(converted.value ?? service.price);
    final depositConverted = service.depositAmount != null &&
            service.depositAmount! > 0
        ? ref.watch(convertedPriceProvider((
            amount: service.depositAmount!.toDouble(),
            fromCurrency: 'XAF')))
        : null;
    final depositDisplay = depositConverted != null
        ? NumberFormat('#,##0')
            .format(depositConverted.value ?? service.depositAmount)
        : null;
    final authState = ref.watch(authNotifierProvider);
    final isAuthenticated = authState.valueOrNull != null;

    return Container(
      width: 300,
      height: 150,
      decoration: BoxDecoration(
        color: GlayaColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: GlayaColors.pinkBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Row(
          children: [
            // Service image
            SizedBox(
              width: 110,
              height: 150,
              child: service.imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: service.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: GlayaColors.pinkLight,
                        child: const Icon(Icons.spa,
                            color: GlayaColors.berry, size: 32),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: GlayaColors.pinkLight,
                        child: const Icon(Icons.spa,
                            color: GlayaColors.berry, size: 32),
                      ),
                    )
                  : Container(
                      color: GlayaColors.pinkLight,
                      child: const Icon(Icons.spa,
                          color: GlayaColors.berry, size: 32),
                    ),
            ),
            // Details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.name,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: GlayaColors.textPrimary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text('${service.durationMins} min',
                        style: const TextStyle(
                            fontSize: 11, color: GlayaColors.textSecondary)),
                    const SizedBox(height: 2),
                    Text('$currencySymbol $displayPrice',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: GlayaColors.berry)),
                    if (depositDisplay != null) ...[
                      const SizedBox(height: 2),
                      Text('Deposit: $currencySymbol $depositDisplay',
                          style: const TextStyle(
                              fontSize: 10, color: GlayaColors.textTertiary)),
                    ],
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (!isAuthenticated) {
                            context.push(
                                '/login?from=${Uri.encodeComponent('/book/$professionalId?serviceId=${service.id}')}');
                          } else {
                            context.push('/book/$professionalId',
                                extra: service.id);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GlayaColors.berry,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          minimumSize: const Size(0, 30),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6)),
                        ),
                        child: const Text('BOOK',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
