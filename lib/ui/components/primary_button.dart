import 'package:flutter/material.dart';
import '../../shared/widgets/glaya_gradient_button.dart';

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool small;
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.small = false});

  @override
  Widget build(BuildContext context) {
    return GlayaGradientButton(
      label: label,
      onPressed: onPressed,
      small: small,
    );
  }
}
