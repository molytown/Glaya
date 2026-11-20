import 'package:flutter/material.dart';
import '../app_theme_glaya2.dart';

class GlayaChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const GlayaChip({super.key, required this.label, this.selected = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? GlayaTheme2.primary.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? GlayaTheme2.primary : Colors.grey.shade300),
          boxShadow: selected ? [const BoxShadow(color: Color(0x22000000), blurRadius: 6, offset: Offset(0, 2))] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? GlayaTheme2.primary : Color(0xFF000000),
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
