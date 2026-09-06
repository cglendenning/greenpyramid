import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Shared canvas-painting helpers for the home-screen pyramid's six
// CustomPainter segments (DrawCat1..DrawCat6 in pyramid.dart), so the
// glow/panel/label technique lives in one place instead of being
// copy-pasted six times.
class PyramidPainting {
  PyramidPainting._();

  static const String fontFamily = 'Exo2';

  static const Color _stoneLight = Color(0xFF9297A0);
  static const Color _stoneMid = Color(0xFF5C5F68);
  static const Color _stoneDark = Color(0xFF303239);

  // Photographic grey-masonry texture (images/stone_texture.jpg). Until it
  // finishes decoding, segments fall back to the procedural stone gradient.
  static ui.Image? stoneImage;
  static Future<void>? _stoneLoad;

  static Future<void> ensureStoneLoaded() {
    return _stoneLoad ??= _loadStone();
  }

  static Future<void> _loadStone() async {
    try {
      final data = await rootBundle.load('images/stone_texture.jpg');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      stoneImage = (await codec.getNextFrame()).image;
    } catch (e) {
      debugPrint('Failed to load pyramid stone texture: $e');
      _stoneLoad = null; // allow a later retry instead of caching the failure
    }
  }

  // Ancient-stone-block-meets-HUD treatment for a lit (non-muted) segment:
  // the segment reads as one monolithic carved stone block (the
  // photographic dark-granite slab texture fitted to the segment's own
  // bounds, a procedural gradient until it loads, plus an inset shadow
  // bevel), then a saturated colored bloom, a translucent status-color
  // wash, fine scanlines, and a crisp neon edge are layered on top — like
  // circuitry glowing on carved rock. [pulse] is a 0.0-1.0 breathing value
  // reserved for a subtle intensity animation.
  static void paintGlowingSegment(
    Canvas canvas,
    Path path,
    Color baseColor, {
    double pulse = 0.5,
  }) {
    final bounds = path.getBounds();
    final hsl = HSLColor.fromColor(baseColor);
    final neon = hsl.withSaturation(1.0).withLightness(0.62).toColor();
    final pulseBoost = 0.85 + (pulse * 0.3); // 0.85..1.15

    for (final stop in const [
      (sigma: 36.0, alpha: 0.22),
      (sigma: 22.0, alpha: 0.30),
      (sigma: 11.0, alpha: 0.40),
    ]) {
      final glowPaint = Paint()
        ..color = neon.withOpacity((stop.alpha * pulseBoost).clamp(0.0, 1.0))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, stop.sigma);
      canvas.drawPath(path, glowPaint);
    }

    canvas.save();
    canvas.clipPath(path);

