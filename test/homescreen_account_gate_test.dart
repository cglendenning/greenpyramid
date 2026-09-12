import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D-132: structural regression tests, not a full widget pump — this
/// screen calls FirebaseAnalytics.instance the same way every other
/// analytics-logging screen in this codebase does, none of which are
/// pumped in a widget test here either (Firebase Core isn't mocked
/// anywhere in this suite). Same source-text-assertion pattern
/// schedule_habits_screen_test.dart already uses for its D-128 group.
///
/// Catches the exact gap Craig hit live: setup already completed before
/// D-130 existed, so nothing had ever prompted him to link a real
/// credential — D-130 only fires *during* setup, never for an account
/// that predates it.
void main() {
  final homescreenSource = File('lib/screens/homescreen.dart').readAsStringSync();

  group('D-132: a real account is enforced by the time the home screen is '
      'reached', () {
    test('_HomeScreen awaits signInSilently() before checking isAnonymous '
        '— main.dart\'s bootstrap is fire-and-forget (D-032) and not '
        'guaranteed to have run yet', () {
      expect(homescreenSource, contains('await AuthService.instance.signInSilently();'));
      expect(homescreenSource, contains('AuthService.instance.isAnonymous'));
    });

    test('the gate is scheduled once via addPostFrameCallback in initState '
        '— once per app session (this widget is mounted once at launch), '
        'not once per tab switch', () {
      expect(homescreenSource,
          contains('WidgetsBinding.instance.addPostFrameCallback((_) => _enforceRealAccount());'));
    });

    test('a plain link (the common case) pops the gate and refreshes — it '
        'never blocks the pyramid the user already has', () {
      expect(homescreenSource, contains('Navigator.of(context).pop();'));
      expect(homescreenSource, contains('setState(() => setFutures());'));
    });

    test('a credential-already-in-use switch restores the real account\'s '
        'cloud data — a real edge case: this device already had a local '
        'pyramid *and* the identity used already belongs to a different, '
        'real account', () {
      expect(homescreenSource, contains('SyncService.instance.restoreFromCloud(uid)'));
    });
  });

  group('D-162: onDone pops both SigningInScreen and AccountCreationScreen '
      '— found live alongside the same-cause bug on WelcomeScreen\'s own '
      'sign-in link. onDone now fires from within SigningInScreen (still '
      'on top of AccountCreationScreen), so a single pop here would leave '
      'AccountCreationScreen stuck on screen with nothing left to dismiss '
      'it.', () {
    test('the AccountCreationScreen onDone callback pops exactly twice, '
        'synchronously — no await between the two pops, so no '
        'intermediate frame can reveal AccountCreationScreen again', () {
      final onDoneStart = homescreenSource.indexOf('onDone: ({required bool switchedToExistingAccount})');
      expect(onDoneStart, greaterThan(-1));
      final onDoneEnd = homescreenSource.indexOf('},', onDoneStart);
      final onDoneBody = homescreenSource.substring(onDoneStart, onDoneEnd);
      final popCount = RegExp('Navigator.of(context).pop();'.replaceAll('(', r'\(').replaceAll(')', r'\)'))
          .allMatches(onDoneBody)
          .length;
      expect(popCount, 2);
      // No `await ` keyword in the actual callback body (comments aside —
      // this file's own explanation of the fix uses the word "await" in
      // prose, which a bare `contains('await')` check would trip on).
      final codeOnly = onDoneBody
          .split('\n')
          .map((line) => line.trim())
          .where((line) => !line.startsWith('//'))
          .join('\n');
      expect(codeOnly, isNot(contains('await ')));
    });
  });
}
