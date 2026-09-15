import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/services/push_messaging_service.dart';

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
}
