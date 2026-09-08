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

  test('D-038/D-065: found live — DarwinInitializationSettings must request '
      'nothing at intialize() time, or iOS shows the OS dialog at app '
      'launch regardless of what requestPermissions() textually calls, '
      'since flutter_local_notifications requests permission from '
      'initialize() itself whenever these flags are true', () {
    final source = File('lib/services/notification.dart').readAsStringSync();
    final settingsIdx = source.indexOf('DarwinInitializationSettings(');
    expect(settingsIdx, greaterThan(-1));
    final settingsEnd = source.indexOf(');', settingsIdx);
    final block = source.substring(settingsIdx, settingsEnd);
    expect(block, contains('requestAlertPermission: false'));
    expect(block, contains('requestBadgePermission: false'));
    expect(block, contains('requestSoundPermission: false'));
  });

  test('D-038/D-065: the iOS branch of requestPermissions actually calls '
      'the plugin\'s permission API — found live, it previously only '
      'printed a debug line and relied on initialize() to have already '
      'asked, which is exactly the bug the previous test guards against',
      () {
    final source = File('lib/services/notification.dart').readAsStringSync();
    expect(source, contains('IOSFlutterLocalNotificationsPlugin'));
    expect(source, contains('?.requestPermissions(alert: true, badge: true, sound: true)'));
  });
}
