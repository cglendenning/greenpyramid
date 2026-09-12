import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D-130: structural regression tests, not a full widget pump — this
/// screen calls FirebaseAnalytics.instance in initState the same way
/// every other analytics-logging screen in this codebase does
/// (faq.dart, homescreen.dart, ...), none of which are pumped in a
/// widget test here either, since Firebase Core isn't mocked anywhere
/// in this suite. Same source-text-assertion pattern
/// schedule_habits_screen_test.dart already uses for its D-128 group.
void main() {
  final source = File('lib/screens/account_creation_screen.dart').readAsStringSync();

  group('D-130: mandatory account creation before the pyramid reveal', () {
    test('wraps its content in PopScope(canPop: false) — no back gesture, '
        'consistent with D-128\'s mechanism: nothing to go back to once '
        'habits are committed and the Council session has ended', () {
      expect(source, contains('canPop: false'));
    });

    test('offers no skip affordance — no "Skip" or "Later" control exists '
        'anywhere on this screen, per "required"', () {
      expect(source.toLowerCase(), isNot(contains('skip')));
      expect(source.toLowerCase(), isNot(contains("'later'")));
    });

    test('offers exactly Apple and Google sign-in, wired to '
        'AccountLinkService — no email/password form (deliberately not '
        'porting goal-executor\'s form, which is real typing friction on '
        'the one screen meant to have none)', () {
      expect(source, contains('widget.linkService.signInWithApple'));
      expect(source, contains('widget.linkService.signInWithGoogle'));
      expect(source, isNot(contains('TextField')));
      expect(source, isNot(contains('obscureText')));
    });

    test('uses the shared OnboardingBackdrop — the same rotating-photo '
        'collage as WelcomeScreen, TrialDisclosureScreen, and '
        'PushPermissionScreen (D-099), not a bespoke background', () {
      expect(source, contains('OnboardingBackdrop('));
    });

    test('D-132: declares onDone with whether AccountLinkService switched '
        'to a different, already-existing account (credential-already-in-'
        'use) rather than linking the current one — every caller needs to '
        'react differently to the two outcomes. D-162: onDone itself is '
        'now called from SigningInScreen on success (see that screen\'s '
        'own tests) — this screen only threads it through.', () {
      expect(source, contains('void Function({required bool switchedToExistingAccount}) onDone'));
      expect(source, contains('onDone: widget.onDone'));
    });

    test('AccountLinkService is injectable, not hardcoded to the '
        'singleton — the real singleton talks to native Apple/Google SDKs '
        'that cannot run in a test', () {
      expect(source, contains('AccountLinkService? linkService'));
    });
  });

  group('D-130: setup_screen.dart wires AccountCreationScreen before '
      'SetupCompletionScreen', () {
    final setupSource = File('lib/screens/setup_screen.dart').readAsStringSync();

    test('_confirmHabitsAndClose navigates to AccountCreationScreen, not '
        'straight to SetupCompletionScreen', () {
      expect(setupSource, contains('AccountCreationScreen('));
      expect(setupSource, contains('onDone: ({required switchedToExistingAccount}) async {'));
    });

    test('D-132: a credential-already-in-use switch restores the real '
        'account\'s cloud data and goes straight home, skipping '
        'SetupCompletionScreen entirely — the pyramid just built in this '
        'session belongs to the abandoned anonymous account, not the real '
        'one just switched into', () {
      expect(setupSource, contains('SyncService.instance.restoreFromCloud(uid)'));
      expect(setupSource, contains("pushNamedAndRemoveUntil('/', (route) => false)"));
    });

    test('an already non-anonymous current user (shouldn\'t happen mid-'
        'setup, but linkWithCredential throws on one) skips straight to '
        'completion instead of showing a screen with nothing to do', () {
      expect(setupSource, contains('FirebaseAuth.instance.currentUser?.isAnonymous == false'));
    });
  });

  group('D-143: the actual sign-in work (and D-139\'s error handling) now '
      'lives in SigningInScreen, reached via Navigator.push — this screen '
      'only reacts to the SignInOutcome that comes back', () {
    test('_handle pushes SigningInScreen and awaits a SignInOutcome, '
        'instead of calling the sign-in function directly inline — the '
        'awaited outcome now only ever represents a failure or a '
        'cancellation (D-162)', () {
      expect(source, contains('Navigator.of(context).push<SignInOutcome>('));
      expect(source, contains('signIn: signIn,'));
      expect(source, contains('provider: provider,'));
    });

    test('a cancelled outcome shows no error — matches D-139\'s original '
        '"Apple sheet dismissed is not a failure" behavior', () {
      expect(source, contains('outcome.cancelled) return'));
    });

    test('an outcome carrying an error message sets it on this screen\'s '
        'own _error state, for display here — not on SigningInScreen, '
        'which has already popped by the time it\'s shown', () {
      expect(source, contains('_error = outcome.errorMessage'));
    });

    test('no more inline "submitting" spinner or fixed-duration '
        '"Welcome back — signing you in..." message on this screen — '
        'that state is now SigningInScreen\'s job entirely', () {
      expect(source, isNot(contains('_submitting')));
      expect(source, isNot(contains('_welcomeBackMessage')));
    });
  });
}
