import 'dart:async' show unawaited;
import 'dart:ui';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../theme/app_colors.dart';

/// D-143/D-162: the outcome of a sign-in attempt that failed or was
/// cancelled, handed back to [AccountCreationScreen] via [Navigator.pop]
/// so it can show an error or simply do nothing. A successful sign-in no
/// longer produces one of these — see [SigningInScreen]'s own doc comment
/// for why.
class SignInOutcome {
  const SignInOutcome.failure(this.errorMessage) : cancelled = false;
  const SignInOutcome.cancelled()
      : errorMessage = null,
        cancelled = true;

  final String? errorMessage;
  final bool cancelled;
}

/// D-143: owner — "as it's signing you in, rather than dropping you back
/// to the sign in screen with text on the screen indicating that it is
/// signing you in, it should go to a new screen with a small slow
/// spinning, glowing green pyramid and just says signing in… And then it
/// drops into the main page with the pyramid once sign in succeeds, or
/// drops you back to the sign in page if sign in fails." Replaces the
/// inline green "Welcome back — signing you in..." text + a fixed
/// 2-second `Future.delayed` that used to live directly on
/// [AccountCreationScreen].
///
/// D-162: on success this screen now calls [onDone] directly instead of
/// popping back to [AccountCreationScreen] and leaving that screen's own
/// caller to navigate onward. Found live — owner: "when I click sign in
/// with Apple it presents me with my account and I click sign in and the
/// black screen comes up with the glowing pyramid logo, which is great,
/// but then after signing succeed, it quickly flips back to the signing
/// page and then to the main pyramid screen." Root cause: popping back to
/// AccountCreationScreen genuinely re-revealed it — including its own
/// visible reveal transition — for the *entire* duration of whatever
/// async work the caller's `onDone` still had left to do (for a switched
/// account, a real Firestore round trip via `SyncService.restoreFromCloud`),
/// before that caller's own navigation call finally left it. Calling
/// `onDone` from here instead means this screen's own glowing-pyramid
/// loading state now honestly covers that entire remaining duration too,
/// not just the initial auth handshake — matching what this screen's own
/// doc comment already promised ("however long it really takes") — and
/// the final navigation is a single transition straight from this screen
/// to the real destination. On failure or cancellation, popping back to
/// AccountCreationScreen is still correct (and desired) — the user needs
/// to see the error or simply try again from there.
class SigningInScreen extends StatefulWidget {
  const SigningInScreen({
    super.key,
    required this.signIn,
    required this.provider,
    required this.onDone,
  });

  final Future<User?> Function() signIn;
  final String provider;
  final void Function({required bool switchedToExistingAccount}) onDone;

  @override
  State<SigningInScreen> createState() => _SigningInScreenState();
}

class _SigningInScreenState extends State<SigningInScreen> {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  @override
  void initState() {
    super.initState();
    _analytics.logEvent(name: 'signing_in_screen', parameters: {'provider': widget.provider});
    _run();
  }

  Future<void> _run() async {
    try {
      final uidBefore = FirebaseAuth.instance.currentUser?.uid;
      final user = await widget.signIn();
      final switchedAccount = user != null && user.uid != uidBefore;
      unawaited(_analytics.logEvent(
        name: 'account_created',
        parameters: {'provider': widget.provider, 'switched_existing_account': switchedAccount},
      ));
      if (!mounted) return;
      widget.onDone(switchedToExistingAccount: switchedAccount);
    } catch (error) {
      if (kDebugMode) {
        print('SigningInScreen: ${widget.provider} sign-in failed: $error');
      }
      if (!mounted) return;
      if (error is SignInWithAppleAuthorizationException &&
          error.code == AuthorizationErrorCode.canceled) {
        // The user dismissed Apple's own sheet — not a failure (D-139).
        Navigator.of(context).pop(const SignInOutcome.cancelled());
        return;
      }
      final errorCode = switch (error) {
        FirebaseAuthException e => e.code,
        SignInWithAppleAuthorizationException e => 'apple.${e.code.name}',
        SignInWithAppleException _ => 'apple.${error.runtimeType}',
        _ => error.runtimeType.toString(),
      };
      unawaited(_analytics.logEvent(
        name: 'account_creation_failed',
        parameters: {'provider': widget.provider, 'error_code': errorCode},
      ));
      Navigator.of(context).pop(SignInOutcome.failure(
          "Couldn't sign in — check your connection and try again. ($errorCode)"));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _GlowingPyramidIcon(),
              const SizedBox(height: 28),
              Text(
                'Signing in…',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontFamily: 'Exo2',
                  fontSize: 18,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small, slowly and continuously rotating brand pyramid with a soft
/// green glow — a blurred, tinted copy of the same vector mark sits
/// behind the crisp one, both spinning together.
class _GlowingPyramidIcon extends StatefulWidget {
  const _GlowingPyramidIcon();

  final double size = 84;

  @override
  State<_GlowingPyramidIcon> createState() => _GlowingPyramidIconState();
}

class _GlowingPyramidIconState extends State<_GlowingPyramidIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 10))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const asset = 'images/svg/logo_green.svg';
    return RotationTransition(
      turns: _controller,
      child: SizedBox(
        width: widget.size * 1.6,
        height: widget.size * 1.6,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: widget.size * 0.16,
                sigmaY: widget.size * 0.16,
              ),
              child: SvgPicture.asset(
                asset,
                width: widget.size * 1.2,
                height: widget.size * 1.2,
                colorFilter: const ColorFilter.mode(AppColors.brandGreen, BlendMode.srcIn),
              ),
            ),
            SvgPicture.asset(asset, width: widget.size, height: widget.size),
          ],
        ),
      ),
    );
  }
}
