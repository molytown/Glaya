import 'package:flutter/material.dart';
import 'colors.dart';
import 'text_styles.dart';

class GlayaAppTheme {
  GlayaAppTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: GlayaColors.berry,
        onPrimary: Colors.white,
        secondary: GlayaColors.vibrantPink,
        onSecondary: Colors.white,
        surface: GlayaColors.surface,
        error: GlayaColors.error,
        onError: Colors.white,
        onSurface: GlayaColors.textPrimary,
      ),
      scaffoldBackgroundColor: GlayaColors.pinkBg,
      textTheme: TextTheme(
        displayLarge: GlayaTextStyles.headlineLarge(),
        displayMedium: GlayaTextStyles.headlineMedium(),
        displaySmall: GlayaTextStyles.headlineSmall(),
        headlineMedium: GlayaTextStyles.titleLarge(),
        titleMedium: GlayaTextStyles.titleMedium(),
        bodyLarge: GlayaTextStyles.bodyLarge(),
        bodyMedium: GlayaTextStyles.bodyMedium(),
        bodySmall: GlayaTextStyles.bodySmall(),
        labelLarge: GlayaTextStyles.labelLarge(),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: GlayaColors.background,
        titleTextStyle: GlayaTextStyles.titleLarge(),
        iconTheme: const IconThemeData(color: GlayaColors.textPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: GlayaColors.berry,
          foregroundColor: Colors.white,
          textStyle: GlayaTextStyles.button(),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          minimumSize: const Size.fromHeight(48),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: GlayaColors.berry,
          side: const BorderSide(color: GlayaColors.berry),
          textStyle: GlayaTextStyles.button(color: GlayaColors.berry),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          minimumSize: const Size.fromHeight(48),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: GlayaColors.accentPink,
          textStyle: GlayaTextStyles.labelLarge(color: GlayaColors.accentPink),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: GlayaColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: GlayaColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: GlayaColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: GlayaColors.berry, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: GlayaColors.error),
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: GlayaColors.pinkBorder),
        ),
        color: GlayaColors.surface,
        shadowColor: GlayaColors.shadow,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: GlayaColors.surface,
        selectedItemColor: GlayaColors.berry,
        unselectedItemColor: Color(0xFF000000),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      dividerTheme: const DividerThemeData(
        color: GlayaColors.divider,
        thickness: 1,
      ),
    );
  }

  static ThemeData get darkTheme {
    return lightTheme.copyWith(
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: GlayaColors.vibrantPink,
        onPrimary: Colors.white,
        secondary: GlayaColors.accentPink,
        onSecondary: Colors.white,
        surface: Color(0xFF1E1E1E),
        error: GlayaColors.error,
        onError: Colors.white,
        onSurface: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFF121212),
    );
  }
}
