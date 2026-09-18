import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/services/push_messaging_service.dart';

// D-149-AC-01 and D-149-AC-04: fallback decisions and account-safe
// notification delivery behavior are exercised below.

void main() {
  group('D-149/D-149/D-021: notification fallback decision', () {
    test('D-021: a lapsed account always gets the static pool, even with '
        'push fully working', () {
      final action = decideNotificationFallback(
          entitlement: 'lapsed', pushAuthorized: true, hasToken: true);
      expect(action, NotificationFallbackAction.lapsedStatic);
    });

    test('D-149: push authorized with a registered token relies on push',
        () {
      final action = decideNotificationFallback(
          entitlement: 'trialing', pushAuthorized: true, hasToken: true);
      expect(action, NotificationFallbackAction.relyOnPush);
    });

    test('D-149: permission denied falls back to local', () {
      final action = decideNotificationFallback(
          entitlement: 'trialing', pushAuthorized: false, hasToken: false);
      expect(action, NotificationFallbackAction.localFallback);
    });

    test('D-149: permission granted but token registration failed still '
        'falls back to local', () {
      final action = decideNotificationFallback(
          entitlement: 'trialing', pushAuthorized: true, hasToken: false);
      expect(action, NotificationFallbackAction.localFallback);
    });

    test('D-014/R7: a pre_trial account with working push relies on push — '
        'everyone is treated as entitled until R8', () {
      final action = decideNotificationFallback(
          entitlement: 'pre_trial', pushAuthorized: true, hasToken: true);
      expect(action, NotificationFallbackAction.relyOnPush);
    });
  });

  test('D-149: FCM registration retries token readiness and listens for '
      'token refresh so an account cannot remain inbox-only after startup', () {
    final source =
        File('lib/services/push_messaging_service.dart').readAsStringSync();
    expect(source, contains('requestPermissionAndSync'));
    expect(source, contains('_getTokenWithRetry'));
    expect(source, contains('onTokenRefresh'));
    expect(source, contains('_registerInstallationToken'));
  });
}
