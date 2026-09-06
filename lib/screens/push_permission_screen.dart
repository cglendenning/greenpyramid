import 'package:flutter/material.dart';

import '../services/notification.dart';
import '../services/push_messaging_service.dart';
import '../theme/app_colors.dart';

/// D-065: push permission is requested exactly once, immediately after
/// D-046's completion moment settles — never on first launch (D-038). One
/// screen, one action, framed as how the Council reaches the user. The OS
/// dialog itself is the accept/decline choice; denial degrades nothing and
/// this screen is never shown again after this call.
class PushPermissionScreen extends StatelessWidget {
  final VoidCallback onDone;
  const PushPermissionScreen({super.key, required this.onDone});

  Future<void> _requestAndContinue(BuildContext context) async {
    try {
      await LocalNotificationService().requestPermissions();
      // D-036/D-038: registers the FCM token if granted, or schedules the
      // local fallback if not — either way, degrades nothing on failure.
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'The Council reaches you between visits — a word at the '
                'right moment, not a schedule of pings.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 18),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => _requestAndContinue(context),
                child: const Text('Let them reach you'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
