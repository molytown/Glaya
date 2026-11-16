import 'package:flutter/material.dart';
import '../../../../shared/theme/colors.dart';

class HomeLocationBar extends StatelessWidget {
  final String locationLabel;
  final VoidCallback? onTap;

  const HomeLocationBar({
    super.key,
    required this.locationLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: GlayaColors.surface,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            const Icon(Icons.location_on, color: GlayaColors.berry, size: 16),
            const SizedBox(width: 4),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current location',
                  style: TextStyle(fontSize: 10, color: GlayaColors.textGray),
                ),
                Row(
                  children: [
                    Text(
                      locationLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: GlayaColors.textPrimary,
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down, size: 16, color: GlayaColors.textPrimary),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
