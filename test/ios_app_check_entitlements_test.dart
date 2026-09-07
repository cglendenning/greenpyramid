import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Regression test for a startup defect that shipped to a physical device
/// as "Could not verify the app. Please try again." (council_client.dart /
/// ai_proxy_client.dart's App Check token acquisition).
///
/// main.dart activates Firebase App Check with `AppleProvider.appAttest`
/// for every non-debug iOS build (see the `kForceAppCheckDebug` comment).
/// Apple's App Attest silently fails token requests — no crash, no build
/// error, just every `FirebaseAppCheck.instance.getToken()` call throwing
/// at runtime — unless the app carries the
/// `com.apple.developer.devicecheck.appattest-environment` entitlement.
/// This project shipped with no `ios/Runner/Runner.entitlements` file at
/// all, so nothing caught the gap until a real device rejected every
/// App-Check-gated backend call. Structural (source-text) checks, matching
/// this repo's convention for native-project invariants Dart code can't
/// express (see setup_screen_opening_line_test.dart): there is no runtime
/// way to unit-test an Xcode signing setting.
void main() {
  final entitlementsFile = File('ios/Runner/Runner.entitlements');
  final pbxproj = File('ios/Runner.xcodeproj/project.pbxproj');

  test(
      'ios/Runner/Runner.entitlements exists and declares the App Attest '
      'environment', () {
    expect(entitlementsFile.existsSync(), isTrue,
        reason: 'Without this file, AppleProvider.appAttest fails every '
            'App Check token request on a real device — see main.dart\'s '
            'FirebaseAppCheck.instance.activate() call.');
    final content = entitlementsFile.readAsStringSync();
    expect(content,
        contains('com.apple.developer.devicecheck.appattest-environment'));
    expect(content, anyOf(contains('development'), contains('production')),
        reason: 'the entitlement value must be a real App Attest '
            'environment, not left as a placeholder');
  });

  test(
      'the Runner target actually signs with Runner.entitlements — the '
      'file alone does nothing if no build config references it', () {
    final content = pbxproj.readAsStringSync();
    final matches = 'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;'
        .allMatches(content)
        .length;
    // Debug, Release, and Profile configs for the Runner target (not
    // RunnerTests, which has no App Check surface). Three, not just one,
    // because a build config missing this setting silently signs without
    // the entitlement for that configuration only.
    expect(matches, greaterThanOrEqualTo(3),
        reason: 'expected CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements '
            'in all three Runner build configurations (Debug/Release/Profile)'
            ', found $matches');
  });

  test(
      'the App Attest entitlement is "production" — verified on-device, '
      'not assumed: Xcode\'s automatic signing embeds "production" here '
      'even for this project\'s "development"-method export '
      '(ios/ExportOptions.plist), because the App Attest environment '
      'tracks the provisioning profile\'s capability grant, not the '
      'export method. A "development" value here was tried first and '
      'built fine, but doesn\'t reflect what actually gets signed — '
      'pinned to the real value so a future edit doesn\'t quietly '
      'reintroduce that same wrong assumption.', () {
    final content = entitlementsFile.readAsStringSync();
    expect(content, contains('<string>production</string>'));
  });
}
