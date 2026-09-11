import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/material.dart';

import '../services/account_link_service.dart';
import '../theme/app_colors.dart';
import '../widgets/onboarding_backdrop.dart';
import 'signing_in_screen.dart';

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
  // D-132: every caller needs to know whether AccountLinkService actually
  // linked the current (anonymous) account, or switched into a different,
  // already-existing one via the credential-already-in-use path — those
  // two outcomes call for genuinely different next steps (see setup_screen
  // .dart, homescreen.dart, and welcome_screen.dart's respective onDone).
  final void Function({required bool switchedToExistingAccount}) onDone;
  final String headline;
  final String subhead;
  // Injectable for tests: the real singleton talks to the native Apple/
  // Google SDKs, which can't run in a widget test.
  final AccountLinkService linkService;

  AccountCreationScreen({
    super.key,
    required this.onDone,
    this.headline = 'One last step.',
    this.subhead = "Create your account so your pyramid is never lost — one "
        "tap, nothing to type.",
    AccountLinkService? linkService,
  }) : linkService = linkService ?? AccountLinkService.instance;

  @override
  State<AccountCreationScreen> createState() => _AccountCreationScreenState();
}

class _AccountCreationScreenState extends State<AccountCreationScreen> {
  String? _error;

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  @override
  void initState() {
    super.initState();
    _analytics.logEvent(name: 'account_creation_screen');
  }

  // D-143: the actual sign-in work (native Apple/Google round-trip,
  // Firebase link-or-switch, its own analytics) now lives entirely in
  // SigningInScreen — this just navigates there and reacts to whatever
  // outcome comes back. Found live: a fixed-duration inline message on
  // *this* screen ("Welcome back — signing you in...") was a poor
  // substitute for an honest loading state, since the real work can take
  // more or less than the 2 seconds that text needed to be read for.
  Future<void> _handle(
    Future<User?> Function() signIn,
    String provider,
  ) async {
    setState(() => _error = null);
    final outcome = await Navigator.of(context).push<SignInOutcome>(
      MaterialPageRoute(builder: (_) => SigningInScreen(signIn: signIn, provider: provider)),
    );
    if (!mounted || outcome == null || outcome.cancelled) return;
    if (outcome.errorMessage != null) {
      setState(() => _error = outcome.errorMessage);
      return;
    }
    widget.onDone(switchedToExistingAccount: outcome.switchedAccount);
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Text(widget.headline, style: OnboardingStyles.headline),
                ),
                const SizedBox(height: 14),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 28),
                  child: OnboardingStyles.accentDivider,
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Text(widget.subhead, style: OnboardingStyles.subhead),
                ),
                const Spacer(flex: 4),
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
                      onPressed: () => _handle(widget.linkService.signInWithApple, 'apple'),
                      style: OnboardingStyles.primaryButton,
                      child: const Text('Continue with Apple', style: OnboardingStyles.buttonLabel),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: () => _handle(widget.linkService.signInWithGoogle, 'google'),
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
