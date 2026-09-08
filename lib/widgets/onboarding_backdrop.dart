import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'crossfading_stock_images.dart';

/// D-099: the shared full-bleed rotating-photograph background used by
/// every onboarding-adjacent screen — welcome (D-089), trial disclosure
/// (D-014), push permission (D-065), and any future screen in the same
/// family. Extracted from [WelcomeScreen] so the visual treatment the
/// owner singled out as exactly right ("I love the font. I love the
/// layout. I love the imagery. It's perfect") doesn't drift screen to
/// screen through independent reimplementation, the same reasoning
/// [ChatBackdrop] already applies to the Council conversation screens.
class OnboardingBackdrop extends StatelessWidget {
  final Widget child;
  const OnboardingBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
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
        child,
      ],
    );
  }
}

/// D-099: the shared typography and button styling for onboarding-family
/// screens — one Raleway type scale (headline / accent divider / subhead
/// / button label) instead of each screen inlining its own copy of the
/// same styles.
class OnboardingStyles {
  static const headline = TextStyle(
    fontFamily: 'Raleway',
    fontSize: 32,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.15,
    letterSpacing: -0.3,
  );

  static const subhead = TextStyle(
    fontFamily: 'Raleway',
    fontStyle: FontStyle.italic,
    fontSize: 16,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  static const buttonLabel = TextStyle(
    fontFamily: 'Raleway',
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.6,
  );

  static final ButtonStyle primaryButton = ElevatedButton.styleFrom(
    backgroundColor: AppColors.brandGreen,
    foregroundColor: AppColors.background,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    elevation: 0,
  );

  /// The thin accent rule between a headline and its subhead.
  static const accentDivider = SizedBox(
    width: 36,
    child: Divider(color: AppColors.brandGreen, thickness: 1, height: 1),
  );
}
