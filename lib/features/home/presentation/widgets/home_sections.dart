import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../shared/providers/location_provider.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../shared/services/config_service.dart';
import '../../../../shared/services/currency_service.dart';
import '../../../../shared/theme/colors.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../../discovery/data/professional_model.dart';
import '../../../discovery/data/trending_service_model.dart';
import 'home_utils.dart';

String _getCurrencySymbol() {
  const symbols = <String, String>{
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
  return symbols['XAF'] ?? 'XAF';
}

// Helper to get currency symbol from code
String _getSymbolFromCode(String? currencyCode) {
  if (currencyCode == null) return _getCurrencySymbol();
  const symbols = <String, String>{
    'USD': '\$',
    'EUR': '€',
    'GBP': '£',
    'XAF': 'FCFA ',
    'XOF': 'CFA ',
    'NGN': '₦',
    'GHS': 'GH₵ ',
    'KES': 'KSh ',
    'ZAR': 'R ',
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
  return symbols[currencyCode.toUpperCase()] ?? '$currencyCode ';
}

class PopularServicesRow extends ConsumerWidget {
  final List<Map<String, dynamic>> items;

  const PopularServicesRow({super.key, required this.items});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    num parseNum(dynamic value) {
      if (value is num) return value;
      if (value is String) return num.parse(value);
      return 0;
    }

    // Get user's preferred currency
    final user = ref.watch(authNotifierProvider).valueOrNull;
    final userCurrency = user?.preferredCurrency ?? 'XAF';

    final mapped = items.map((item) {
      final name = (item['name'] ?? item['title'] ?? 'Service').toString();
      final priceValue = item['price'] ?? item['priceFrom'];
      final itemCurrency = item['currency']?.toString() ?? 'XAF';

      // Convert price to user's currency if different
      String price;
      if (priceValue != null) {
        if (itemCurrency != userCurrency) {
          // TODO: Implement currency conversion
          // For now, just display in the service's currency
          price =
              '${_getSymbolFromCode(itemCurrency)}${parseNum(priceValue).toStringAsFixed(0)}+';
        } else {
          price =
              '${_getSymbolFromCode(itemCurrency)}${parseNum(priceValue).toStringAsFixed(0)}+';
        }
      } else {
        price = '';
      }

      final rawRating = item['rating'] ?? item['avgRating'];
      final rating =
          (rawRating != null ? parseNum(rawRating) : 4.8).toStringAsFixed(1);
      final imageUrl = item['imageUrl'] as String?;
      final pro = item['professional'] as Map<String, dynamic>?;
      final professionalId = pro?['id']?.toString();
      final proName =
          (pro?['user'] as Map<String, dynamic>?)?['name']?.toString() ??
              pro?['businessName']?.toString();
      return {
        'name': name,
        'price': price,
        'rating': rating,
        'imageUrl': imageUrl,
        'professionalId': professionalId,
        'proName': proName,
      };
    }).toList();

    final services = mapped.isNotEmpty
        ? mapped
        : [
            {
              'name': 'Hair Cut & Style',
              'price': '${_getSymbolFromCode(userCurrency)}45+',
              'rating': '4.8'
            },
            {
              'name': 'Full Makeup',
              'price': '${_getSymbolFromCode(userCurrency)}60+',
              'rating': '4.9'
            },
            {
              'name': 'Gel Manicure',
              'price': '${_getSymbolFromCode(userCurrency)}35+',
              'rating': '4.8'
            },
            {
              'name': 'Facial Treatment',
              'price': '${_getSymbolFromCode(userCurrency)}50+',
              'rating': '4.7'
            },
          ];

    return SizedBox(
      height: 250,
      child: ListView.builder(
        padding: const EdgeInsets.only(left: 16),
        scrollDirection: Axis.horizontal,
        itemCount: services.length,
        itemBuilder: (context, index) {
          final service = services[index];
          final proId = service['professionalId'];
          final name = service['name'] ?? '';
          return GestureDetector(
            onTap: () {
              if (proId != null && proId.isNotEmpty) {
                context.push('/professional/$proId');
              } else if (name.isNotEmpty) {
                context.push('/search?q=${Uri.encodeComponent(name)}');
              }
            },
            child: Container(
              width: 120,
              height: 240,
              margin: const EdgeInsets.only(right: 12),
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
                    (service['imageUrl']?.toString() ?? '').isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: service['imageUrl'].toString(),
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: GlayaColors.vibrantPink
                                  .withValues(alpha: 0.15),
                              child: const Icon(Icons.spa,
                                  size: 36, color: GlayaColors.berry),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: GlayaColors.vibrantPink
                                  .withValues(alpha: 0.15),
                              child: const Icon(Icons.spa,
                                  size: 36, color: GlayaColors.berry),
                            ),
                          )
                        : Container(
                            color:
                                GlayaColors.vibrantPink.withValues(alpha: 0.15),
                            child: const Icon(Icons.spa,
                                size: 36, color: GlayaColors.berry),
                          ),
                    // Bottom scrim for readability
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 110,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0),
                              Colors.black.withValues(alpha: 0.72),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Details overlaid at the bottom of the card
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 10,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if ((service['proName'])?.isNotEmpty == true) ...[
                            const SizedBox(height: 2),
                            Text(
                              service['proName'] as String,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                service['price'] ?? '',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              const Spacer(),
                              const Icon(Icons.star,
                                  size: 11, color: GlayaColors.warning),
                              const SizedBox(width: 2),
                              Text(
                                service['rating']?.toString() ?? '4.8',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.white),
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
        },
      ),
    );
  }
}

class BecomeProfessionalBanner extends ConsumerWidget {
  const BecomeProfessionalBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider).valueOrNull;
    final isProfessional = user?.role == 'professional' || user?.role == 'both';

    // Don't show for professional or both accounts
    if (isProfessional) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF5C3D2E),
              Color(0xFF8B6914),
              Color(0xFFA67C52),
              Color(0xFFD4A76A),
              Color(0xFFF5DEB3),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Become a Professional',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                            color: Color(0x40000000),
                            blurRadius: 4,
                            offset: Offset(0, 1))
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Join Glaya and grow your beauty business.',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12,
                        height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () => context.push('/signup/professional'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 9),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20)),
                      child: const Text(
                        'Join Now',
                        style: TextStyle(
                            color: Color(0xFF5C3D2E),
                            fontSize: 13,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.person_add_alt_1, color: Colors.white, size: 60),
          ],
        ),
      ),
    );
  }
}

