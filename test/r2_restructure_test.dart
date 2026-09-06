import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Structural tests for R2's layered restructure.
///
/// D-024 requires that screens delegate to services rather than owning raw
/// SQL, model-call construction, or derived computation. These assert the
/// structure directly, so a later change cannot quietly reintroduce logic
/// into the UI layer.
void main() {
  Iterable<File> dartsIn(String dir) => Directory(dir).existsSync()
      ? Directory(dir)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
      : const <File>[];

  // Screens deleted by D-069/D-083 in R6 are exempt: restructuring code that
  // is about to be removed is wasted work.
  const doomed = [
    'coach.dart', 'morning.dart', 'afternoon.dart', 'evening.dart',
    'mindset_select.dart', 'motivation.dart', '/setup/', '/tutorial/',
  ];
  bool survivesR6(File f) => !doomed.any((d) => f.path.contains(d));

  group('D-024: the layered structure exists', () {
    test('D-024: lib root holds only main and firebase_options', () {
      final rootDarts = Directory('lib')
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .toSet();
      expect(rootDarts, {'main.dart', 'firebase_options.dart'});
    });

    test('D-024: every layer directory exists', () {
      for (final d in ['models', 'providers', 'services', 'screens', 'widgets', 'theme']) {
        expect(Directory('lib/$d').existsSync(), isTrue, reason: 'lib/$d missing');
      }
    });

    test('D-024: lib/graveyard stays deleted', () {
      expect(Directory('lib/graveyard').existsSync(), isFalse);
    });
  });

  group('D-024: screens own no business logic', () {
    test('D-024: no surviving screen contains raw SQL', () {
      final offenders = dartsIn('lib/screens')
          .where(survivesR6)
          .where((f) {
            final b = f.readAsStringSync();
            return b.contains('rawUpdate(') ||
                b.contains('rawInsert(') ||
                b.contains('rawDelete(') ||
                b.contains('rawQuery(');
          })
          .map((f) => f.path)
          .toList();
      expect(offenders, isEmpty,
          reason: 'raw SQL belongs in a service, parameterized');
    });

    test('D-024: models hold no Flutter widget imports', () {
      final offenders = dartsIn('lib/models')
          .where((f) =>
              f.readAsStringSync().contains("package:flutter/material.dart"))
          .map((f) => f.path)
          .toList();
      expect(offenders, isEmpty);
    });
  });

  group('D-024: user input is never interpolated into SQL', () {
    test('D-024: extracted statements bind their arguments', () {
      final db = File('lib/services/db.dart').readAsStringSync();
      for (final m in [
        'setTaskDayFlag',
        'renameTask',
        'upsertCategoryAt',
        'setTaskLogChecked',
        'deleteTaskLogsForTask',
        'deleteCategoryContents',
      ]) {
        expect(db.contains(m), isTrue, reason: '$m should exist in db.dart');
      }
      expect(db.contains('whereArgs'), isTrue);
    });

    test('D-024: the day-column allowlist rejects an injected column name', () {
      final db = File('lib/services/db.dart').readAsStringSync();
      expect(db.contains('dayColumns'), isTrue);
      expect(db.contains('ArgumentError.value'), isTrue,
          reason: 'day must be validated, never interpolated blindly');
    });
  });
}
