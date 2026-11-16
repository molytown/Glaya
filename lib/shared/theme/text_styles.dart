import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

class GlayaTextStyles {
  GlayaTextStyles._();

  static TextStyle get _base => GoogleFonts.poppins();

  static TextStyle headlineLarge({Color? color}) => _base.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: color ?? GlayaColors.textPrimary,
        letterSpacing: -0.5,
      );

  static TextStyle headlineMedium({Color? color}) => _base.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: color ?? GlayaColors.textPrimary,
      );

  static TextStyle headlineSmall({Color? color}) => _base.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: color ?? GlayaColors.textPrimary,
      );

  static TextStyle titleLarge({Color? color}) => _base.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: color ?? GlayaColors.textPrimary,
      );

  static TextStyle titleMedium({Color? color}) => _base.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: color ?? GlayaColors.textPrimary,
      );

  static TextStyle bodyLarge({Color? color}) => _base.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: color ?? GlayaColors.textSecondary,
      );

  static TextStyle bodyMedium({Color? color}) => _base.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: color ?? GlayaColors.textSecondary,
      );

  static TextStyle bodySmall({Color? color}) => _base.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: color ?? GlayaColors.textTertiary,
      );

  static TextStyle labelLarge({Color? color}) => _base.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: color ?? GlayaColors.textPrimary,
      );

  static TextStyle button({Color? color}) => _base.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: color ?? Colors.white,
      );
}
