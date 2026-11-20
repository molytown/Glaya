import 'package:flutter/material.dart';
import '../../../../shared/theme/colors.dart';

class HomeSectionTitle extends StatelessWidget {
  final String title;
  final Widget? titleWidget;
  final String? subtitle;
  final VoidCallback? onSeeAll;
  final bool showSeeAll;

  const HomeSectionTitle({
    super.key,
    this.title = '',
    this.titleWidget,
    this.subtitle,
    this.onSeeAll,
    this.showSeeAll = true,
  });

  @override
  Widget build(BuildContext context) {
    final titleChild = titleWidget ??
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: GlayaColors.textPrimary,
          ),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                titleChild,
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF000000),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (showSeeAll)
            GestureDetector(
              onTap: onSeeAll,
              child: const Row(
                children: [
                  Text(
                    'See all',
                    style: TextStyle(
                      color: GlayaColors.berry,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(Icons.chevron_right, color: GlayaColors.berry, size: 18),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
