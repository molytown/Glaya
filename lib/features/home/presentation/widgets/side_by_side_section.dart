import 'package:flutter/material.dart';
import '../../../../shared/utils/responsive_helper.dart';

/// Wrapper that displays two widgets side-by-side on tablet (width ≥ 600px)
/// and stacked vertically on mobile devices
class SideBySideSection extends StatelessWidget {
  final Widget left;
  final Widget right;
  final double spacing;
  final bool equalWidth;

  const SideBySideSection({
    super.key,
    required this.left,
    required this.right,
    this.spacing = 16,
    this.equalWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (ResponsiveHelper.isTablet(context)) {
          // Side-by-side layout for tablet
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (equalWidth)
                Expanded(child: left)
              else
                Flexible(child: left),
              SizedBox(width: spacing),
              if (equalWidth)
                Expanded(child: right)
              else
                Flexible(child: right),
            ],
          );
        } else {
          // Stacked layout for mobile
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              left,
              SizedBox(height: spacing),
              right,
            ],
          );
        }
      },
    );
  }
}
