import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The shared visual language for every screen. Screens may choose a more
/// specific text style for meaning, but they should start from these tokens.
class AppTheme {
  AppTheme._();

  static ThemeData dark() {
    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      fontFamily: 'Raleway',
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brandGreen,
        brightness: Brightness.dark,
        primary: AppColors.brandGreen,
        secondary: AppColors.brandPurple,
        surface: AppColors.surface,
      ),
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        fontFamily: 'Raleway',
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
    );
  }
}
