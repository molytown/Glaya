import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../shared/theme/colors.dart';

class PhoneInputField extends StatelessWidget {
  final TextEditingController controller;

  const PhoneInputField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.phone,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      maxLength: 15,
      decoration: InputDecoration(
        labelText: 'Phone Number',
        hintText: '7XX XXX XXX',
        prefixIcon: const Icon(Icons.phone, color: GlayaColors.berry),
        counterText: '',
      ),
    );
  }
}
