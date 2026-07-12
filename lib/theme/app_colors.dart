import 'package:flutter/material.dart';

// Central palette for the app's dark theme. The two brand colors (green and
// purple) come from the existing logo and app-bar gradient — everything
// else here exists to give the rest of the app a consistent dark backdrop
// instead of every screen hardcoding its own greys.
class AppColors {
  AppColors._();

  static const Color brandGreen = Color(0xFF66CC5D);
  static const Color brandPurple = Color(0xFFC35DCC);
  static const Color brandNavy = Color(0xFF000A61);
  static const Color brandBlue = Color(0xFF1782FF);

  static const List<Color> appBarGradient = [brandPurple, brandNavy, brandBlue];

  static const Color background = Color(0xFF0B0B0F);
  static const Color surface = Color(0xFF17171D);
  static const Color surfaceHigh = Color(0xFF212129);

  static const Color textPrimary = Color(0xFFF2F2F5);
  static const Color textSecondary = Color(0xFFB4B4BE);
}
