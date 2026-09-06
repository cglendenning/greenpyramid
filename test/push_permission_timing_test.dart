import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D-038/D-065: push permission is requested exactly once, right after
/// setup's completion moment settles — never on first launch. Structural,
/// since the actual OS permission dialog can't be exercised in a test.
void main() {
  test('D-038: main.dart\'s launch-time notification initialize call does '
      'not request permission', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(source, contains('LocalNotificationService().intialize()'));
    // main.dart must not call requestPermissions() at all — that only
    // happens from the setup completion flow.
    expect(source, isNot(contains('requestPermissions')));
  });

  test('D-065: requestPermissions is invoked only from the post-completion '
      'push permission screen', () {
    final callers = [
      'lib/screens/push_permission_screen.dart',
    ];
    for (final path in callers) {
      expect(File(path).readAsStringSync(), contains('requestPermissions()'));
    }

    // No other screen should call it directly.
    final offenders = Directory('lib/screens')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !callers.contains(f.path))
        .where((f) => f.readAsStringSync().contains('requestPermissions()'))
        .toList();
    expect(offenders, isEmpty);
  });

  test('D-065: setup hands off completion -> push permission -> home, in '
      'that order', () {
    final source = File('lib/screens/setup_screen.dart').readAsStringSync();
    final completionIdx = source.indexOf('SetupCompletionScreen(');
    final pushIdx = source.indexOf('PushPermissionScreen(');
    expect(completionIdx, greaterThan(-1));
    expect(pushIdx, greaterThan(completionIdx),
        reason: 'push permission must be requested after the completion moment');
  });
}
