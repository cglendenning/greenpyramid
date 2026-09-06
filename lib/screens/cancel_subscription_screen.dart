import 'dart:io';

import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../theme/app_colors.dart';

/// D-070: cancellation itself always happens in the platform's own
/// subscription-management UI (Apple/Google require this) — this screen's
/// only job is retention framing and pointing the user there, mirroring
/// Kansei's cancel_subscription_screen.dart adapted to Green Pyramid's copy.
class CancelSubscriptionScreen extends StatelessWidget {
  const CancelSubscriptionScreen({super.key});

  void _showCancelInstructions(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('How to cancel', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          Platform.isIOS
              ? 'Open the Settings app.\n\n'
                  'Tap your name at the top, then tap Subscriptions.\n\n'
                  'Find Green Pyramid and tap Cancel Subscription.\n\n'
                  'You will keep full access until the end of your current billing period.'
              : 'Open the Play Store app.\n\n'
                  'Tap your profile icon, then Payments & subscriptions > Subscriptions.\n\n'
                  'Find Green Pyramid and tap Cancel.\n\n'
                  'You will keep full access until the end of your current billing period.',
          style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<bool> _hasActiveSubscription() async {
    try {
      final info = await Purchases.getCustomerInfo();
      return info.activeSubscriptions.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Your subscription'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Before you go.',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 26, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              const Text(
                'Cancelling ends your subscription at the close of your '
                'current billing period. Your pyramid, habits, essences, '
                'and history remain intact — only the Council stops.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 15, height: 1.5),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Keep my subscription'),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () async {
                    final hasActive = await _hasActiveSubscription();
                    if (!context.mounted) return;
                    if (!hasActive) {
                      Navigator.pop(context);
                      return;
                    }
                    _showCancelInstructions(context);
                  },
                  child: const Text('Show me how to cancel', style: TextStyle(color: AppColors.textSecondary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
