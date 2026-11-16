import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' as services;

/// Utility class for providing haptic feedback throughout the app
/// Adds satisfying micro-interactions for better user experience
/// Note: Haptic feedback is only available on mobile platforms (iOS/Android)
class HapticFeedback {
  HapticFeedback._();

  static final bool _isMobile = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
       defaultTargetPlatform == TargetPlatform.android);

  /// Light haptic feedback for subtle interactions
  static void light() {
    if (_isMobile) {
      services.HapticFeedback.lightImpact();
    }
  }

  /// Medium haptic feedback for standard interactions
  static void medium() {
    if (_isMobile) {
      services.HapticFeedback.mediumImpact();
    }
  }

  /// Heavy haptic feedback for important actions
  static void heavy() {
    if (_isMobile) {
      services.HapticFeedback.heavyImpact();
    }
  }

  /// Selection feedback for selecting items
  static void selection() {
    if (_isMobile) {
      services.HapticFeedback.selectionClick();
    }
  }

  /// Success feedback for completed actions
  static void success() {
    if (_isMobile) {
      services.HapticFeedback.mediumImpact();
      Future.delayed(const Duration(milliseconds: 50), () {
        services.HapticFeedback.lightImpact();
      });
    }
  }

  /// Error feedback for failed actions
  static void error() {
    if (_isMobile) {
      services.HapticFeedback.heavyImpact();
    }
  }

  /// Warning feedback
  static void warning() {
    if (_isMobile) {
      services.HapticFeedback.mediumImpact();
    }
  }

  /// Custom pattern for delightful interactions
  static void delightful() {
    if (_isMobile) {
      services.HapticFeedback.lightImpact();
      Future.delayed(const Duration(milliseconds: 100), () {
        services.HapticFeedback.lightImpact();
      });
    }
  }
}
