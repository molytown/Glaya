import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/services/config_service.dart';
import '../../../discovery/presentation/discovery_provider.dart';

class ExclusiveOffersSection extends ConsumerWidget {
  const ExclusiveOffersSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offersAsync = ref.watch(exclusiveOffersProvider);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF000000).withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Exclusive Offers',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              GestureDetector(
                onTap: () => context.push('/offers'),
                child: const Row(
                  children: [
                    Text(
                      'View all',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: GlayaColors.berry,
                      ),
                    ),
                    SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right,
                      size: 13,
                      color: GlayaColors.berry,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          offersAsync.when(
            data: (offers) {
              if (offers.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'No offers available',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                );
              }
              final offerList =
                  offers.map((offer) => Offer.fromJson(offer)).toList();
              return Column(
                children:
                    offerList.map((offer) => _OfferCard(offer: offer)).toList(),
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (_, __) => Column(
              children: _getFallbackOffers()
                  .map((offer) => _OfferCard(offer: offer))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  List<Offer> _getFallbackOffers() {
    return const [
      Offer(
        discountLabel: '20% OFF',
        title: 'All Hair Services',
        validUntil: 'May 31, 2025',
        code: 'GLAYA20',
        bgColor: Color(0xFF2D1B4E),
        imageUrl: null,
      ),
      Offer(
        discountLabel: '15% OFF',
        title: 'Nail Art & Design',
        validUntil: 'May 31, 2025',
        code: 'NAIL15',
        bgColor: Color(0xFF1A0A2E),
        imageUrl: null,
      ),
    ];
  }
}

class _OfferCard extends StatelessWidget {
  final Offer offer;

  const _OfferCard({required this.offer});

  @override
  Widget build(BuildContext context) {
    final configService = ConfigService();
    final imageUrl = offer.imageUrl?.isNotEmpty == true
        ? configService.replaceLocalhost(offer.imageUrl!)
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      height: 110,
      decoration: BoxDecoration(
        color: offer.bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          // Low-opacity image overlay (matches React design)
          if (imageUrl != null)
            Positioned.fill(
              child: Opacity(
                opacity: 0.15,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          Positioned(
            left: 14,
            top: 0,
            bottom: 0,
            child: SizedBox(
              width: 150,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offer.discountLabel,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: GlayaColors.berry,
                      height: 0.9,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    offer.title,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Valid till ${offer.validUntil}',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.white.withValues(alpha: 0.65),
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 1,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: RichText(
                      text: TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Use Code ',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFFE6E6E6),
                            ),
                          ),
                          TextSpan(
                            text: offer.code,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Image on the right side (matches React design)
          if (imageUrl != null)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 100,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            )
          else
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 100,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      offer.bgColor,
                      offer.bgColor.withValues(alpha: 0.7),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.local_offer,
                  size: 48,
                  color: Color.fromRGBO(255, 255, 255, 0.2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class Offer {
  final String discountLabel;
  final String title;
  final String validUntil;
  final String code;
  final Color bgColor;
  final String? imageUrl;

  const Offer({
    required this.discountLabel,
    required this.title,
    required this.validUntil,
    required this.code,
    required this.bgColor,
    this.imageUrl,
  });

  factory Offer.fromJson(Map<String, dynamic> json) {
    return Offer(
      discountLabel: json['discountLabel']?.toString() ??
          json['discount_label']?.toString() ??
          '',
      title: json['title']?.toString() ?? '',
      validUntil: (json['validUntil'] ?? json['valid_until'])?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      bgColor: json['bgColor'] != null
          ? Color(
              int.parse(json['bgColor'].toString().replaceFirst('#', '0xFF')))
          : json['bg_color'] != null
              ? Color(int.parse(
                  json['bg_color'].toString().replaceFirst('#', '0xFF')))
              : const Color(0xFF2D1B4E),
      imageUrl: json['imageUrl'] as String? ?? json['image_url'] as String?,
    );
  }
}
