import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/services/subscription_panel_logic.dart';

/// D-115: pure decision logic for the settings screen's subscription
/// panel — regression coverage for the reported bug: "when I clicked on
/// update subscription, the subscription section doesn't work at all so
/// it seems to think I already have a subscription, but I am on the
/// three day trial."
void main() {
  group('decideSubscriptionPanelState', () {
    test('D-115: loading before RevenueCat info has arrived', () {
      expect(decideSubscriptionPanelState(isActive: null),
          SubscriptionPanelState.loading);
    });

    test(
        'D-115: a trialing account with no real RevenueCat purchase gets '
        'needsSubscription, never a cancel-only state — this is the exact '
        'bug: a 3-day trial (D-057) never touches RevenueCat, so '
        '`isActive` is false the whole time', () {
      expect(decideSubscriptionPanelState(isActive: false),
          SubscriptionPanelState.needsSubscription);
    });

    test(
        'D-115: a lapsed account (trial over, never subscribed) also gets '
        'needsSubscription — RevenueCat sees the same "no purchase" state '
        'as trialing', () {
      expect(decideSubscriptionPanelState(isActive: false, willRenew: false),
          SubscriptionPanelState.needsSubscription);
    });

    test('D-115: an active, renewing subscription gets activeRenewing', () {
      expect(
          decideSubscriptionPanelState(isActive: true, willRenew: true),
          SubscriptionPanelState.activeRenewing);
    });

    test(
        'D-115: an active but cancelled (not renewing) subscription gets '
        'activeCancelling, offering resubscribe rather than manage', () {
      expect(
          decideSubscriptionPanelState(isActive: true, willRenew: false),
          SubscriptionPanelState.activeCancelling);
    });
  });

  group('subscriptionPanelMessage', () {
    test('D-115: names the trial plainly for a trialing account', () {
      expect(subscriptionPanelMessage('trialing'), contains('free trial'));
    });

    test('D-115: names the trial having ended for a lapsed account', () {
      expect(subscriptionPanelMessage('lapsed'), contains('trial has ended'));
    });

    test('D-115: falls back to generic subscribe copy for pre_trial/null',
        () {
      expect(subscriptionPanelMessage('pre_trial'), contains('Subscribe'));
      expect(subscriptionPanelMessage(null), contains('Subscribe'));
    });
  });
}
