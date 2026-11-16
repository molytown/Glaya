import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../shared/theme/colors.dart';
import '../../../../shared/services/config_service.dart';
import '../../../../shared/widgets/verification_badge.dart';
import '../../data/professional_model.dart';

class SalonProfileHeader extends StatelessWidget {
  final ProfessionalModel professional;

  const SalonProfileHeader({super.key, required this.professional});

  @override
  Widget build(BuildContext context) {
    final displayName = professional.businessName ?? professional.name;
    final configService = ConfigService();
    final photoUrl = professional.photoUrl != null
        ? configService.replaceLocalhost(professional.photoUrl!)
        : null;
    final isVerified = professional.verificationStatus == 'approved';
    final rating = professional.avgRating ?? 0.0;
    final reviewCount = professional.totalReviews;
    final onlineStatus = professional.onlineStatus ?? 'offline';
    final isOnline = onlineStatus == 'online';
    final isBusy = onlineStatus == 'busy';

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: photoUrl ?? '',
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        Container(color: GlayaColors.berry.withOpacity(0.1)),
                    errorWidget: (_, __, ___) =>
                        Container(color: GlayaColors.berry.withOpacity(0.1)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ),
                        if (isVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified,
                            color: Colors.blue,
                            size: 18,
                          ),
                        ],
                        const SizedBox(width: 6),
                        VerificationBadge(
                          subscriptionType: professional.subscriptionType,
                          size: VerificationBadgeSize.medium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          color: Color(0xFFF59E0B),
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '($reviewCount reviews)',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF888888),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: GlayaColors.berry,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          professional.displayArea ?? 'Location not set',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF666666),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isOnline
                                ? const Color(0xFF10B981).withOpacity(0.15)
                                : isBusy
                                ? const Color(0xFFF59E0B).withOpacity(0.15)
                                : const Color(0xFF9E9E9E).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isOnline
                                ? 'Open'
                                : isBusy
                                ? 'Busy'
                                : 'Closed',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isOnline
                                  ? const Color(0xFF10B981)
                                  : isBusy
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFF9E9E9E),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (professional.totalBookings > 0)
                      Text(
                        '${professional.totalBookings} bookings completed',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF888888),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.push('/book/${professional.id}'),
              style: ElevatedButton.styleFrom(
                backgroundColor: GlayaColors.berry,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Book Appointment',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/chat/list'),
                  icon: const Icon(
                    Icons.chat_bubble_outline,
                    size: 18,
                    color: GlayaColors.berry,
                  ),
                  label: const Text(
                    'Message',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: GlayaColors.berry,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: GlayaColors.berry),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final address =
                        professional.displayArea ?? 'Location not set';
                    final Uri mapUri = Uri(
                      scheme: 'https',
                      host: 'maps.google.com',
                      path: '/search',
                      queryParameters: {'api': '1', 'query': address},
                    );
                    if (await canLaunchUrl(mapUri)) {
                      launchUrl(mapUri, mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(
                    Icons.directions_outlined,
                    size: 18,
                    color: GlayaColors.berry,
                  ),
                  label: const Text(
                    'Directions',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: GlayaColors.berry,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: GlayaColors.berry),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final phone = professional.phone ?? '';
                    if (phone.isNotEmpty) {
                      final Uri phoneUri = Uri(scheme: 'tel', path: phone);
                      if (await canLaunchUrl(phoneUri)) {
                        launchUrl(phoneUri);
                      }
                    }
                  },
                  icon: const Icon(
                    Icons.phone_outlined,
                    size: 18,
                    color: GlayaColors.berry,
                  ),
                  label: const Text(
                    'Call',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: GlayaColors.berry,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: GlayaColors.berry),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
