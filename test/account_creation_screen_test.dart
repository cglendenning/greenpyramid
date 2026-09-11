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

    test('D-132: calls onDone with whether AccountLinkService switched to a '
        'different, already-existing account (credential-already-in-use) '
        'rather than linking the current one — every caller needs to react '
        'differently to the two outcomes', () {
      expect(source, contains('widget.onDone(switchedToExistingAccount: switchedAccount)'));
      expect(source, contains('void Function({required bool switchedToExistingAccount}) onDone'));
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

  group('D-139: a failed sign-in is diagnosable, not a silent dead end', () {
    test('a canceled Apple sheet is not treated as an error — no message '
        'shown, submitting simply resets', () {
      expect(source, contains('AuthorizationErrorCode.canceled'));
    });

    test('the real error code is logged via analytics — Firebase Auth\'s '
        'client-side sign-in calls leave no server-side trail otherwise, '
        'and the prior kDebugMode-only print was invisible on a release '
        'build', () {
      expect(source, contains("name: 'account_creation_failed'"));
      expect(source, contains("'error_code': errorCode"));
    });

    test('the error code is surfaced in the user-facing message too, not '
        'just logged — so a report from the field is actionable', () {
      expect(source, contains(r'"($errorCode)"'));
    });
  });
}
