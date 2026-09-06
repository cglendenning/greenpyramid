import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// D-046/D-066: the confetti burst at setup completion — the single
/// sanctioned exception to the standing no-decoration rule, bounded to
/// exactly one occurrence in the app's lifetime by its caller (the
/// completion screen only ever shows once, D-082's one-setup-session
/// guarantee). A particle animation in the app's own palette — no emoji,
/// no icon, no clip art (D-066).
class ConfettiOverlay extends StatefulWidget {
  final Duration duration;
  const ConfettiOverlay({super.key, this.duration = const Duration(seconds: 3)});

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _Particle {
  final double startX;
  final double fallSpeed;
  final double drift;
  final double rotationSpeed;
  final Color color;
  final double size;
  final double startDelay; // fraction of total duration, 0-1

  _Particle({
    required this.startX,
    required this.fallSpeed,
    required this.drift,
    required this.rotationSpeed,
    required this.color,
    required this.size,
    required this.startDelay,
  });
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Particle> _particles;

  static const _palette = [
    AppColors.brandGreen,
    AppColors.brandPurple,
    AppColors.brandBlue,
    AppColors.brandNavy,
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    final rng = math.Random();
    _particles = List.generate(60, (i) {
      return _Particle(
        startX: rng.nextDouble(),
        fallSpeed: 0.6 + rng.nextDouble() * 0.6,
        drift: (rng.nextDouble() - 0.5) * 0.4,
        rotationSpeed: (rng.nextDouble() - 0.5) * 8,
        color: _palette[rng.nextInt(_palette.length)],
        size: 6 + rng.nextDouble() * 6,
        startDelay: rng.nextDouble() * 0.3,
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _controller.value = 1.0;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(particles: _particles, t: _controller.value),
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double t;
  _ConfettiPainter({required this.particles, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final localT = ((t - p.startDelay) / (1 - p.startDelay)).clamp(0.0, 1.0);
      if (localT <= 0) continue;
      final y = size.height * p.fallSpeed * localT;
      final x = size.width * p.startX + size.width * p.drift * localT;
      final opacity = (1 - localT).clamp(0.0, 1.0);
      if (opacity <= 0 || y > size.height) continue;

      final paint = Paint()..color = p.color.withOpacity(opacity);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotationSpeed * localT * math.pi);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => oldDelegate.t != t;
}
