import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D-133/D-136: structural regression tests, not a full widget pump — this
/// screen calls FirebaseAnalytics.instance and FirebaseAuth.instance the
/// same way every other Firebase-touching screen in this codebase does,
/// none of which are pumped in a widget test here (Firebase Core isn't
/// mocked anywhere in this suite). Same source-text-assertion pattern
/// schedule_habits_screen_test.dart already uses for its D-128 group.
void main() {
  final source = File('lib/screens/homescreen.dart').readAsStringSync();

  group('D-133/D-136: the hamburger menu offers Sign out and "Set up '
      'again" — two genuinely different actions, never sharing a code '
      'path', () {
    test('the "Setup" menu item now reads "Set up again"', () {
      expect(source, contains("child: Text('Set up again')"));
    });

    test('"Set up again" never signs the user out and never goes near '
        'WelcomeScreen — it stays signed in and rebuilds the existing, '
        'cloud-synced pyramid in place, a different and more '
        'consequential action than the plain first-run screen', () {
      final start = source.indexOf('Future<void> navigateToSetup(');
      expect(start, greaterThan(-1));
      final end = source.indexOf('\n  }', start);
      final body = source.substring(start, end);
      expect(body, isNot(contains('WelcomeScreen')));
      expect(body, isNot(contains('AccountLinkService.instance.signOut()')));
      expect(body, contains('SetupScreen'));
    });

    test('"Set up again" explicitly confirms before erasing anything — '
        'the confirm dialog names what\'s about to be destroyed', () {
      final start = source.indexOf('Future<void> navigateToSetup(');
      final end = source.indexOf('\n  }', start);
      final body = source.substring(start, end);
      expect(body, contains("title: const Text('Set up again?'"));
      expect(body, contains('erased'));
      expect(body, contains('LocalPyramidResetService.instance.wipeLocalPyramid()'));
    });

    test('Sign out is offered only when actually signed in with a real '
        'account — checked live (AuthService.instance.isAnonymous), so it '
        'can never linger stale in the menu across a sign-out', () {
      expect(source, contains('if (!AuthService.instance.isAnonymous)'));
      expect(source, contains("value: 'signOut'"));
    });

    test('signing out from the menu confirms, then goes through '
        'AccountLinkService, and leaves the app genuinely signed out '
        '(no eager re-anonymization) before landing on the plain '
        'WelcomeScreen — identical to a fresh install, per the owner\'s '
        'correction that "logged out" has no sub-states', () {
      final start = source.indexOf('Future<void> signOut(BuildContext context)');
      expect(start, greaterThan(-1));
      final end = source.indexOf('\n  }', start);
      final body = source.substring(start, end);
      expect(body, contains("title: const Text('Sign out?'"));
      expect(body, contains('await AccountLinkService.instance.signOut();'));
      expect(body, isNot(contains('signInSilently()')));
      expect(body, contains('pushAndRemoveUntil('));
      expect(body, contains('const WelcomeScreen()'));
    });
  });
}
