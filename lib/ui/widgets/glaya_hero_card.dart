import 'package:flutter/material.dart';
import '../app_theme_glaya2.dart';

class GlayaHeroCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badge;

  const GlayaHeroCard(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.badge});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: const [GlayaTheme2.primary, GlayaTheme2.accent]),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: GlayaTheme2.primary.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 8))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(999)),
                  child: Text(badge,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 10),
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(subtitle,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16)),
            child:
                const Icon(Icons.auto_awesome, color: Colors.white, size: 30),
          ),
        ],
      ),
    );
  }
}
