import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D-115: the settings screen mirrors Kansei's (`goal-executor`) layout —
/// sectioned cards, an entitlement-aware subscription panel, and a "send
/// test notification" control — structural, matching this repo's
/// convention for screens built on live plugins/singletons
/// (RevenueCat's `Purchases`, `flutter_local_notifications`).
void main() {
  test(
      'D-115: the subscription panel branches through '
      'decideSubscriptionPanelState rather than assuming an active '
      'subscription — regression test for the reported bug: "when I '
      'clicked on update subscription, the subscription section doesn\'t '
      'work at all so it seems to think I already have a subscription, '
      'but I am on the three day trial"', () {
    final source = File('lib/screens/settings.dart').readAsStringSync();
    expect(source, contains('decideSubscriptionPanelState('));
    expect(source, contains('subscriptionPanelMessage('));
    expect(source, contains('PaywallScreen('));
  });

  test(
      'D-115: "Manage subscription" (the cancel flow) is gated behind '
      '_openManage, called only from the activeRenewing branch — not '
      'reachable from needsSubscription, which is what a trialing account '
      'actually hits', () {
    final source = File('lib/screens/settings.dart').readAsStringSync();
    final renewingStart = source.indexOf('SubscriptionPanelState.activeRenewing:');
    final cancellingStart = source.indexOf('SubscriptionPanelState.activeCancelling:');
    final needsSubStart = source.indexOf('SubscriptionPanelState.needsSubscription:');
    expect(renewingStart, greaterThan(-1));
    expect(cancellingStart, greaterThan(renewingStart));
    expect(needsSubStart, greaterThan(cancellingStart));

    final renewingBranch = source.substring(renewingStart, cancellingStart);
    final needsSubBranch = source.substring(needsSubStart);
    expect(renewingBranch, contains('_openManage'));
    expect(needsSubBranch, isNot(contains('CancelSubscriptionScreen')));
  });

  test('D-115: a test notification can be sent from settings', () {
    final source = File('lib/screens/settings.dart').readAsStringSync();
    expect(source, contains('isTestNotificationPending()'));
  });

  test(
      'D-154: the settings test notification now uses a real newsfeed '
      "item's own headline/body, not a generic message — owner: \"the "
      'button to send a test notification [should] behave the same way '
      "that it will have a headline of one of the news items and when "
      'you tap the notification it brings you to that headline in the '
      'newsfeed."', () {
    final source = File('lib/screens/settings.dart').readAsStringSync();
    expect(source,
        contains('NewsfeedService.instance.seedSampleCardsIfNeeded()'));
    expect(source, contains('scheduleNewsfeedTestNotification('));
  });

  test(
      'D-115: notification.dart\'s test notification no longer routes to '
      'the deleted /morning, /afternoon, /evening screens (D-083) — '
      'regression test for the previous version\'s five-notification '
      'burst that would throw on tap since those routes no longer exist',
      () {
    final source = File('lib/services/notification.dart').readAsStringSync();
    expect(source, isNot(contains("payload: '/morning'")));
    expect(source, isNot(contains("payload: '/afternoon'")));
    expect(source, isNot(contains("payload: '/evening'")));
    expect(source, contains('testNotificationId'));
  });

  test(
      'D-115: homescreen.dart no longer unconditionally schedules the '
      'legacy morning/afternoon/evening local notifications on every '
      'build — found live while building this change: they routed to '
      '/morning, /afternoon, /evening, screens D-083 already deleted, and '
      'ran regardless of push authorization, duplicating the real D-038 '
      'fallback push_messaging_service.dart already implements correctly',
      () {
    final source = File('lib/screens/homescreen.dart').readAsStringSync();
    expect(source, isNot(contains("payload: '/morning'")));
    expect(source, isNot(contains("payload: '/afternoon'")));
    expect(source, isNot(contains("payload: '/evening'")));
  });

  group('D-184: the real OS notification-permission state is checked and '
      'surfaced, not just whether a test notification was accepted for '
      'scheduling — found live: "Send test notification" showed '
      '"Pending…" and the notification never arrived, with no error '
      'anywhere, because iOS accepts a schedule request and silently '
      'drops it at delivery time when permission is denied', () {
    test('checks the real permission state via '
        'LocalNotificationService.areNotificationsEnabled(), not '
        'isTestNotificationPending() (which only confirms the plugin '
        'accepted the schedule request)', () {
      final source = File('lib/screens/settings.dart').readAsStringSync();
      expect(source, contains('widget.lns.areNotificationsEnabled()'));
    });

    test('does not depend on package:permission_handler for this check — '
        'that package requires an iOS Podfile macro '
        '(PERMISSION_NOTIFICATIONS) this project has never enabled for '
        'any permission group, so it would silently report the wrong '
        'status rather than the real one', () {
      final source = File('lib/screens/settings.dart').readAsStringSync();
      expect(source, isNot(contains('permission_handler')));
      expect(source, isNot(contains('Permission.notification')));
    });

    test('an off state shows a banner whose action requests permission '
        'directly first — not just a bare "Open Settings" link — since an '
        'account that completed setup before D-065\'s permission screen '
        'existed has never called the OS request API at all, so iOS never '
        'creates a Notifications entry under Settings to open: found live '
        'via a screenshot showing no Notifications row whatsoever under '
        'Settings > Green Pyramid', () {
      final source = File('lib/screens/settings.dart').readAsStringSync();
      expect(source, contains('Notifications are off for Green Pyramid'));
      expect(source, contains('widget.lns.requestPermissions()'));
      expect(source, contains("Uri.parse('app-settings:')"));
      expect(source, contains('Enable Notifications'));
    });

    test('requestPermissions() returns whether permission was actually '
        'granted, so the banner can fall back to opening Settings only '
        'when it was already asked and declined, not on a first-ever ask',
        () {
      final source = File('lib/services/notification.dart').readAsStringSync();
      expect(source, contains('Future<bool> requestPermissions()'));
      expect(source, contains('Future<bool> _requestNotificationPermissions()'));
    });

    test('the permission state is rechecked on app resume, so returning '
        'from the "Open Settings" button reflects a just-granted '
        'permission without needing to leave and re-enter this screen',
        () {
      final source = File('lib/screens/settings.dart').readAsStringSync();
      expect(source, contains('with WidgetsBindingObserver'));
      expect(source, contains('didChangeAppLifecycleState'));
      expect(source, contains('AppLifecycleState.resumed'));
    });
  });

  group('D-184: LocalNotificationService.areNotificationsEnabled() reads '
      'the real OS state per platform', () {
    final source = File('lib/services/notification.dart').readAsStringSync();

    test('iOS reads IOSFlutterLocalNotificationsPlugin.checkPermissions() '
        '— the same already-working plugin every other notification '
        'call in this file already uses, not a second, unconfigured one',
        () {
      expect(source, contains('checkPermissions()'));
      expect(source, contains('options?.isEnabled'));
    });

    test('Android reads AndroidFlutterLocalNotificationsPlugin.'
        'areNotificationsEnabled(), the same call _requestNotificationPermissions() '
        'already makes for its own debug logging', () {
      final start = source.indexOf('Future<bool> areNotificationsEnabled()');
      final end = source.indexOf('\n  }', start);
      expect(source.substring(start, end), contains('.areNotificationsEnabled()'));
    });
  });
}