class HowItWorksRow extends StatelessWidget {
  final List<Map<String, dynamic>> steps;

  const HowItWorksRow({super.key, required this.steps});

  @override
  Widget build(BuildContext context) {
    final defaults = [
      {'title': 'Choose Service', 'icon': 'search'},
      {'title': 'Select Pro', 'icon': 'person'},
      {'title': 'Book & Pay', 'icon': 'payment'},
      {'title': 'Get Glammed', 'icon': 'star'},
    ];
    final items = steps.isNotEmpty ? steps : defaults;
    const icons = {
      'search': Icons.search,
      'person': Icons.person,
      'payment': Icons.payment,
      'star': Icons.star,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: items.take(4).map((step) {
          final iconKey = step['icon'] as String? ?? 'star';
          return Expanded(
            child: Column(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: GlayaColors.vibrantPink.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icons[iconKey] ?? Icons.circle,
                      color: GlayaColors.berry, size: 22),
                ),
                const SizedBox(height: 6),
                Text(
                  step['title'] as String? ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: GlayaColors.textPrimary),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class ReferLoyaltyRow extends ConsumerWidget {
  const ReferLoyaltyRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _MiniPromoCard(
              icon: Icons.card_giftcard,
              title: 'Refer & Earn',
              subtitle: "You're the friend who knows everyone!",
              ctaText: 'Earn Now',
              onTap: () async {
                try {
                  final response =
                      await ApiService.dio.get('/loyalty/referral-code');
                  final code = response.data['data']['code'] as String;
                  await Clipboard.setData(ClipboardData(text: code));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Code $code copied!')),
                    );
                  }
                } catch (_) {}
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _MiniPromoCard(
              icon: Icons.emoji_events,
              title: 'Loyalty Rewards',
              subtitle: 'Book more, earn exciting rewards.',
              ctaText: 'View Rewards',
              onTap: () => context.push('/loyalty'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniPromoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String ctaText;
  final VoidCallback onTap;

  const _MiniPromoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.ctaText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GlayaColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: GlayaColors.vibrantPink),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: GlayaColors.berry, size: 28),
          const SizedBox(height: 8),
          Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: GlayaColors.textPrimary)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 11, color: GlayaColors.textGray, height: 1.4),
              maxLines: 2),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onTap,
            child: Text(ctaText,
                style: const TextStyle(
                    color: GlayaColors.berry,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class NearbyProfessionalsList extends StatelessWidget {
  final List<ProfessionalModel> professionals;

  const NearbyProfessionalsList({super.key, required this.professionals});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: professionals.take(3).map((pro) {
          final rating = professionalRating(pro.trustScore);
          final reviews = pro.reviews?.length ?? 0;
          return GestureDetector(
            onTap: () => context.push('/professional/${pro.id}'),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: GlayaColors.surface,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 70,
                    height: 50,
                    child: Stack(
                      children: [
                        Positioned(left: 0, child: _avatar(pro.photoUrl, 40)),
                        Positioned(left: 20, child: _avatar(null, 36)),
                        Positioned(left: 38, child: _avatar(null, 32)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(pro.name,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: GlayaColors.textPrimary)),
                        Text(pro.category,
                            style: const TextStyle(
                                fontSize: 12, color: GlayaColors.textGray)),
                        Row(
                          children: [
                            const Icon(Icons.star,
                                size: 12, color: GlayaColors.warning),
                            Text(' ${rating.toStringAsFixed(1)} ($reviews)',
                                style: const TextStyle(
                                    fontSize: 11, color: GlayaColors.textGray)),
                          ],
                        ),
                        if (pro.distance != null)
                          Text('${pro.distance!.toStringAsFixed(1)} km away',
                              style: const TextStyle(
                                  fontSize: 11, color: GlayaColors.textGray))
                        else
                          const Text('Distance unknown',
                              style: TextStyle(
                                  fontSize: 11, color: GlayaColors.textGray)),
                      ],
                    ),
                  ),
                  const Icon(Icons.favorite_border,
                      color: GlayaColors.textGray, size: 20),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _avatar(String? photoUrl, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: GlayaColors.surface, width: 2),
          color: GlayaColors.vibrantPink.withValues(alpha: 0.25),
        ),
        child: photoUrl?.isNotEmpty == true
            ? ClipOval(
                child: CachedNetworkImage(
                    imageUrl: ConfigService().replaceLocalhost(photoUrl!),
                    fit: BoxFit.cover))
            : const Icon(Icons.person, size: 14, color: GlayaColors.berry),
      );
}

class BnplBanner extends StatelessWidget {
  const BnplBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: GlayaColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: GlayaColors.vibrantPink),
        ),
        padding: const EdgeInsets.all(18),
        child: const Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Book Now, Pay Later',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: GlayaColors.textPrimary)),
                  SizedBox(height: 4),
                  Text('Split your payment into 4 stress-free installments.',
                      style: TextStyle(
                          fontSize: 12,
                          color: GlayaColors.textGray,
                          height: 1.4)),
                ],
              ),
            ),
            SizedBox(width: 12),
            Icon(Icons.calendar_today, size: 60, color: GlayaColors.berry),
          ],
        ),
      ),
    );
  }
}

