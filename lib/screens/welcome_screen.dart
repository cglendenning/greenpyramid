import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/crossfading_stock_images.dart';
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
/// D-090: the background is now [CrossfadingStockImages], ported from
/// Kansei rather than the single static `welcome_candle.jpg` this screen
/// used before — the same slow rotation Kansei uses on its own setup-analog
/// screen (`igniter_screen.dart`).
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const CrossfadingStockImages(),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.background.withValues(alpha: 0.35),
                  AppColors.background.withValues(alpha: 0.55),
                  AppColors.background.withValues(alpha: 0.92),
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(flex: 5),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 28),
                  child: Text(
                    'Say what matters. We’ll build your life around it.',
                    style: TextStyle(
                      fontFamily: 'Raleway',
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      height: 1.15,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: SizedBox(
                    width: 36,
                    child: Divider(
                        color: AppColors.brandGreen, thickness: 1, height: 1),
                  ),
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 28),
                  child: Text(
                    'A short conversation, and your pyramid of values will '
                    'take shape.',
                    style: TextStyle(
                      fontFamily: 'Raleway',
                      fontStyle: FontStyle.italic,
                      fontSize: 16,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
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
                          MaterialPageRoute(
                              builder: (_) => const SetupScreen())),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandGreen,
                        foregroundColor: AppColors.background,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('Begin',
                          style: TextStyle(
                              fontFamily: 'Raleway',
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.6)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
