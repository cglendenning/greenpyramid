import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'setup_screen.dart';

/// D-089: a single screen, shown once per entry into setup, that tells the
/// user what is about to happen before Mira's opening line (D-042) puts
/// them straight into a conversation with no warning. Deliberately NOT a
/// second version of the old eighteen-screen wizard (D-001) or a feature
/// carousel D-042 already forbids — one photograph, one line of intent,
/// one line of what to expect, one action. Owns no service dependency, so
/// it is genuinely widget-testable, unlike SetupScreen (see
/// setup_screen_opening_line_test.dart's own comment on why that screen
/// isn't).
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: height * 0.6,
            child: Image.asset('images/welcome_candle.jpg', fit: BoxFit.cover),
          ),
          Positioned(
            top: height * 0.32,
            left: 0,
            right: 0,
            height: height * 0.32,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.background.withValues(alpha: 0),
                    AppColors.background.withValues(alpha: 0.75),
                    AppColors.background,
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: height * 0.42),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 28),
                    child: Text(
                      'Say what matters.\nWe’ll build around it.',
                      style: TextStyle(
                        fontFamily: 'Raleway',
                        fontSize: 34,
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
                      child: Divider(color: AppColors.brandGreen, thickness: 1, height: 1),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 28),
                    child: Text(
                      'A short conversation with the Council, then your '
                      'pyramid takes shape.',
                      style: TextStyle(
                        fontFamily: 'Raleway',
                        fontStyle: FontStyle.italic,
                        fontSize: 16,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => const SetupScreen())),
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
          ),
        ],
      ),
    );
  }
}