    final stone = stoneImage;
    if (stone != null) {
      // Fit the slab to this segment's own bounds so every segment reads
      // as one individual stone block rather than sharing wall coursing.
      final scale = math.max(
          bounds.width / stone.width, bounds.height / stone.height);
      final shaderMatrix = Matrix4.identity()
        ..translateByDouble(bounds.left, bounds.top, 0, 1)
        ..scaleByDouble(scale, scale, 1, 1);
      canvas.drawRect(
        bounds,
        Paint()
          ..shader = ui.ImageShader(stone, TileMode.mirror, TileMode.mirror,
              shaderMatrix.storage),
      );
    } else {
      final stoneFill = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_stoneLight, _stoneMid, _stoneDark],
        ).createShader(bounds);
      canvas.drawRect(bounds, stoneFill);

      // Deterministic mottling so the fallback doesn't "swim" on repaint.
      final rand = math.Random(baseColor.value);
      final speckDark = Paint()..color = Colors.black.withOpacity(0.10);
      final speckLight = Paint()..color = Colors.white.withOpacity(0.05);
      for (int i = 0; i < 16; i++) {
        final center = Offset(
          bounds.left + rand.nextDouble() * bounds.width,
          bounds.top + rand.nextDouble() * bounds.height,
        );
        final radius = 3 + rand.nextDouble() * 9;
        canvas.drawCircle(
            center, radius, rand.nextBool() ? speckDark : speckLight);
      }
    }

    final highlight =
        hsl.withLightness((hsl.lightness + 0.24).clamp(0.0, 1.0)).toColor();
    final shadow =
        hsl.withLightness((hsl.lightness - 0.30).clamp(0.0, 1.0)).toColor();
    // Strong status-color glow over the dark grey granite: the wash is the
    // dominant read, with the stone grain still visible through it.
    final colorWash = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          highlight.withOpacity(0.42),
          baseColor.withOpacity(0.26),
          shadow.withOpacity(0.34),
        ],
      ).createShader(bounds);
    canvas.drawRect(bounds, colorWash);

    final scanPaint = Paint()
      ..color = Colors.white.withOpacity(0.045)
      ..strokeWidth = 1;
    for (double y = bounds.top; y < bounds.bottom; y += 5) {
      canvas.drawLine(Offset(bounds.left, y), Offset(bounds.right, y), scanPaint);
    }

    // Inset shadow ring around the segment so it reads as one distinct
    // carved block with relief, not a flat cutout of a larger wall.
    final insetWidth = bounds.shortestSide * 0.10;
    final insetBevel = Paint()
      ..color = Colors.black.withOpacity(0.40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = insetWidth
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, insetWidth * 0.6);
    canvas.drawPath(path, insetBevel);

    canvas.restore();

    final edgeGlow = Paint()
      ..color = neon.withOpacity((0.75 * pulseBoost).clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(path, edgeGlow);

    final edgeCrisp = Paint()
      ..color = Color.lerp(neon, Colors.white, 0.35)!.withOpacity(0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawPath(path, edgeCrisp);
  }

  // Flat fill with a plain outline, no glow — used for the muted/toggled
  // (tap feedback) state where the segment should look "switched off".
  static void paintMutedSegment(
      Canvas canvas, Path path, LinearGradient gradient, Color outlineColor) {
    final fillPaint = Paint()..style = PaintingStyle.fill;
    fillPaint.shader = gradient.createShader(path.getBounds());
    canvas.drawPath(path, fillPaint);

    final outlinePaint = Paint()
      ..color = outlineColor
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, outlinePaint);
  }

  static TextStyle _labelStyle(double fontSize) => TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        fontFamily: fontFamily,
        letterSpacing: 0.2,
      );

  // Finds the largest font size (down to [minFontSize]) at which [text]
  // renders on a single line no wider than [maxWidth], so category labels
  // never wrap regardless of how long the name is.
  static double _fitFontSize(
    String text,
    double maxWidth,
    double startFontSize, {
    double minFontSize = 8.0,
  }) {
    double fontSize = startFontSize;
    while (fontSize > minFontSize) {
      final textPainter = TextPainter(
        text: TextSpan(text: text, style: _labelStyle(fontSize)),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout(minWidth: 0, maxWidth: double.infinity);
      if (textPainter.width <= maxWidth) {
        return fontSize;
      }
      fontSize -= 0.5;
    }
    return minFontSize;
  }

  // Measures how wide [text] renders at its fitted single-line font size,
  // so callers can center it within their own hand-computed anchor box
  // before painting.
  static double measureWidth(
    String text, {
    required double maxWidth,
    double fontSize = 14,
  }) {
    final fitted = _fitFontSize(text, maxWidth, fontSize);
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: _labelStyle(fitted)),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(minWidth: 0, maxWidth: double.infinity);
    return textPainter.width;
  }

  // Draws [text] on a single line — shrinking to fit [maxWidth] rather than
  // wrapping — with a dark stroked backing then a light fill on top, so
  // labels stay legible over the glow/gradient regardless of the
  // underlying category color.
  static void paintReadableLabel(
    Canvas canvas,
    String text,
    Offset offset, {
    required double maxWidth,
    double fontSize = 14,
  }) {
    final fitted = _fitFontSize(text, maxWidth, fontSize);
    final baseStyle = _labelStyle(fitted);

    final strokeSpan = TextSpan(
      text: text,
      style: baseStyle.copyWith(
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Colors.black.withOpacity(0.6),
      ),
    );
    final fillSpan = TextSpan(
      text: text,
      style: baseStyle.copyWith(color: Colors.white),
    );

    for (final span in [strokeSpan, fillSpan]) {
      final textPainter = TextPainter(
        maxLines: 1,
        text: span,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(minWidth: 0, maxWidth: double.infinity);
      textPainter.paint(canvas, offset);
    }
  }
}
