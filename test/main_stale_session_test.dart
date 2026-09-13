import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'D-001-AC-01: launch preserves Firebase identity and routes an unfinished draft to setup',
      () {
    final source = File('lib/main.dart').readAsStringSync();
    final start = source.indexOf('// Pending setup must route');
    final end = source.indexOf('unawaited(_bootstrapAccountSync', start);
    final routing = source.substring(start, end);
    expect(routing, contains('SetupDraftStore(db: dbHelper).load(pending)'));
    expect(routing, contains("draft['state']['phase'] != 'finished'"));
    expect(routing, isNot(contains('signOut()')));
  });
}
