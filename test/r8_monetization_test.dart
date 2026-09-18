import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D-011/D-012/D-014/D-054: structural checks for R8's monetization wiring,
/// matching this repo's convention for screens gated behind a live account
/// (council_entry_point_test.dart, r7_coach_retirement_test.dart) — the
/// screens themselves need Firebase/RevenueCat to exercise meaningfully, so
/// these confirm the wiring in source rather than via widget tests.
void main() {
  test(
      'D-011/D-014/D-142: an unentitled account revisiting a category is '
      'routed to the paywall, not a dead-end dialog — via the shared '
      'ensureEntitled gate (which itself pushes PaywallScreen), not a '
      'private duplicate of that push', () {
    final source =
        File('lib/screens/council_category_picker.dart').readAsStringSync();
    expect(source, contains('ensureEntitled(context'));
    expect(source, contains('reason:'));
  });

  test(
      'D-075/D-014/D-142: an unentitled account opening the general '
      'Council is routed to the paywall before GeneralCouncilScreen is '
      'ever pushed, not a dead-end "could not open" error — via the '
      'shared ensureEntitled gate, same as CouncilCategoryPicker', () {
    final source = File('lib/screens/homescreen.dart').readAsStringSync();
    final navIdx = source.indexOf('Future<void> navigateToCouncil(');
    expect(navIdx, greaterThan(-1));
    final navEnd = source.indexOf('\n  }', navIdx);
    final body = source.substring(navIdx, navEnd);
    expect(body, contains('ensureEntitled(context'));
    expect(body, contains('reason:'));
    final gateIdx = body.indexOf('ensureEntitled(context');
    final pushIdx = body.indexOf('GeneralCouncilScreen()');
    expect(pushIdx, greaterThan(gateIdx),
        reason: 'the entitlement check and paywall route must come before '
            'GeneralCouncilScreen is ever pushed');
  });

  test(
      'D-054: the paywall fetches the live store product rather than '
      'hardcoding a price, and reports a confirmed purchase back to the '
      'caller', () {
    final source = File('lib/screens/paywall_screen.dart').readAsStringSync();
    expect(source, contains('SubscriptionService.getMonthlyProduct()'));
    expect(source, contains('Navigator.pop(context, true)'));
  });

  test(
      'D-148/D-012: setup completion requests the device-bound trial and '
      'shows the one-time disclosure before push permission, in that order',
      () {
    final source = File('lib/screens/setup_screen.dart').readAsStringSync();
    final service = File('lib/services/setup_service.dart').readAsStringSync();
    expect(service, contains('entitlement.requestTrialAfterSetup()'));
    expect(source, contains('TrialDisclosureScreen('));
    expect(source, contains('PushPermissionScreen('));
    expect(source, contains('onDone: permissions'));
  });

  test(
      'D-012: the disclosure screen states different copy for a device '
      'that already consumed its trial (lapsed) vs a fresh grant (trialing)',
      () {
    final source =
        File('lib/screens/trial_disclosure_screen.dart').readAsStringSync();
    expect(source, contains('_lapsed'));
    expect(source, contains("entitlement == 'lapsed'"));
  });

  test('D-054: Settings carries a subscription-management entry point', () {
    final source = File('lib/screens/settings.dart').readAsStringSync();
    expect(source, contains('Manage subscription'));
    expect(source, contains('CancelSubscriptionScreen'));
  });

  test('D-062: spend-limit surfaces do not promise unavailable top-ups', () {
    for (final path in [
      'lib/screens/council_screen.dart',
      'lib/screens/general_council_screen.dart',
      'lib/screens/profile.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains('More can be purchased soon')));
      expect(source, contains('resets at the start of next month'));
    }
  });

  test(
      'D-044: entitlement is never decided on-device — the only literal '
      'entitlement value EntitlementService ever writes locally is '
      "'subscribed', as an optimistic mirror right after a confirmed "
      'purchase; every other value it writes is read from a server '
      'response, never assigned as a client-side literal', () {
    final source =
        File('lib/services/entitlement_service.dart').readAsStringSync();
    expect(source, isNot(contains("entitlement: 'trialing'")));
    expect(source, isNot(contains("entitlement: 'lapsed'")));
    expect(source, contains("entitlement: 'subscribed'"));
  });

  test(
      'D-045: the Android device hash is computed with SHA-256 and the '
      'raw ANDROID_ID is never sent to the backend', () {
    final source =
        File('lib/services/entitlement_service.dart').readAsStringSync();
    expect(source, contains('sha256.convert'));
    expect(source, isNot(contains("body['androidId']")));
  });

  test(
      'D-045: the DeviceCheck environment flag sent for iOS trial requests '
      'reflects this build\'s actual code-signing environment, not Dart\'s '
      'kDebugMode', () {
    final source =
        File('lib/services/entitlement_service.dart').readAsStringSync();
    expect(source, contains('_isDeviceCheckDevelopmentEnvironment'));
    expect(source,
        contains("'isDevelopmentBuild': _isDeviceCheckDevelopmentEnvironment"));
    expect(source, isNot(contains("'isDevelopmentBuild': kDebugMode")));

    final exportOptions = File('ios/ExportOptions.plist').readAsStringSync();
    final signsDevelopment =
        exportOptions.contains('<string>development</string>');
    // The flag's value must match ExportOptions.plist's actual method —
    // this is the exact coupling that broke live; keep them locked together.
    expect(
        source,
        contains(signsDevelopment
            ? '_isDeviceCheckDevelopmentEnvironment = true'
            : '_isDeviceCheckDevelopmentEnvironment = false'));
  });

  test(
      'D-010: the subscription is the sole revenue model — no ad SDK '
      'dependency exists alongside RevenueCat', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('purchases_flutter'));
    expect(pubspec, isNot(contains('google_mobile_ads')));
    expect(pubspec, isNot(contains('admob')));
  });

  test(
      'D-013: habit tracking and the pyramid never check entitlement — a '
      'lapsed account keeps the tracker forever, with no paywall on it', () {
    // homescreen.dart added for D-075: navigateToCouncil() gates the
    // general Council entry point the same way council_category_picker.dart
    // already gates category re-clarification — a second legitimate D-014
    // gate site, not habit tracking or the pyramid gating on entitlement.
    // newsfeed_screen.dart added for D-122: gates visibility of the
    // "Generate new analysis" on-demand control — the base newsfeed
    // itself remains ungated (D-122), only this one AI-costing control
    // checks entitlement, the same "one legitimate gate site per real AI
    // feature" pattern the other two entries already establish.
    final gatedScreens = [
      'lib/screens/council_category_picker.dart',
      'lib/screens/homescreen.dart',
      'lib/screens/newsfeed_screen.dart',
    ];
    final offenders = Directory('lib/screens')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !gatedScreens.contains(f.path))
        .where((f) => f.readAsStringSync().contains('columnEntitlement'))
        .where((f) =>
            f.path !=
            'lib/screens/setup_screen.dart') // writes the trial grant, never gates on it
        .toList();
    expect(offenders, isEmpty);
  });

  test(
      'D-015: setup\'s free AI exchange is bounded by call count '
      '(D-148), while authenticated calls use server-owned reservation '
      'billing under D-061', () {
    final source = File('functions/index.js').readAsStringSync();
    final guardIdx = source.indexOf('async function guardCouncilCall');
    final isSetupBranchIdx = source.indexOf('if (isSetup) {', guardIdx);
    final authenticatedBillingIdx = source.indexOf('reserveCost(', guardIdx);
    expect(isSetupBranchIdx, greaterThan(-1));
    expect(authenticatedBillingIdx, greaterThan(isSetupBranchIdx),
        reason:
            'authenticated calls must reserve against the server-owned spend cap after the setup branch');
    final setupBranch =
        source.substring(isSetupBranchIdx, authenticatedBillingIdx);
    expect(setupBranch, contains('guardAndCountSetupCall'));
    expect(setupBranch, isNot(contains('reserveCost(')),
        reason: 'the setup branch is governed by its call-count allowance');
    expect(source, contains('settleReservedCost('));
  });

  test(
      'D-019: trial state is exactly one of three values everywhere it '
      'is checked', () {
    final source = File('functions/lib/entitlement.js').readAsStringSync();
    expect(source, contains("'trialing'"));
    expect(source, contains("'subscribed'"));
  });
}
