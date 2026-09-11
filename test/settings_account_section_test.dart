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

    test('D-144: the confirmation is a single question, "Sign out?" — '
        'no body text explaining that data is saved to the account', () {
      final start = source.indexOf('Future<void> _confirmSignOut()');
      final end = source.indexOf('\n  }', start);
      final body = source.substring(start, end);
      expect(body, isNot(contains('content:')));
      expect(body, isNot(contains('saved to your account')));
    });

    test('D-136: confirmed sign-out goes through AccountLinkService and '
        'leaves the app genuinely signed out — no eager re-anonymization; '
        'a screen that actually needs a session establishes one lazily, '
        'exactly when it needs it (AccountLinkService.signInWithApple/'
        'signInWithGoogle)', () {
      expect(source, contains('await AccountLinkService.instance.signOut();'));
      expect(source, isNot(contains('signInSilently()')));
    });

    test('D-136: after sign-out, the whole nav stack is replaced with the '
        'plain WelcomeScreen — identical to a fresh install, never left '
        'reachable by backing out into the now-signed-out home screen',
        () {
      expect(source, contains('pushAndRemoveUntil('));
      expect(source, contains('const WelcomeScreen()'));
      expect(source, contains('(route) => false,'));
    });
  });
}
