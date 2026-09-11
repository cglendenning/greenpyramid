import 'dart:math';

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
/// D-136 (supersedes D-132/D-133/D-135's flag-based approach): this
/// screen is now a pure function of nothing at all — it looks and behaves
/// identically every single time, whether reached by a genuine fresh
/// install or by signing out. No persisted flag, no "resetup mode," no
/// per-visit local-data check. Found live, after a real bug where a
/// persisted flag's lifetime was wrong (it survived exactly one relaunch,
/// not "however many launches until the user decides"): "Don't ever do
/// that — when you're logged out you're in the logged out state, PERIOD."
/// This screen is *only* ever reached while signed out (anonymous or no
/// session at all) — there is no other entry point anymore. Tapping
/// "Begin" always silently resets local storage first (harmless even
/// when it's already empty) and starts a fresh setup conversation; no
/// confirmation, because nothing of value can be destroyed by a signed-
/// out user starting over — their real data, if any, lives under
/// whichever real account they'd need to sign back into to see it again.
/// The *separate*, genuinely destructive case — an already signed-in
/// user explicitly choosing to rebuild their existing, cloud-synced
/// pyramid — never touches this screen at all; see
/// `CustomAppBarState.navigateToSetup` (`homescreen.dart`) for that
/// flow's own explicit confirmation.
/// D-141: shown as [AccountCreationScreen]'s subhead on the "Welcome
/// back." sign-in screen — owner: "'Sign up with the account you set up
/// before' is not a phrase that I like. I want a phrase to be inspiring
/// ... short and inspiring and related to living a life aligned with
/// values that truly matter." One is chosen at random each time the
/// screen is shown, rather than a single fixed line, so it stays fresh
/// across repeat sign-ins.
const List<String> welcomeBackTaglines = [
  'Your pyramid is exactly where you left it.',
  "What matters to you hasn't gone anywhere.",
  "Come back to the life you're building.",
  'The values you chose are still here, waiting.',
  'Pick up where you left off — nothing was lost.',
  'A life built on what matters is worth returning to.',
  'Some things are worth signing back in for.',
  'The foundation you laid is still standing.',
  'Return to the life you started shaping.',
  'What you value deserves to keep growing.',
  "You already began. Let's keep building.",
  'Your life, aligned — right where you left it.',
  'Living with intention starts with showing up again.',
  "The thread is still there. Pick it back up.",
  'Your values were never going anywhere.',
  'Come home to what matters most.',
  'What you started still matters.',
  'Everything you value is right where you left it.',
  'Nothing here was lost while you were away.',
  "The life you're shaping is still waiting.",
];

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  Future<void> _signIn(BuildContext context) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AccountCreationScreen(
        headline: 'Welcome back.',
        subhead: welcomeBackTaglines[Random().nextInt(welcomeBackTaglines.length)],
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
          // No prior account for that identity — it just linked onto the
          // current (signed-out-until-now) session. Nothing to lose:
          // reset local storage the same way "Begin" does, then proceed
          // into setup as this newly-linked user.
          await LocalPyramidResetService.instance.wipeLocalPyramid();
          if (!context.mounted) return;
          Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const SetupScreen()));
        },
      ),
    ));
  }

  Future<void> _begin(BuildContext context) async {
    // Idempotent — harmless when local storage is already empty (a
    // genuine fresh install). No confirmation: a signed-out user has
    // nothing here that isn't already recoverable by signing back in.
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
                        onPressed: () => _begin(context),
                        style: OnboardingStyles.primaryButton,
                        child: const Text('Begin', style: OnboardingStyles.buttonLabel),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
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
