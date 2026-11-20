import 'package:flutter/material.dart';
import 'animated_gradient_background.dart';
import 'flowing_water_background.dart';

/// Seasonal auth slide-out background:
/// - Nov 1 – Jan 5  -> flowing water animation (winter/holiday)
/// - Jan 6 – Oct 31 -> animated brand gradient (matches React waterFlow)
class SeasonalAuthBackground extends StatelessWidget {
  final Widget child;

  const SeasonalAuthBackground({
    super.key,
    required this.child,
  });

  static bool _isWinterSeason(DateTime now) {
    return now.month == 11 ||
        now.month == 12 ||
        (now.month == 1 && now.day <= 5);
  }

  @override
  Widget build(BuildContext context) {
    if (_isWinterSeason(DateTime.now())) {
      return FlowingWaterBackground(child: child);
    }
    return AnimatedGradientBackground(child: child);
  }
}
