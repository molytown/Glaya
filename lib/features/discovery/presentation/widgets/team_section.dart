import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/theme/colors.dart';
import '../../data/professional_model.dart';

class TeamSection extends StatelessWidget {
  final ProfessionalModel professional;

  const TeamSection({super.key, required this.professional});

  @override
  Widget build(BuildContext context) {
    final hasTeam = professional.businessName != null &&
        professional.businessName!.isNotEmpty;

    if (!hasTeam) return const SizedBox.shrink();

    // Only show the actual professional (no hardcoded team members)
    final team = [
      {
        'name': professional.name,
        'role': professional.category,
        'photo': professional.photoUrl,
        'rating': professional.avgRating,
      },
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Our Team',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: team.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                final member = team[i];
                return _TeamMemberCard(
                  name: member['name'] as String,
                  role: member['role'] as String,
                  photo: member['photo'] as String?,
                  rating: member['rating'] is num
                      ? (member['rating'] as num).toDouble()
                      : double.tryParse('${member['rating']}'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamMemberCard extends StatelessWidget {
  final String name;
  final String role;
  final String? photo;
  final double? rating;

  const _TeamMemberCard({
    required this.name,
    required this.role,
    this.photo,
    this.rating,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: GlayaColors.berry.withValues(alpha: 0.1),
            ),
            child: ClipOval(
              child: photo != null
                  ? CachedNetworkImage(
                      imageUrl: photo!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          const Icon(Icons.person, color: GlayaColors.berry),
                      errorWidget: (_, __, ___) =>
                          const Icon(Icons.person, color: GlayaColors.berry),
                    )
                  : const Icon(Icons.person, color: GlayaColors.berry),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            role,
            style: const TextStyle(fontSize: 10, color: Color(0xFF888888)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (rating != null) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, color: Color(0xFFF59E0B), size: 12),
                const SizedBox(width: 2),
                Text(
                  rating!.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
