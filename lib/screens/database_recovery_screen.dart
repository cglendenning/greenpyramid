import 'package:flutter/material.dart';
import 'package:life_ops/theme/app_colors.dart';

/// Shown when the local database cannot be opened or migrated (D-086).
///
/// Migration is best-effort. When it fails, the user is told plainly what
/// happened and what to do — never a crash, never a silent wipe, and never a
/// promise that the data can be recovered when it cannot.
class DatabaseRecoveryScreen extends StatelessWidget {
  const DatabaseRecoveryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Green Pyramid needs a fresh start',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'This version of the app changed how your information is '
                    'stored, and the data already on this device could not be '
                    'carried over.',
                    style: TextStyle(fontSize: 16, height: 1.45),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'To continue, delete Green Pyramid from your device and '
                    'install it again. Your previous habits and history cannot '
                    'be recovered.',
                    style: TextStyle(fontSize: 16, height: 1.45),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Setting up again takes a few minutes, and the app you '
                    'come back to is a considerably better one.',
                    style: TextStyle(fontSize: 16, height: 1.45),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
