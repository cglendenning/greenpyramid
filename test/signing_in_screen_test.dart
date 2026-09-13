import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D-143: structural regression tests, not a full widget pump — this
/// screen calls FirebaseAnalytics.instance and FirebaseAuth.instance
/// directly, neither mocked in this suite (same reasoning
/// account_creation_screen_test.dart already documents for its own
/// screen). Same source-text-assertion pattern used throughout this
/// codebase for screens that can't be widget-pumped.
///
/// Owner — "as it's signing you in, rather than dropping you back to the
/// sign in screen with text on the screen indicating that it is signing
/// you in, it should go to a new screen with a small slow spinning,
/// glowing green pyramid and just says signing in… And then it drops
/// into the main page with the pyramid once sign in succeeds, or drops
/// you back to the sign in page if sign in fails."
void main() {
  final source = File('lib/screens/signing_in_screen.dart').readAsStringSync();

  group('D-143: a dedicated screen owns the actual sign-in wait, instead '
      'of a fixed-duration message on the button screen', () {
    test('shows a small, continuously and slowly rotating pyramid — not '
        'a fixed splash, an ongoing animation for as long as sign-in '
        'actually takes', () {
      expect(source, contains('RotationTransition('));
      expect(source, contains('..repeat()'));
      expect(source, contains("duration: const Duration(seconds: 10)"));
    });

    test('the pyramid has a soft glow — a blurred, tinted copy behind '
        'the crisp one', () {
      expect(source, contains('ImageFiltered('));
      expect(source, contains('ImageFilter.blur('));
      expect(source, contains('AppColors.brandGreen'));
    });

    test('uses the app\'s own vector brand mark, not a new asset', () {
      expect(source, contains("'images/svg/logo_green.svg'"));
    });

    test('says exactly "Signing in…"', () {
      expect(source, contains("'Signing in…'"));
    });

    test('wraps its content in PopScope(canPop: false) — nothing '
        'coherent to go back to mid-sign-in', () {
      expect(source, contains('canPop: false'));
    });

    test('kicks off the sign-in call immediately from initState, and on '
        'success calls onDone directly rather than popping back to '
        'AccountCreationScreen', () {
      expect(source, contains('_run();'));
      expect(source, contains('await widget.signIn()'));
      expect(source, contains('widget.onDone(switchedToExistingAccount: switchedAccount)'));
    });

    test('D-162: found live — popping back to AccountCreationScreen on '
        'success genuinely re-revealed it (including its own reveal '
        'transition) for the entire duration of whatever async work the '
        'caller\'s onDone still had left (a real Firestore round trip for '
        'a switched account). Owner: "it quickly flips back to the '
        'signing page and then to the main pyramid screen." Calling '
        'onDone directly from here means this screen\'s own loading state '
        'covers that whole remaining duration instead, and the final '
        'navigation is a single transition straight to the real '
        'destination.', () {
      expect(source, isNot(contains('SignInOutcome.success')));
      expect(source, contains('required this.onDone'));
    });

    test('D-139 carried over: a canceled Apple sheet is not treated as '
        'an error', () {
      expect(source, contains('AuthorizationErrorCode.canceled'));
      expect(source, contains('SignInOutcome.cancelled()'));
    });

    test('D-139 carried over: the real error code is always logged via '
        'analytics, regardless of whether it\'s shown to the user', () {
      expect(source, contains("name: 'account_creation_failed'"));
      expect(source, contains("'error_code': errorCode"));
    });

    test('D-180: found live — a raw internal exception type name '
        '("PlatformException") used to leak straight into the user-facing '
        'message; only a genuinely legible named error code (Firebase\'s '
        'or Apple\'s own) is shown, and the bare-runtimeType fallback '
        'never reaches the user at all', () {
      expect(source, contains(r'($userFacingCode)"'));
      expect(source, contains('_ => null,'));
      expect(source,
          contains('"Couldn\'t sign in — check your connection and try again."'));
    });
  });
}
