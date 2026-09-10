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

  static Color _neonFor(Color baseColor) =>
      HSLColor.fromColor(baseColor).withSaturation(1.0).withLightness(0.62).toColor();

  static double _pulseBoost(double pulse) => 0.85 + (pulse * 0.3); // 0.85..1.15

  /// The outward-blurred ambient bloom, on its own so it can be drawn for
  /// every segment on a shared canvas *before* any segment's opaque body
  /// fill — found live: when a whole segment (glow, then stone fill, then
  /// edge, in that order) was painted one segment at a time on the
  /// pyramid's single shared canvas, each segment's rightward/upward glow
  /// bleeding into a neighbor's territory got silently painted over by
  /// that neighbor's own later, opaque stone fill — most visible as the
  /// glow looking "cut off" on whichever side of a block was drawn over
  /// by the next one, since [_buildSegmentPaths]' draw order is bottom
  /// row left-to-right, then the middle row, then the apex. Splitting
  /// into three passes (glow, then body, then edge) run across every
  /// segment in turn — rather than one segment fully painted at a time —
  /// fixes this without changing what any single segment looks like in
  /// isolation.
  static void paintSegmentGlow(
    Canvas canvas,
    Path path,
    Color baseColor, {
    double pulse = 0.5,
  }) {
    final neon = _neonFor(baseColor);
    final pulseBoost = _pulseBoost(pulse);
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
  }

  // Ancient-stone-block-meets-HUD treatment for a lit (non-muted) segment's
  // opaque body: the segment reads as one monolithic carved stone block
  // (the photographic dark-granite slab texture fitted to the segment's
  // own bounds, a procedural gradient until it loads, plus an inset
  // shadow bevel), then a saturated colored bloom, a translucent
  // status-color wash, and fine scanlines are layered on top. Clipped to
  // [path], so — unlike the glow — this never reaches past the segment's
  // own edges into a neighbor's territory.
  static void paintSegmentBody(
    Canvas canvas,
    Path path,
    Color baseColor,
  ) {
    final bounds = path.getBounds();
    final hsl = HSLColor.fromColor(baseColor);

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
  }

  /// The neon edge — a soft blurred stroke plus a crisp 1.4px line on top —
  /// drawn last across every segment so a shared boundary's edge glow
  /// (which, like the ambient glow, blurs slightly past the path itself)
  /// is never covered by a later segment's opaque body fill either.
  static void paintSegmentEdge(
    Canvas canvas,
    Path path,
    Color baseColor, {
    double pulse = 0.5,
  }) {
    final neon = _neonFor(baseColor);
    final pulseBoost = _pulseBoost(pulse);

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

  /// The single-call convenience for painting one segment fully in
  /// isolation (glow, then body, then edge) — correct on its own, but do
  /// NOT use this to paint multiple segments that share a canvas and may
  /// touch or overlap (like the pyramid's own six blocks): call
  /// [paintSegmentGlow] for every segment first, then [paintSegmentBody]
  /// for every segment, then [paintSegmentEdge] for every segment, or a
  /// later segment's opaque body will paint over an earlier segment's
  /// glow bleeding into its territory (see [paintSegmentGlow]'s own
  /// comment for the defect this was found from).
  static void paintGlowingSegment(
    Canvas canvas,
    Path path,
    Color baseColor, {
    double pulse = 0.5,
  }) {
    paintSegmentGlow(canvas, path, baseColor, pulse: pulse);
    paintSegmentBody(canvas, path, baseColor);
    paintSegmentEdge(canvas, path, baseColor, pulse: pulse);
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

  // Found live: labels used to be forced onto a single line and shrunk
  // (down to an 8px floor) until they fit a width budget — a long name
  // either went illegibly tiny to stay on one line, or, once the floor
  // was hit, overflowed anyway with nothing containing it. Neither
  // problem is fixable by tuning the width alone: a block has real
  // vertical room too, and a label should use it — wrapping across a
  // couple of lines at a readable size — before ever shrinking below a
  // comfortable minimum.
  //
  // Finds the largest font size (down to [minFontSize]) at which [text]
  // wraps to fit within [maxWidth] and [maxLines] lines without exceeding
  // [maxHeight] — wrapping is tried at every size before the size itself
  // is reduced, so a label reaches for the floor font size only once
  // wrapping alone genuinely can't make it fit.
  static (double fontSize, TextPainter painter) _fitWrappedText(
    String text,
    double maxWidth,
    double maxHeight,
    double startFontSize, {
    double minFontSize = 10.0,
    int maxLines = 3,
  }) {
    double fontSize = startFontSize;
    TextPainter layOut(double size) => TextPainter(
          text: TextSpan(text: text, style: _labelStyle(size)),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
          maxLines: maxLines,
        )..layout(maxWidth: maxWidth);

    while (fontSize > minFontSize) {
      final painter = layOut(fontSize);
      if (!painter.didExceedMaxLines && painter.height <= maxHeight) {
        return (fontSize, painter);
      }
      fontSize -= 0.5;
    }
    return (minFontSize, layOut(minFontSize));
  }

  // Draws [text] centered on [anchor], wrapping within a box up to
  // [maxWidth] wide and [maxHeight] tall — a dark stroked backing then a
  // light fill on top, so labels stay legible over the glow/gradient
  // regardless of the underlying category color. Clipped to that box, so
  // a label that still doesn't fit even at the floor font size and
  // [maxLines] lines truncates at its own block's boundary rather than
  // bleeding into whatever is drawn next to it.
  static void paintReadableLabel(
    Canvas canvas,
    String text,
    Offset anchor, {
    required double maxWidth,
    required double maxHeight,
    double fontSize = 15,
    int maxLines = 3,
  }) {
    final (fitted, layout) = _fitWrappedText(
        text, maxWidth, maxHeight, fontSize,
        maxLines: maxLines);
    final baseStyle = _labelStyle(fitted);
    final topLeft =
        Offset(anchor.dx - layout.width / 2, anchor.dy - layout.height / 2);

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

    canvas.save();
    // A little slack on every side for the stroke's own width (it
    // extends past the glyph outline) and for descenders.
    canvas.clipRect(Rect.fromCenter(
        center: anchor, width: maxWidth + 8, height: maxHeight + 8));

    for (final span in [strokeSpan, fillSpan]) {
      final textPainter = TextPainter(
        maxLines: maxLines,
        text: span,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: maxWidth);
      textPainter.paint(canvas, topLeft);
    }
    canvas.restore();
  }
}
