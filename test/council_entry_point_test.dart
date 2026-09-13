import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D-061: Settings carries the re-clarification entry point. Structural
/// (source-text) rather than a widget test, matching this repo's existing
/// convention for entry-point wiring (r2_restructure_test.dart) — the
/// screen itself is gated behind Firebase Auth/Firestore and D-014's
/// entitlement check, which need a live account to exercise meaningfully.
void main() {
  test('D-061: Settings carries the "Revisit a category with the Council" '
      'row, wired to the category picker', () {
    final source = File('lib/screens/settings.dart').readAsStringSync();
    expect(source, contains('Revisit a category with the Council'));
    expect(source, contains('CouncilCategoryPicker'));
  });

  test('D-014/D-182: choosing a category checks entitlement before '
      'opening a Council session, via the shared ensureEntitled gate — '
      'not a private duplicate of its check (D-182: a duplicate here '
      'meant this screen never benefited from ensureEntitled\'s own '
      'server-freshness fix)', () {
    final source =
        File('lib/screens/council_category_picker.dart').readAsStringSync();
    expect(source, contains('ensureEntitled(context'));
    expect(source, contains("import '../services/entitlement_gate.dart';"));
    expect(source, isNot(contains('columnEntitlement')));
  });
}
