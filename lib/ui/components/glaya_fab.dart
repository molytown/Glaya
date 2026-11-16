import 'package:flutter/material.dart';
import '../app_theme_glaya2.dart';

class GlayaFAB extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  const GlayaFAB({super.key, required this.onTap, this.icon = Icons.add});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: FloatingActionButton(
        onPressed: onTap,
        backgroundColor: GlayaTheme2.primary,
        elevation: 10,
        child: Icon(icon, size: 28, color: Colors.white),
      ),
    );
  }
}
