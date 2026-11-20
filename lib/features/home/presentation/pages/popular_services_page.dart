import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../shared/theme/colors.dart';
import '../../../../shared/utils/haptic_feedback.dart';
import '../../../discovery/presentation/discovery_provider.dart';

/// All services ranked by booking popularity (backend sortBy=popular:
/// bookings x10 + likes x3 + rating x2). Tapping a card opens the
/// professional's profile who offers the service.
class PopularServicesPage extends ConsumerWidget {
  const PopularServicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(allPopularServicesProvider);

    return Scaffold(
      backgroundColor: GlayaColors.pinkBg,
      appBar: AppBar(
        backgroundColor: GlayaColors.surface,
        foregroundColor: GlayaColors.textPrimary,
        elevation: 0,
        title: const Text('Popular Services',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: servicesAsync.when(
        data: (services) {
          if (services.isEmpty) {
            return const Center(
              child: Text('No services found',
                  style: TextStyle(color: GlayaColors.textSecondary)),
            );
          }
          return RefreshIndicator(
            color: GlayaColors.berry,
            onRefresh: () async => ref.invalidate(allPopularServicesProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: services.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _ServiceTile(
                service: services[i],
                rank: i + 1,
              ),
            ),
          );
        },
        loading: () => const Center(
            child: CircularProgressIndicator(color: GlayaColors.berry)),
        error: (_, __) => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Could not load services. Pull down to retry.',
              textAlign: TextAlign.center,
              style: TextStyle(color: GlayaColors.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  final Map<String, dynamic> service;
  final int rank;

  const _ServiceTile({required this.service, required this.rank});

  @override
  Widget build(BuildContext context) {
    final name = (service['name'] ?? service['title'] ?? 'Service').toString();
    final pro = service['professional'] as Map<String, dynamic>?;
    final proId = pro?['id']?.toString();
    final proName =
        (pro?['user'] as Map<String, dynamic>?)?['name']?.toString() ??
            pro?['businessName']?.toString() ??
            'Professional';
    final proPhoto =
        (pro?['user'] as Map<String, dynamic>?)?['photoUrl']?.toString();
    final imageUrl = service['imageUrl'] as String?;
    final price = service['price'] ?? service['priceFrom'];
    final currency = service['currency']?.toString() ?? 'XAF';
    final rating = service['rating'] ?? service['avgRating'];
    final bookings = service['bookingCount'];

    return GestureDetector(
      onTap: () {
        HapticFeedback.light();
        if (proId != null && proId.isNotEmpty) {
          context.push('/professional/$proId');
        } else {
          context.push('/search?q=${Uri.encodeComponent(name)}');
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: GlayaColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: GlayaColors.pinkBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Rank badge
            Container(
              width: 26,
              alignment: Alignment.center,
              child: Text(
                '#$rank',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: GlayaColors.berry,
                ),
              ),
            ),
            // Service image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        width: 64,
                        height: 64,
                        color: GlayaColors.pinkLight,
                        child: const Icon(Icons.spa,
                            color: GlayaColors.berry, size: 24),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        width: 64,
                        height: 64,
                        color: GlayaColors.pinkLight,
                        child: const Icon(Icons.spa,
                            color: GlayaColors.berry, size: 24),
                      ),
                    )
                  : Container(
                      width: 64,
                      height: 64,
                      color: GlayaColors.pinkLight,
                      child: const Icon(Icons.spa,
                          color: GlayaColors.berry, size: 24),
                    ),
            ),
            const SizedBox(width: 12),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: GlayaColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 9,
                        backgroundColor: GlayaColors.pinkLight,
                        backgroundImage:
                            proPhoto != null ? NetworkImage(proPhoto) : null,
                        child: proPhoto == null
                            ? const Icon(Icons.person,
                                size: 12, color: GlayaColors.berry)
                            : null,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          proName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: GlayaColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (rating != null) ...[
                        const Icon(Icons.star,
                            size: 13, color: GlayaColors.warning),
                        const SizedBox(width: 3),
                        Text(
                          num.tryParse(rating.toString())?.toStringAsFixed(1) ??
                              rating.toString(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: GlayaColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (bookings != null)
                        Text(
                          '${NumberFormat('#,##0').format(num.tryParse(bookings.toString()) ?? 0)} bookings',
                          style: const TextStyle(
                            fontSize: 11,
                            color: GlayaColors.textTertiary,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Price
            if (price != null)
              Text(
                '$currency ${NumberFormat('#,##0').format(num.tryParse(price.toString()) ?? 0)}+',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: GlayaColors.berry,
                ),
              ),
            const Icon(Icons.chevron_right,
                size: 20, color: GlayaColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
