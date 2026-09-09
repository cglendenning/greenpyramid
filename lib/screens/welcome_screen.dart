import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/onboarding_backdrop.dart';
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
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

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
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
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
