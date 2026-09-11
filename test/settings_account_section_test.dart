import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D-132: structural regression tests, not a full widget pump — this
/// screen calls FirebaseAnalytics.instance and RevenueCat's
/// SubscriptionService the same way the rest of settings.dart already
/// does, none of which are pumped in a widget test here (no Firebase/
/// RevenueCat mocking exists in this suite). Same source-text-assertion
/// pattern schedule_habits_screen_test.dart already uses for its D-128
/// group.
void main() {
  final source = File('lib/screens/settings.dart').readAsStringSync();

  group('D-132: Settings offers sign-out, gated by a confirmation dialog',
      () {
    test('an ACCOUNT section exists', () {
      expect(source, contains("_sectionLabel('ACCOUNT')"));
      expect(source, contains('_card(child: const _AccountSection())'));
    });

    test('signing out shows a confirm dialog before doing anything '
        'destructive', () {
      expect(source, contains("title: const Text('Sign out?'"));
      expect(source, contains('showDialog<bool>'));
    });

    test('confirmed sign-out goes through AccountLinkService, then '
        're-establishes a fresh anonymous session before showing anything '
        'else — every Firestore-touching screen in this app assumes at '
        'least an anonymous uid exists (D-032)', () {
      expect(source, contains('await AccountLinkService.instance.signOut();'));
      expect(source, contains('await AuthService.instance.signInSilently();'));
    });

    test('after sign-out, the whole nav stack is replaced with '
        'WelcomeScreen(isResetup: true) — never left reachable by backing '
        'out into the now-signed-out home screen', () {
      expect(source, contains('pushAndRemoveUntil('));
      expect(source, contains('WelcomeScreen(isResetup: true)'));
      expect(source, contains('(route) => false,'));
    });
  });
}
