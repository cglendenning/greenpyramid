import 'package:flutter/material.dart';
import '../services/notification.dart';
import '../services/push_messaging_service.dart';
import '../theme/app_colors.dart';
import '../widgets/onboarding_backdrop.dart';

/// D-065: triggers the OS push-notification permission dialog. One screen,
/// one action — no skip path, no second button.
///
/// D-099: shares [OnboardingBackdrop]/[OnboardingStyles] with WelcomeScreen.
/// Copy rewritten so the screen's actual function — requesting permission
/// to send push notifications — is unambiguous, rather than reading as a
/// generic "the Council reaches you" statement with no visible connection
/// to a permission prompt.
class PushPermissionScreen extends StatelessWidget {
  final VoidCallback onDone;
  const PushPermissionScreen({super.key, required this.onDone});

  Future<void> _requestAndContinue(BuildContext context) async {
    try {
      await LocalNotificationService().requestPermissions();
      await PushMessagingService.instance.syncNotificationState();
    } catch (_) {
      // D-038: a failure here degrades nothing — proceed regardless.
    }
    onDone();
  }

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
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 28),
                child: Text(
                  'Allow notifications from the Council of Advisors.',
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
                  'iOS will ask for permission to send push notifications. '
                  'Say yes, and the Council of Advisors reaches you between '
                  'visits — a word at the right moment, not a schedule of '
                  'pings.',
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
                    onPressed: () => _requestAndContinue(context),
                    style: OnboardingStyles.primaryButton,
                    child: const Text('Allow notifications', style: OnboardingStyles.buttonLabel),
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
