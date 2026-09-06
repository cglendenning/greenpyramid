import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D-013/D-014/D-016/D-070: structural checks for R8's monetization wiring,
/// matching this repo's convention for screens gated behind a live account
/// (council_entry_point_test.dart, r7_coach_retirement_test.dart) — the
/// screens themselves need Firebase/RevenueCat to exercise meaningfully, so
/// these confirm the wiring in source rather than via widget tests.
void main() {
  test('D-013/D-016: an unentitled account revisiting a category is routed '
      'to the paywall, not a dead-end dialog', () {
    final source = File('lib/screens/council_category_picker.dart').readAsStringSync();
    expect(source, contains('PaywallScreen('));
    expect(source, contains('reason:'));
  });

  test('D-070: the paywall fetches the live store product rather than '
      'hardcoding a price, and reports a confirmed purchase back to the '
      'caller', () {
    final source = File('lib/screens/paywall_screen.dart').readAsStringSync();
    expect(source, contains('SubscriptionService.getMonthlyProduct()'));
    expect(source, contains('Navigator.pop(context, true)'));
  });

  test('D-058/D-014: setup completion requests the device-bound trial and '
      'shows the one-time disclosure before push permission, in that order', () {
    final source = File('lib/screens/setup_screen.dart').readAsStringSync();
    final trialIdx = source.indexOf('requestTrialAfterSetup()');
    final disclosureIdx = source.indexOf('TrialDisclosureScreen(');
    final pushIdx = source.indexOf('PushPermissionScreen(');
    expect(trialIdx, greaterThan(-1));
    expect(disclosureIdx, greaterThan(trialIdx));
    expect(pushIdx, greaterThan(disclosureIdx));
  });

  test('D-014: the disclosure screen states different copy for a device '
      'that already consumed its trial (lapsed) vs a fresh grant (trialing)', () {
    final source = File('lib/screens/trial_disclosure_screen.dart').readAsStringSync();
    expect(source, contains('_lapsed'));
    expect(source, contains("entitlement == 'lapsed'"));
  });

  test('D-070: Settings carries a subscription-management entry point', () {
    final source = File('lib/screens/settings.dart').readAsStringSync();
    expect(source, contains('Manage subscription'));
    expect(source, contains('CancelSubscriptionScreen'));
  });

  test('D-057: entitlement is never decided on-device — the only literal '
      'entitlement value EntitlementService ever writes locally is '
      "'subscribed', as an optimistic mirror right after a confirmed "
      'purchase; every other value it writes is read from a server '
      'response, never assigned as a client-side literal', () {
    final source = File('lib/services/entitlement_service.dart').readAsStringSync();
    expect(source, isNot(contains("entitlement: 'trialing'")));
    expect(source, isNot(contains("entitlement: 'lapsed'")));
    expect(source, contains("entitlement: 'subscribed'"));
  });

  test('D-059: the Android device hash is computed with SHA-256 and the '
      'raw ANDROID_ID is never sent to the backend', () {
    final source = File('lib/services/entitlement_service.dart').readAsStringSync();
    expect(source, contains('sha256.convert'));
    expect(source, isNot(contains("body['androidId']")));
  });
}
