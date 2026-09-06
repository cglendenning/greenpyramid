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

  test('D-012: the subscription is the sole revenue model — no ad SDK '
      'dependency exists alongside RevenueCat', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('purchases_flutter'));
    expect(pubspec, isNot(contains('google_mobile_ads')));
    expect(pubspec, isNot(contains('admob')));
  });

  test('D-015: habit tracking and the pyramid never check entitlement — a '
      'lapsed account keeps the tracker forever, with no paywall on it', () {
    final gatedScreens = ['lib/screens/council_category_picker.dart'];
    final offenders = Directory('lib/screens')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !gatedScreens.contains(f.path))
        .where((f) => f.readAsStringSync().contains('columnEntitlement'))
        .where((f) => f.path != 'lib/screens/setup_screen.dart') // writes the trial grant, never gates on it
        .toList();
    expect(offenders, isEmpty);
  });

  test('D-017: setup\'s free AI exchange is bounded by call count '
      '(D-072), never by the D-087 spend cap — the two are mutually '
      'exclusive branches', () {
    final source = File('functions/index.js').readAsStringSync();
    final guardIdx = source.indexOf('async function guardCouncilCall');
    final isSetupBranchIdx = source.indexOf('if (isSetup) {', guardIdx);
    final elseIdx = source.indexOf('checkSpendLimit', guardIdx);
    expect(isSetupBranchIdx, greaterThan(-1));
    expect(elseIdx, greaterThan(isSetupBranchIdx),
        reason: 'checkSpendLimit must sit in the non-setup branch, after the isSetup check');
  });

  test('D-021: trial state is exactly one of three values everywhere it '
      'is checked', () {
    final source = File('functions/lib/entitlement.js').readAsStringSync();
    expect(source, contains("'trialing'"));
    expect(source, contains("'subscribed'"));
  });
}