class CustomerReviewsRow extends StatelessWidget {
  final List<Map<String, dynamic>> reviews;

  const CustomerReviewsRow({super.key, required this.reviews});

  @override
  Widget build(BuildContext context) {
    final items = reviews.isEmpty
        ? [
            {
              'reviewerName': 'Emily R.',
              'rating': 5,
              'comment': 'Amazing experience! Will definitely come back again.'
            },
            {
              'reviewerName': 'Jessica M.',
              'rating': 5,
              'comment': 'Maya is the best! My makeup looked stunning.'
            },
            {
              'reviewerName': 'Sophia L.',
              'rating': 4,
              'comment': 'The nails were amazing — highly recommended!'
            },
          ]
        : reviews;

    return SizedBox(
      height: 150,
      child: ListView.builder(
        padding: const EdgeInsets.only(left: 16),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        itemBuilder: (_, index) {
          final review = items[index];
          final name =
              (review['reviewerName'] ?? review['reviewer']?['name'] ?? 'User')
                  .toString();
          final rating = (review['rating'] as num?)?.toInt() ?? 5;
          final comment = review['comment']?.toString() ?? '';
          return Container(
            width: 180,
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: GlayaColors.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor:
                          GlayaColors.vibrantPink.withValues(alpha: 0.2),
                      child: Text(
                        name[0].toUpperCase(),
                        style: const TextStyle(
                            color: GlayaColors.berry,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: GlayaColors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: List.generate(
                    5,
                    (star) => Icon(
                      star < rating ? Icons.star : Icons.star_border,
                      size: 13,
                      color: GlayaColors.warning,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  comment,
                  style: const TextStyle(
                      fontSize: 11, color: GlayaColors.textGray, height: 1.4),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class TrendingNowRow extends StatelessWidget {
  final List<TrendingServiceModel> items;

  const TrendingNowRow({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 160,
      child: ListView.builder(
        padding: const EdgeInsets.only(left: 16),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        itemBuilder: (_, index) {
          final item = items[index];
          final priceFrom =
              '${_getCurrencySymbol()}${item.priceFrom.toStringAsFixed(0)}+';
          final imageUrl = item.imageUrl?.isNotEmpty == true
              ? ConfigService().replaceLocalhost(item.imageUrl!)
              : null;
          return GestureDetector(
            onTap: () {
              if (item.serviceId != null && item.serviceId!.isNotEmpty) {
                context.push('/service-portfolio/${item.serviceId}');
              } else if (item.category != null && item.category!.isNotEmpty) {
                context.push(
                    '/category/${Uri.encodeComponent(item.category!.toLowerCase())}?name=${Uri.encodeComponent(item.category!)}');
              }
            },
            child: Container(
              width: 120,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: GlayaColors.vibrantPink.withValues(alpha: 0.25),
              ),
              child: Stack(
                children: [
                  if (imageUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        height: 160,
                        width: 120,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          height: 160,
                          width: 120,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color:
                                GlayaColors.vibrantPink.withValues(alpha: 0.25),
                          ),
                          child: const Icon(Icons.spa,
                              size: 40, color: GlayaColors.berry),
                        ),
                      ),
                    )
                  else
                    Container(
                      height: 160,
                      width: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: GlayaColors.vibrantPink.withValues(alpha: 0.25),
                      ),
                      child: const Icon(Icons.spa,
                          size: 40, color: GlayaColors.berry),
                    ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(14)),
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withValues(alpha: 0.6),
                            Colors.transparent
                          ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                          if (priceFrom.isNotEmpty)
                            Text(priceFrom,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class NeverMissDealBanner extends StatelessWidget {
  const NeverMissDealBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [GlayaColors.berry, GlayaColors.accentPink],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Never Miss a Deal!',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Enable notifications to get alerts on exclusive offers and discounts.',
                    style: TextStyle(
                        color: Colors.white, fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () async {
                      try {
                        await ApiService.dio
                            .post('/engagement/notification-opt-in');
                      } catch (_) {}
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Notifications enabled!')),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 9),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20)),
                      child: const Text(
                        'Enable Notifications',
                        style: TextStyle(
                            color: GlayaColors.berry,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.notifications_active,
                color: Colors.white, size: 56),
          ],
        ),
      ),
    );
  }
}

class WhyChooseGlayaGrid extends StatelessWidget {
  final List<Map<String, dynamic>> items;

  const WhyChooseGlayaGrid({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    const defaults = [
      {
        'icon': Icons.verified_user,
        'title': 'Verified Pros',
        'subtitle': 'Only verified & trusted professionals'
      },
      {
        'icon': Icons.lock,
        'title': 'Secure Booking',
        'subtitle': 'Safe payments & secure transactions'
      },
      {
        'icon': Icons.thumb_up,
        'title': 'Satisfaction Guaranteed',
        'subtitle': 'Your satisfaction is our priority'
      },
      {
        'icon': Icons.support_agent,
        'title': '24/7 Support',
        'subtitle': "We're here to help you anytime"
      },
    ];

    const iconMap = {
      'verified_user': Icons.verified_user,
      'lock': Icons.lock,
      'thumb_up': Icons.thumb_up,
      'support_agent': Icons.support_agent,
    };

    final resolved = items.isNotEmpty
        ? items.map((item) {
            final key = item['icon'] as String? ?? 'star';
            return {
              'icon': iconMap[key] ?? Icons.star,
              'title': item['title'] ?? '',
              'subtitle': item['subtitle'] ?? '',
            };
          }).toList()
        : defaults;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Why Choose Glaya?',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: GlayaColors.textPrimary),
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.4,
            children: resolved.map((entry) {
              final icon = entry['icon'] as IconData;
              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: GlayaColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: GlayaColors.vibrantPink),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: GlayaColors.vibrantPink.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: GlayaColors.berry, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            entry['title']?.toString() ?? '',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: GlayaColors.textPrimary),
                          ),
                          Text(
                            entry['subtitle']?.toString() ?? '',
                            style: const TextStyle(
                                fontSize: 9, color: GlayaColors.textGray),
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class UpcomingAppointmentCard extends StatelessWidget {
  final Map<String, dynamic> booking;

  const UpcomingAppointmentCard({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    final scheduledAt = DateTime.tryParse(
      (booking['scheduledAt'] ?? booking['scheduled_at'] ?? '').toString(),
    );
    final serviceName =
        (booking['service'] as Map<String, dynamic>?)?['name'] ?? 'Appointment';
    final proName = ((booking['professional'] as Map<String, dynamic>?)?['user']
            as Map<String, dynamic>?)?['name'] ??
        'Professional';
    final formatted = scheduledAt != null
        ? DateFormat('EEE, MMM d • h:mm a').format(scheduledAt.toLocal())
        : '';
    final bookingId = booking['id'] as String?;

    return GestureDetector(
      onTap: () {
        if (bookingId != null) context.push('/bookings/$bookingId');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [GlayaColors.berry, GlayaColors.accentPink],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Upcoming Appointment',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text('$serviceName with $proName',
                      style:
                          const TextStyle(color: Colors.white, fontSize: 12)),
                  Text(formatted,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
