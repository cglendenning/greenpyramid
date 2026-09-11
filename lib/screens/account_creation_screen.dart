import 'dart:async' show unawaited;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../services/account_link_service.dart';
import '../theme/app_colors.dart';
import '../widgets/onboarding_backdrop.dart';

/// D-130 (supersedes D-033/Q-28): a real account is now required here,
/// right before [SetupCompletionScreen] — the one moment goal-executor
/// itself gates on sign-in, mirrored deliberately rather than reused
/// verbatim (goal-executor's own screen also offers email/password; this
/// one is Apple + Google one-tap only, since a typed form is exactly the
/// friction this screen exists to avoid).
///
/// [PopScope(canPop: false)] — same mechanism D-128 already uses — removes
/// the back gesture/button entirely. By the time this screen shows,
/// `_confirmHabitsAndClose` has already committed habits and ended the
/// Council session (setup_screen.dart), so there is nothing coherent left
/// to go back to.
class AccountCreationScreen extends StatefulWidget {
  final VoidCallback onDone;
  // Injectable for tests: the real singleton talks to the native Apple/
  // Google SDKs, which can't run in a widget test.
  final AccountLinkService linkService;

  AccountCreationScreen({super.key, required this.onDone, AccountLinkService? linkService})
      : linkService = linkService ?? AccountLinkService.instance;

  @override
  State<AccountCreationScreen> createState() => _AccountCreationScreenState();
}

class _AccountCreationScreenState extends State<AccountCreationScreen> {
  bool _submitting = false;
  String? _error;
  String? _welcomeBackMessage;

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  @override
  void initState() {
    super.initState();
    _analytics.logEvent(name: 'account_creation_screen');
  }

  Future<void> _handle(
    Future<User?> Function() signIn,
    String provider,
  ) async {
    setState(() {
      _submitting = true;
      _error = null;
      _welcomeBackMessage = null;
    });
    try {
      final uidBefore = FirebaseAuth.instance.currentUser?.uid;
      final user = await signIn();
      final switchedAccount = user != null && user.uid != uidBefore;
      unawaited(_analytics.logEvent(
        name: 'account_created',
        parameters: {'provider': provider, 'switched_existing_account': switchedAccount},
      ));
      if (!mounted) return;
      if (switchedAccount) {
        // D-130: credential-already-in-use — AccountLinkService already
        // signed the user into their real existing account instead of
        // linking. Same "welcome back" treatment D-096 gives a reinstall.
        setState(() {
          _submitting = false;
          _welcomeBackMessage = 'Welcome back — signing you into your existing Green Pyramid.';
        });
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
      } else {
        setState(() => _submitting = false);
      }
      widget.onDone();
    } catch (error) {
      if (kDebugMode) {
        print('AccountCreationScreen: $provider sign-in failed: $error');
      }
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = "Couldn't sign in — check your connection and try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: OnboardingBackdrop(
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(flex: 5),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 28),
                  child: Text('One last step.', style: OnboardingStyles.headline),
                ),
                const SizedBox(height: 14),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 28),
                  child: OnboardingStyles.accentDivider,
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 28),
                  child: Text(
                    "Create your account so your pyramid is never lost — one tap, "
                    "nothing to type.",
                    style: OnboardingStyles.subhead,
                  ),
                ),
                const Spacer(flex: 4),
                if (_welcomeBackMessage != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
                    child: Text(
                      _welcomeBackMessage!,
                      style: OnboardingStyles.subhead.copyWith(color: AppColors.brandGreen),
                    ),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
                    child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _submitting
                          ? null
                          : () => _handle(widget.linkService.signInWithApple, 'apple'),
                      style: OnboardingStyles.primaryButton,
                      child: _submitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.background),
                            )
                          : const Text('Continue with Apple', style: OnboardingStyles.buttonLabel),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: _submitting
                          ? null
                          : () => _handle(widget.linkService.signInWithGoogle, 'google'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.textSecondary),
                        foregroundColor: AppColors.textPrimary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Continue with Google', style: OnboardingStyles.buttonLabel),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
