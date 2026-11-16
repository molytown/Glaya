import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// Glaya gradient button — raspberry wine gradient (vibrant → berry → deep wine),
/// matching the app's primary button styling.
class GlayaGradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool small;
  final EdgeInsetsGeometry? padding;

  const GlayaGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.small = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final child = icon != null
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: small ? 16 : 18, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: small ? 13 : 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          )
        : Text(
            label,
            style: TextStyle(
              fontSize: small ? 13 : 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          );

    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: Material(
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            gradient: GlayaColors.berryGradient,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: GlayaColors.wineDeep.withOpacity(0.4)),
          ),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: padding ??
                  EdgeInsets.symmetric(
                    vertical: small ? 10 : 14,
                    horizontal: small ? 14 : 20,
                  ),
              alignment: Alignment.center,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
