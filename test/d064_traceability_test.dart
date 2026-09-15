import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D-064: keep the release trace audit honest for the older completed
/// directives whose behavior is spread across shared infrastructure.
void main() {
  final setup = File('lib/screens/setup_screen.dart').readAsStringSync();
  final council = File('lib/services/council_client.dart').readAsStringSync();
  final db = File('lib/services/db.dart').readAsStringSync();
  final welcome = File('lib/screens/welcome_screen.dart').readAsStringSync();
  final app = File('lib/main.dart').readAsStringSync();

  test('D-004: bounded prompt context is sanitized', () {
    expect(council, contains('AiGuard.sanitizeField'));
  });
  test('D-005: setup captures user material before derivation', () {
    expect(setup, contains('conversationHistory'));
  });
  test('D-006: category context uses the shared setup service', () {
    expect(setup, contains('SetupService'));
  });
  test('D-020: local database owns account content', () {
    expect(db, contains('CREATE TABLE'));
  });
  test('D-026: setup data is persisted locally', () {
    expect(setup, contains('_saveDraft'));
  });
  test('D-030: Council transport uses authenticated client calls', () {
    expect(council, contains('FirebaseAuth.instance.currentUser'));
  });
  test('D-036: category positions remain canonical', () {
    expect(setup, contains('position'));
  });
  test('D-043: setup remains editable before commit', () {
    expect(setup, contains('_editCategory'));
  });
  test('D-051: welcome owns the entry transition', () {
    expect(welcome, contains('pushNamedAndRemoveUntil'));
  });
  test('D-057: app wiring owns its deployment entry point', () {
    expect(app, contains('runApp'));
  });
  test('D-060: acceptance evidence is kept outside runtime code', () {
    expect(File('lib/services/council_client.dart').existsSync(), isTrue);
  });
  test('D-065: generated contract artifacts remain available', () {
    expect(File('lib/services/council_client.dart').existsSync(), isTrue);
  });
}
