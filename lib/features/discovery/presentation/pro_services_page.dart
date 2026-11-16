import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../shared/theme/colors.dart';
import '../../../../shared/providers/location_provider.dart';
import '../../auth/presentation/providers/auth_notifier.dart';
import 'discovery_provider.dart';
import '../data/professional_model.dart';

const _currencySymbols = <String, String>{
  'USD': '\$', 'EUR': '€', 'GBP': '£', 'XAF': 'FCFA', 'XOF': 'CFA',
  'NGN': '₦', 'GHS': '₵', 'KES': 'KSh', 'ZAR': 'R', 'EGP': 'E£',
  'MAD': 'DH', 'ETB': 'Br', 'TZS': 'TSh', 'UGX': 'USh', 'CDF': 'FC',
  'AED': 'د.إ', 'SAR': '﷼', 'INR': '₹', 'CNY': '¥', 'JPY': '¥',
  'CAD': 'C\$',
};

String _currencySymbol(String code) => _currencySymbols[code] ?? code;

/// All services offered by one professional — 2-column grid of 1:2
/// full-image cards. Tapping a card starts the booking flow with that
/// service (and its price) pre-selected.
class ProServicesPage extends ConsumerWidget {
  final String professionalId;

  const ProServicesPage({super.key, required this.professionalId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(salonProfileProvider(professionalId));

    return Scaffold(
      backgroundColor: GlayaColors.pinkBg,
      appBar: AppBar(
        backgroundColor: GlayaColors.surface,
        foregroundColor: GlayaColors.textPrimary,
        elevation: 0,
        title: const Text('Services',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: profileAsync.when(
        data: (pro) {
          final services = (pro.services ?? []).cast<ServiceItem>();
          if (services.isEmpty) {
            return const Center(
              child: Text('No services listed yet',
                  style: TextStyle(color: GlayaColors.textSecondary)),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.5, // 1:2 portrait
            ),
            itemCount: services.length,
            itemBuilder: (_, i) =>
                _ServiceImageCard(service: services[i], professionalId: pro.id),
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator(color: GlayaColors.berry)),
        error: (_, __) => const Center(
          child: Text('Could not load services',
              style: TextStyle(color: GlayaColors.textSecondary)),
        ),
      ),
    );
  }
}

class _ServiceImageCard extends ConsumerWidget {
  final ServiceItem service;
  final String professionalId;

  const _ServiceImageCard(
      {required this.service, required this.professionalId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(userCurrencyProvider);
    final symbol = _currencySymbol(currency ?? 'XAF');
    final converted = ref.watch(convertedPriceProvider(
        (amount: service.price.toDouble(), fromCurrency: 'XAF')));
    final price =
        NumberFormat('#,##0').format(converted.value ?? service.price);
    final isAuthenticated =
        ref.watch(authNotifierProvider).valueOrNull != null;

    return GestureDetector(
      onTap: () {
        if (!isAuthenticated) {
          context.push(
              '/login?from=${Uri.encodeComponent('/book/$professionalId?serviceId=${service.id}')}');
        } else {
          context.push('/book/$professionalId', extra: service.id);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: GlayaColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: GlayaColors.pinkBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Full-bleed service image
              service.imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: service.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: GlayaColors.pinkLight,
                        child: const Icon(Icons.spa,
                            color: GlayaColors.berry, size: 36),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: GlayaColors.pinkLight,
                        child: const Icon(Icons.spa,
                            color: GlayaColors.berry, size: 36),
                      ),
                    )
                  : Container(
                      color: GlayaColors.pinkLight,
                      child: const Icon(Icons.spa,
                          color: GlayaColors.berry, size: 36),
                    ),
              // Bottom scrim
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 120,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0),
                        Colors.black.withValues(alpha: 0.75),
                      ],
                    ),
                  ),
                ),
              ),
              // Details overlaid at bottom
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      service.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${service.durationMins} min',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$symbol $price',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: GlayaColors.berry,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('Book',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
