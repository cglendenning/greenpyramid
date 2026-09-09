import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/onboarding_backdrop.dart';

/// D-014: discloses trial terms before the Council becomes billable.
///
/// D-099: shares [OnboardingBackdrop]/[OnboardingStyles] with WelcomeScreen
/// so this screen carries the same rotating-photograph, Raleway-typeset
/// identity rather than its own plain background.
class TrialDisclosureScreen extends StatelessWidget {
  final VoidCallback onDone;
  final String? entitlement;
  const TrialDisclosureScreen({super.key, required this.onDone, this.entitlement});

  bool get _lapsed => entitlement == 'lapsed';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: OnboardingBackdrop(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 5),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Text(
                  _lapsed ? 'Your pyramid is ready.' : 'You have 3 days of full access.',
                  style: OnboardingStyles.headline,
                ),
              ),
              const SizedBox(height: 14),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 28),
                child: OnboardingStyles.accentDivider,
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Text(
                  _lapsed
                      ? 'Your pyramid, habits, and history are yours to track for free, forever. The Council of Advisors — tailored notifications and everything the advisors help you clarify — requires a subscription.'
                      : 'The Council of Advisors, tailored notifications, and everything the advisors help you clarify are open for the next three days. After that, your pyramid, habits, and history stay yours to track for free, forever — but the Council of Advisors goes quiet until you subscribe.',
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
                    onPressed: onDone,
                    style: OnboardingStyles.primaryButton,
                    child: const Text('Got it', style: OnboardingStyles.buttonLabel),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
