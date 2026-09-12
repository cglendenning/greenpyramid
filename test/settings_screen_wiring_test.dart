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
}
