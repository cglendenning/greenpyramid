import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/theme/app_colors.dart';
import 'package:life_ops/theme/app_theme.dart';

void main() {
  // D-151-AC-03 is completed by the Android emulator visual review recorded
  // with this test evidence.
  test('D-151-AC-01 defines the shared editorial system in AppTheme', () {
    final theme = AppTheme.dark();

    expect(theme.textTheme.bodyLarge?.fontFamily, AppTypography.editorial);
    expect(theme.scaffoldBackgroundColor, AppColors.background);
    expect(theme.colorScheme.primary, AppColors.brandGreen);
    expect(theme.colorScheme.secondary, AppColors.brandPurple);
    expect(theme.appBarTheme.backgroundColor, Colors.transparent);
    expect(theme.cardTheme.color, AppColors.surface);
    expect(theme.textTheme.bodyMedium?.fontFamily, AppTypography.editorial);
    expect(theme.textTheme.labelSmall?.fontFamily, AppTypography.metadata);
  });

  test('D-151-AC-02 keeps the root route on the shared theme', () {
    final homeSource = File('lib/screens/homescreen.dart').readAsStringSync();

    expect(homeSource, contains('theme: AppTheme.dark()'));
    expect(homeSource, isNot(matches(RegExp(r'\bThemeData\s*\('))));
  });

  test('D-151-AC-02 has no parallel ThemeData definitions in screens', () {
    final screenFiles = Directory('lib/screens')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    for (final file in screenFiles) {
      expect(
          file.readAsStringSync(), isNot(matches(RegExp(r'\bThemeData\s*\('))),
          reason: file.path);
    }
  });
}
