import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D-061: Settings carries the re-clarification entry point. Structural
/// (source-text) rather than a widget test, matching this repo's existing
/// convention for entry-point wiring (r2_restructure_test.dart) — the
/// screen itself is gated behind Firebase Auth/Firestore and D-016's
/// entitlement check, which need a live account to exercise meaningfully.
void main() {
  test('D-061: Settings carries the "Revisit a category with the Council" '
      'row, wired to the category picker', () {
    final source = File('lib/screens/settings.dart').readAsStringSync();
    expect(source, contains('Revisit a category with the Council'));
    expect(source, contains('CouncilCategoryPicker'));
  });

  test('D-016: choosing a category checks entitlement before opening a '
      'Council session', () {
    final source =
        File('lib/screens/council_category_picker.dart').readAsStringSync();
    expect(source, contains('columnEntitlement'));
    expect(source, contains("'trialing'"));
    expect(source, contains("'subscribed'"));
  });
}
