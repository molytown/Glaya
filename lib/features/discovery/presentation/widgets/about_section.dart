import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../shared/theme/colors.dart';
import '../../data/professional_model.dart';

class AboutSection extends StatelessWidget {
  final ProfessionalModel professional;

  const AboutSection({super.key, required this.professional});

  @override
  Widget build(BuildContext context) {
    final bio = professional.bio ?? '';
    final homeService = professional.homeService;
    final category = professional.category;
    String establishedYear = '';
    if (professional.createdAt != null) {
      try {
        establishedYear = DateFormat('y').format(professional.createdAt!);
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('About', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
          const SizedBox(height: 12),
          if (bio.isNotEmpty) ...[
            Text(bio, style: const TextStyle(fontSize: 14, color: Color(0xFF555555), height: 1.5)),
            const SizedBox(height: 12),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: GlayaColors.berry.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(category, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: GlayaColors.berry)),
              ),
              if (homeService) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Home Service', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (establishedYear.isNotEmpty)
            Text('Established $establishedYear', style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
        ],
      ),
    );
  }
}
