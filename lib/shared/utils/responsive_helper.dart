import 'package:flutter/material.dart';

/// Helper class for responsive design decisions
class ResponsiveHelper {
  /// Returns true if the current screen width indicates a tablet device
  /// Uses 600px as the breakpoint (Material Design standard)
  static bool isTablet(BuildContext context) {
    return MediaQuery.of(context).size.width >= 600;
  }

  /// Returns true if the current screen width indicates a desktop device.
  /// Desktop gets the React-style web UI (top navbar, grid homepage, no
  /// mobile bottom nav / app header / footer).
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1024;
  }

  /// Returns true if the current screen width indicates a mobile device
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
  }

  /// Returns the number of columns to use for a grid layout based on screen width
  static int gridColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1200) return 4;
    if (width >= 900) return 3;
    if (width >= 600) return 2;
    return 1;
  }
}
