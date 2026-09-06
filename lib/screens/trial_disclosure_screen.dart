import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// D-014: free users are told plainly, once, what the free tier actually
/// is — setup is a one-time experience, and without a subscription their
/// values clarification never advances. Shown exactly once, immediately
/// after the trial is granted (D-058's pyramid-reveal moment), never
/// repeated on a schedule.
class TrialDisclosureScreen extends StatelessWidget {
  final VoidCallback onDone;
  // The entitlement resolved right after setup completion (D-058). When a
  // device has already consumed its trial (D-059's reinstall case), the
  // account lands in 'lapsed' instead of 'trialing' — this screen must not
  // promise three days that were never actually granted.
  final String? entitlement;
  const TrialDisclosureScreen({super.key, required this.onDone, this.entitlement});

  bool get _lapsed => entitlement == 'lapsed';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _lapsed ? 'Your pyramid is ready.' : 'You have 3 days of full access.',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _lapsed
                    ? 'Your pyramid, habits, and history are yours to track '
                        'for free, forever. The Council — tailored '
                        'notifications and everything the advisors help you '
                        'clarify — requires a subscription.'
                    : 'The Council, tailored notifications, and everything '
                        'the advisors help you clarify are open for the '
                        'next three days. After that, your pyramid, '
                        'habits, and history stay yours to track for free, '
                        'forever — but the Council goes quiet until you '
                        'subscribe.',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onDone,
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
