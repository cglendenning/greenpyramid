import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/local_pyramid_reset_service.dart';
import '../services/sync_service.dart';
import '../theme/app_colors.dart';
import '../widgets/onboarding_backdrop.dart';
import 'account_creation_screen.dart';
import 'setup_screen.dart';

/// D-089: a single screen, shown once per entry into setup, that tells the
/// user what is about to happen before Mira's opening line (D-042) puts
/// them straight into a conversation with no warning. Deliberately NOT a
/// second version of the old eighteen-screen wizard (D-001) or a feature
/// carousel D-042 already forbids — one rotating photograph, one line of
/// intent, one line of what to expect, one action. Owns no service
/// dependency, so it is genuinely widget-testable, unlike SetupScreen (see
/// setup_screen_opening_line_test.dart's own comment on why that screen
/// isn't).
///
/// D-090: the background is now [OnboardingBackdrop]'s rotating photograph
/// (ported from Kansei), rather than the single static
/// `welcome_candle.jpg` this screen used before — the same slow rotation
/// Kansei uses on its own setup-analog screen (`igniter_screen.dart`).
///
/// D-099: the background, typography, and button styling live in
/// [OnboardingBackdrop]/[OnboardingStyles] — this screen originated the
/// look, but no longer owns a private copy of it, so `TrialDisclosureScreen`
/// and `PushPermissionScreen` render with the exact same visual identity.
///
/// D-111: a back affordance, shown only when there's somewhere to go back
/// to (`Navigator.canPop`) — true for the Settings-menu re-entry point
/// (pushed on top of the home screen), false for a fresh install's
/// `/setup` route (this is the very first screen; there is nothing before
/// it to return to). Nothing has been created or committed at this point
/// in either case, so backing out here is always safe.
///
/// D-132: "Already have an account? Sign in" — mirrors goal-executor's
/// own first-screen pattern (its splash screen routes an onboarded-but-
/// signed-out user to its auth screen, which itself toggles between sign-
/// in and create-account). [showStartFreshOption] is true only when this
/// screen is reached via Settings' sign-out flow (see settings.dart) —
/// on a genuine fresh install there is no local pyramid to "start fresh"
/// from, and "Begin" already does exactly that.
class WelcomeScreen extends StatelessWidget {
  final bool showStartFreshOption;
  const WelcomeScreen({super.key, this.showStartFreshOption = false});

  Future<void> _signIn(BuildContext context) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AccountCreationScreen(
        headline: 'Welcome back.',
        subhead: 'Sign in with the account you set up before.',
        onDone: ({required switchedToExistingAccount}) async {
          if (switchedToExistingAccount) {
            final uid = FirebaseAuth.instance.currentUser?.uid;
            if (uid != null) {
              await SyncService.instance.restoreFromCloud(uid);
            }
            if (!context.mounted) return;
            Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
            return;
          }
          if (!showStartFreshOption) {
            // A genuine fresh install: this identity had no prior
            // account, but local storage was already empty — nothing to
            // lose by just continuing into setup as a newly-linked user.
            if (!context.mounted) return;
            Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const SetupScreen()));
            return;
          }
          // Reached via sign-out: this device's local pyramid still
          // belongs to the account just signed out of. Never silently
          // touch it on an unexpected "no prior account" outcome — surface
          // it and let the user make an explicit choice ("Start fresh"
          // below) instead.
          if (!context.mounted) return;
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'No existing pyramid found for that sign-in. Use "Start fresh" '
                'below to set up a new one instead.'),
          ));
        },
      ),
    ));
  }

  Future<void> _confirmAndStartFresh(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        title: const Text('Start fresh?', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          "Starting fresh will permanently delete this device's current "
          "pyramid, habits, and history. This can't be undone unless you "
          "sign back into your account.",
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Start fresh'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await LocalPyramidResetService.instance.wipeLocalPyramid();
    if (!context.mounted) return;
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => const SetupScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final canGoBack = Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: OnboardingBackdrop(
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(flex: 5),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 28),
                    child: Text(
                      'Say what matters. We’ll build your life around it.',
                      style: OnboardingStyles.headline,
                    ),
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
                      'A short conversation, and your pyramid of values will '
                      'take shape.',
                      style: OnboardingStyles.subhead,
                    ),
                  ),
                  const Spacer(flex: 4),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => const SetupScreen())),
                        style: OnboardingStyles.primaryButton,
                        child: const Text('Begin', style: OnboardingStyles.buttonLabel),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        onPressed: () => _signIn(context),
                        child: const Text(
                          'Already have an account? Sign in',
                          style: TextStyle(color: AppColors.textPrimary),
                        ),
                      ),
                    ),
                  ),
                  if (showStartFreshOption)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                          onPressed: () => _confirmAndStartFresh(context),
                          child: const Text(
                            'Start fresh instead',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 16),
                ],
              ),
              if (canGoBack)
                Positioned(
                  top: 4,
                  left: 4,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
