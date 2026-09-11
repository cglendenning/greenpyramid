import 'dart:async' show unawaited;
import 'dart:ui';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../theme/app_colors.dart';

/// D-143: the actual outcome of a sign-in attempt, handed back to
/// [AccountCreationScreen] via [Navigator.pop] once [SigningInScreen]
/// finishes. Exactly one of [errorMessage] is set, or neither — a plain
/// success (`errorMessage == null`) still needs [switchedAccount] to pick
/// the right next step (D-132), and a cancellation is a silent no-op, not
/// an error.
class SignInOutcome {
  const SignInOutcome.success({required this.switchedAccount})
      : errorMessage = null,
        cancelled = false;
  const SignInOutcome.failure(this.errorMessage)
      : switchedAccount = false,
        cancelled = false;
  const SignInOutcome.cancelled()
      : switchedAccount = false,
        errorMessage = null,
        cancelled = true;

  final bool switchedAccount;
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
/// [AccountCreationScreen] — this screen instead covers the *actual*
/// in-flight duration of [signIn], however long it really takes, then
/// pops with a [SignInOutcome] for the caller to act on. `canPop: false`
/// (same mechanism D-128/D-130 already use) — nothing coherent to go
/// back to mid-sign-in.
class SigningInScreen extends StatefulWidget {
  const SigningInScreen({super.key, required this.signIn, required this.provider});

  final Future<User?> Function() signIn;
  final String provider;

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
      Navigator.of(context).pop(SignInOutcome.success(switchedAccount: switchedAccount));
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
