import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// D-042/D-028: the Council's two chat screens (setup and category
/// re-clarification) shared one visual complaint found live — "all dark
/// and dreary... no glow" — while the home screen's spinning pyramid,
/// same app, already has warmth: a photograph behind it and a soft green
/// glow (`pyramid_painting.dart`). This gives both chat screens the same
/// family of treatment: `images/jungle_bg.jpg` (already bundled, already
/// the pyramid's own backdrop) full-bleed, a brand-green radial glow
/// echoing the pyramid's, and a dark scrim so message text — the actual
/// job of these screens — stays legible over the photograph rather than
/// competing with it.
class ChatBackdrop extends StatelessWidget {
  final Widget child;
  const ChatBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('images/jungle_bg.jpg', fit: BoxFit.cover),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.4),
              radius: 1.1,
              colors: [
                AppColors.brandGreen.withValues(alpha: 0.14),
                Colors.transparent,
              ],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.background.withValues(alpha: 0.62),
                AppColors.background.withValues(alpha: 0.90),
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }
}
