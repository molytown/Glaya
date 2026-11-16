import 'package:flutter/material.dart';

/// Glaya color palette — magenta theme
///   --magenta: #D6006E (vivid magenta)  --magenta-dark: #880E4F
///   --magenta-light: #F8BBD0  --magenta-bg: #FCE4EC   --magenta-border: #F48FB1
///   --text-dark: #1A1A2E   --text-gray: #6B7280 --text-light: #9CA3AF
///   --off-white: #F9FAFB   --border: #E5E7EB   --star: #F59E0B  --green: #10B981
class GlayaColors {
  GlayaColors._();

  // Primary colors — magenta / deep magenta
  static const Color berry = Color(0xFFD6006E);
  static const Color vibrantPink = Color(0xFFE91E63);
  static const Color accentPink = Color(0xFF880E4F);
  static const Color pinkDark = Color(0xFF880E4F);
  static const Color wineDeep = Color(0xFF4A0E2E);

  // Magenta gradient — light magenta → deep magenta (left → right)
  static const LinearGradient berryGradient = LinearGradient(
    colors: [vibrantPink, berry, wineDeep],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // Magenta tints — light / bg / border
  static const Color pinkLight = Color(0xFFF8BBD0);
  static const Color pinkBg = Color(0xFFFCE4EC);
  static const Color pinkBorder = Color(0xFFF48FB1);

  // Neutrals — React text / surface / border
  static const Color background = Color(0xFFF4F5F7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color offWhite = Color(0xFFF9FAFB);

  static const Color error = Color(0xFFB3261E);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color star = Color(0xFFF59E0B);

  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textGray = Color(0xFF9CA3AF);

  static const Color divider = Color(0xFFE5E7EB);
  static const Color border = Color(0xFFE5E7EB);

  // Soft shadows — React --shadow-sm/md/lg (neutral black)
  static const Color shadow = Color(0x1F000000);
  static const Color softShadow = Color(0x14000000);
  static const Color mediumShadow = Color(0x1A000000);

  // Decorative accents (magenta tints)
  static const Color roseGold = Color(0xFFF48FB1);
  static const Color softLavender = Color(0xFFE6E6FA);
  static const Color softCoral = Color(0xFFFF7F50);
  static const Color cream = Color(0xFFFFFDD0);
  static const Color blushPink = Color(0xFFFCE4EC);
  static const Color mauve = Color(0xFFE0B0FF);
  static const Color accentPurple = Color(0xFF7B1FA2);
  static const Color dustyRose = Color(0xFFD8A7A0);
  static const Color sageGreen = Color(0xFFBCEAD0);
  static const Color softPeach = Color(0xFFFFDAB9);
}
