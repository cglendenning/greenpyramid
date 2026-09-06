import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// D-044: the small corner indicator that answers "how much longer" during
/// the open-ended setup conversation, without a progress bar. Pulses
/// gently; fills bottom-to-top with a green glow as [progress] (0.0-1.0)
/// rises, mirroring the pyramid's own tier order. Fill tracks setup
/// completion, never message count — the caller decides what [progress]
/// means.
class SetupProgressIndicator extends StatefulWidget {
  final double progress;
  final double size;

  const SetupProgressIndicator({
    super.key,
    required this.progress,
    this.size = 48,
  });

  @override
  State<SetupProgressIndicator> createState() => _SetupProgressIndicatorState();
}

class _SetupProgressIndicatorState extends State<SetupProgressIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion == _reduceMotion) return;
    _reduceMotion = reduceMotion;
    if (_reduceMotion) {
      _pulse.stop();
      _pulse.value = 0;
    } else {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion) {
      return _paint(1.0);
    }
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) => _paint(0.92 + (_pulse.value * 0.08)),
    );
  }

  Widget _paint(double scale) {
    return Transform.scale(
      scale: scale,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _PyramidFillPainter(progress: widget.progress.clamp(0.0, 1.0)),
        ),
      ),
    );
  }
}

class _PyramidFillPainter extends CustomPainter {
  final double progress;
  const _PyramidFillPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final outline = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      outline,
      Paint()
        ..color = AppColors.surfaceHigh
        ..style = PaintingStyle.fill,
    );

    // Bottom-to-top fill, clipped to the triangular silhouette so the
    // filled region is always pyramid-shaped, not a rectangle peeking out.
    canvas.save();
    canvas.clipPath(outline);
    final fillHeight = size.height * progress;
    final fillRect = Rect.fromLTWH(
      0,
      size.height - fillHeight,
      size.width,
      fillHeight,
    );
    canvas.drawRect(
      fillRect,
      Paint()
        ..color = AppColors.brandGreen
        ..style = PaintingStyle.fill,
    );
    canvas.restore();

    canvas.drawPath(
      outline,
      Paint()
        ..color = AppColors.textSecondary.withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _PyramidFillPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
