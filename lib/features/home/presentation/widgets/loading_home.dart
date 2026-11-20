import 'package:flutter/material.dart';

class HomeLoadingPlaceholder extends StatelessWidget {
  final double height;

  const HomeLoadingPlaceholder({super.key, this.height = 200});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }
}
