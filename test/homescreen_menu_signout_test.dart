import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D-133: structural regression tests, not a full widget pump — this
/// screen calls FirebaseAnalytics.instance and FirebaseAuth.instance the
/// same way every other Firebase-touching screen in this codebase does,
/// none of which are pumped in a widget test here (Firebase Core isn't
/// mocked anywhere in this suite). Same source-text-assertion pattern
/// schedule_habits_screen_test.dart already uses for its D-128 group.
void main() {
  final source = File('lib/screens/homescreen.dart').readAsStringSync();

  group('D-133: the hamburger menu offers Sign out and "Set up again"', () {
    test('the "Setup" menu item now reads "Set up again"', () {
      expect(source, contains("child: Text('Set up again')"));
    });

    test('"Set up again" routes through WelcomeScreen(isResetup: true), '
        'not the plain first-run mode — the user is already signed in '
        'with a real pyramid here', () {
      expect(source, contains('WelcomeScreen(isResetup: true)'));
    });

    test('Sign out is offered only when actually signed in with a real '
        'account — checked live (AuthService.instance.isAnonymous), so it '
        'can never linger stale in the menu across a sign-out', () {
      expect(source, contains('if (!AuthService.instance.isAnonymous)'));
      expect(source, contains("value: 'signOut'"));
    });

    test('signing out from the menu goes through a confirm dialog, then '
        'AccountLinkService, then re-establishes a fresh anonymous '
        'session (D-032\'s "always signed in" invariant) before landing '
        'on WelcomeScreen\'s resetup mode', () {
      expect(source, contains("title: const Text('Sign out?'"));
      expect(source, contains('await AccountLinkService.instance.signOut();'));
      expect(source, contains('await AuthService.instance.signInSilently();'));
      expect(source, contains('pushAndRemoveUntil('));
    });
  });
}
