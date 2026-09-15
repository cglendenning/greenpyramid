import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('D-144-AC-03: restored accounts get one explicit recovery offer', () {
    final source = File('lib/screens/homescreen.dart').readAsStringSync();
    expect(source, contains('areNotificationsEnabled()'));
    expect(source, contains('d144.notification_recovery_offered'));
    expect(source, contains('showDialog<bool>'));
    expect(source, contains('requestPermissions()'));
    expect(source, contains("Uri.parse('app-settings:')"));
    expect(source, contains('user.isAnonymous'));
  });
}
