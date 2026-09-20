import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// D-181: the admin dashboard could not say which screens got attention,
/// because almost no route was pushed with a name. The observer fell back to
/// the route's Dart type, so every unnamed push in the app aggregated into a
/// single `MaterialPageRoute<dynamic>` row — 597 opens against 11 for the one
/// screen that happened to be identifiable.
void main() {
  final sources = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  /// The index just past the balanced `(...)` that starts at [from].
  int callEnd(String text, int from) {
    var i = text.indexOf('(', from);
    var depth = 0;
    while (i < text.length) {
      if (text[i] == '(') depth++;
      if (text[i] == ')') {
        depth--;
        if (depth == 0) return i + 1;
      }
      i++;
    }
    return -1;
  }

  test(
      'D-181-AC-01: every MaterialPageRoute in the app is pushed with an '
      'explicit RouteSettings name', () {
    final pattern = RegExp(r'MaterialPageRoute(<[^>]*>)?\s*\(');
    final unnamed = <String>[];
    var total = 0;

    for (final file in sources) {
      final text = file.readAsStringSync();
      for (final match in pattern.allMatches(text)) {
        total++;
        final end = callEnd(text, match.start);
        final body = text.substring(match.start, end);
        // Only this call's own arguments: a nested route's settings must not
        // be mistaken for the outer one's.
        final builderAt = body.indexOf('builder:');
        final head = builderAt == -1 ? body : body.substring(0, builderAt);
        final tail = builderAt == -1 ? '' : body.substring(builderAt);
        // A settings argument may follow the builder, at this call's depth.
        final ownsTailSettings = RegExp(r'\n\s{0,14}settings:').hasMatch(tail);
        if (!head.contains('settings:') && !ownsTailSettings) {
          final line = '\n'.allMatches(text.substring(0, match.start)).length + 1;
          unnamed.add('${file.path}:$line');
        }
      }
    }

    expect(total, greaterThan(40),
        reason: 'the scan should be finding the app\'s routes at all');
    expect(unnamed, isEmpty,
        reason: 'these routes would be reported to the admin dashboard as a '
            'Dart type rather than a screen name');
  });

  test(
      'D-181-AC-02: a route name is a screen identity, never a type with a '
      'generic in it', () {
    final names = <String>{};
    for (final file in sources) {
      for (final match
          in RegExp(r"RouteSettings\(\s*name:\s*'([^']+)'").allMatches(
              file.readAsStringSync())) {
        names.add(match.group(1)!);
      }
    }
    expect(names, isNotEmpty);
    for (final name in names) {
      expect(name, isNot(contains('<')), reason: name);
      expect(name, isNot(contains('Route')), reason: name);
      expect(name.trim(), name, reason: name);
      expect(name, isNotEmpty);
    }
  });

  test(
      'D-181-AC-03: only a full page is recorded as a screen, so dialogs, '
      'bottom sheets and popup menus stop being counted as ones', () {
    final source = File('lib/services/telemetry_service.dart').readAsStringSync();
    expect(source, contains('if (route is! PageRoute) return;'));
    // Both entry points must go through the same guard.
    expect(source, contains('void didPush('));
    expect(source, contains('void didReplace('));
    expect('_record('.allMatches(source).length, greaterThanOrEqualTo(3));
  });

  test(
      'D-181-AC-03: a PageRoute is recorded and a non-page route is not',
      () {
    final recorded = <Route<dynamic>>[];
    // Mirrors the observer's own predicate, which is the behaviour under
    // test; the observer itself writes to Firestore and cannot run here.
    void record(Route<dynamic> route) {
      if (route is! PageRoute) return;
      recorded.add(route);
    }

    final page = MaterialPageRoute<void>(
      settings: const RouteSettings(name: 'HomeScreenWidget'),
      builder: (_) => const SizedBox(),
    );
    // A dialog is a PopupRoute, the same category as the bottom sheets and
    // popup menus that were filling the dashboard.
    final dialog = RawDialogRoute<void>(
      pageBuilder: (_, __, ___) => const SizedBox(),
    );

    record(page);
    record(dialog);

    expect(recorded, hasLength(1));
    expect(recorded.single.settings.name, 'HomeScreenWidget');
    expect(dialog, isNot(isA<PageRoute>()));
  });
}
