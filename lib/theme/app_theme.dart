import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Shared editorial typography tokens. Raleway carries readable copy while
/// Exo2 is reserved for compact labels and interface metadata.
class AppTypography {
  AppTypography._();

  static const String editorial = 'Raleway';
  static const String metadata = 'Exo2';
}

/// The shared visual language for every screen. Screens may choose a more
/// specific text style for meaning, but they should start from these tokens.
class AppTheme {
  AppTheme._();

  static ThemeData dark() {
    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      fontFamily: AppTypography.editorial,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brandGreen,
        brightness: Brightness.dark,
        primary: AppColors.brandGreen,
        secondary: AppColors.brandPurple,
        surface: AppColors.surface,
        error: AppColors.error,
      ),
    );
    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displayLarge: const TextStyle(
          fontFamily: AppTypography.editorial,
          fontSize: 32,
          fontWeight: FontWeight.w600,
          height: 1.2,
          color: AppColors.textPrimary,
        ),
        headlineMedium: const TextStyle(
          fontFamily: AppTypography.editorial,
          fontSize: 24,
          fontWeight: FontWeight.w600,
          height: 1.2,
          color: AppColors.textPrimary,
        ),
        titleLarge: const TextStyle(
          fontFamily: AppTypography.editorial,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          height: 1.25,
          color: AppColors.textPrimary,
        ),
        bodyLarge: const TextStyle(
          fontFamily: AppTypography.editorial,
          fontSize: 16,
          height: 1.55,
          color: AppColors.textPrimary,
        ),
        bodyMedium: const TextStyle(
          fontFamily: AppTypography.editorial,
          fontSize: 15,
          height: 1.7,
          color: AppColors.textSecondary,
        ),
        labelLarge: const TextStyle(
          fontFamily: AppTypography.metadata,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
          color: AppColors.textPrimary,
        ),
        labelSmall: const TextStyle(
          fontFamily: AppTypography.metadata,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: AppColors.textSecondary,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: AppTypography.editorial,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: const TextStyle(
          fontFamily: AppTypography.editorial,
          color: AppColors.textSecondary,
        ),
        labelStyle: const TextStyle(
          fontFamily: AppTypography.metadata,
          color: AppColors.textSecondary,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.brandGreen),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderSubtle,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.surfaceHigh,
        contentTextStyle: TextStyle(
          fontFamily: AppTypography.editorial,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
