import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Shared canvas-painting helpers for the pyramid's six wall segments
// (Pyramid3D, pyramid_3d.dart), so the glow/panel/label technique lives in
// one place instead of being copy-pasted six times. D-151: the flat 2D
// DrawCat1..DrawCat6 CustomPainters this comment used to describe were the
// pyramid edit screen's own separate, legacy rendering pipeline — deleted
// once EditPyramid was migrated onto the same Pyramid3D/PyramidStack the
// main screen already used.
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

  static TextStyle _labelStyle(double fontSize) => TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        fontFamily: fontFamily,
        letterSpacing: 0.2,
      );

  // D-126: labels wrap at word boundaries only — never inside a word, no
  // hyphenation — and every line of a given label shares one font size,
  // never a larger size for a short line just because it has room. Found
  // live, twice: first, forcing a label onto one line and shrinking it
  // meant a long name either went illegibly tiny or (once the shrink
  // floor was hit) overflowed with nothing containing it; then, letting
  // Flutter's own TextPainter wrap multi-line text meant it broke *inside*
  // long words ("Settle-\ndness") whenever a single word didn't fit the
  // width, which Flutter's default line-breaking permits but this app's
  // labels must never do. Both problems come from the same root: relying
  // on a general-purpose text layout that isn't actually the algorithm
  // this design calls for. `_wrapWords` implements that algorithm
  // directly instead: pack whole words onto a line greedily, and report
  // failure (rather than splitting a word) the moment even one word alone
  // can't fit — the caller's signal to shrink the font size for the
  // *entire* label and re-wrap from scratch, not just that one word.

  static const double _labelPaddingFraction = 0.06;

  // The rendered width of [text] at [fontSize] in this label style — the
  // exact measurement [wrapWords]/[fitWrappedLabel] make their fit
  // decisions from. Public so tests can construct exact, font-metric-
  // independent scenarios (an active-font substitution in the test
  // environment would otherwise make a hand-guessed pixel width in a
  // test meaningless) rather than guess pixel budgets.
  @visibleForTesting
  static double measureLabelWidth(String text, double fontSize) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: _labelStyle(fontSize)),
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width;
  }

  // Whether [word] alone fits [maxWidth] at [fontSize] — the test that
  // decides whether wrapping can help at this size at all.
  static bool _wordFits(String word, double maxWidth, double fontSize) =>
      measureLabelWidth(word, fontSize) <= maxWidth;

  // Greedily packs [words] onto as few lines as fit within [maxWidth] at
  // [fontSize], adding one word at a time and starting a new line only
  // once the next word would overflow the current one. Returns null —
  // never a line containing a mid-word break — the instant a single word
  // doesn't fit even alone on its own line, since no arrangement of
  // whole words at this font size can accommodate it. Public (but
  // annotated, not part of the real API) so D-126's actual wrapping rule
  // — the thing most worth getting right here — is directly testable.
  @visibleForTesting
  static List<String>? wrapWords(
      List<String> words, double maxWidth, double fontSize) {
    final lines = <String>[];
    var current = '';
    for (final word in words) {
      if (current.isEmpty) {
        if (!_wordFits(word, maxWidth, fontSize)) return null;
        current = word;
        continue;
      }
      final candidate = '$current $word';
      if (_wordFits(candidate, maxWidth, fontSize)) {
        current = candidate;
      } else {
        lines.add(current);
        if (!_wordFits(word, maxWidth, fontSize)) return null;
        current = word;
      }
    }
    if (current.isNotEmpty) lines.add(current);
    return lines;
  }

  static double _lineHeight(double fontSize) {
    final painter = TextPainter(
      text: TextSpan(text: 'Ag', style: _labelStyle(fontSize)),
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.height;
  }

  // Finds the largest font size (down to [minFontSize]) at which [text]
  // word-wraps (never mid-word) to fit within [maxWidth] and [maxHeight]
  // — the size only ever decreases as far as fitting actually requires:
  // wrapping is tried again at every candidate size before the size
  // itself is reduced further, and the same size always applies to every
  // line the label ends up wrapped to. Public for the same reason as
  // [wrapWords] — directly testable without a Canvas.
  @visibleForTesting
  static (double fontSize, List<String> lines) fitWrappedLabel(
    String text,
    double maxWidth,
    double maxHeight,
    double startFontSize, {
    double minFontSize = 6.0,
  }) {
    final words = text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return (startFontSize, const []);

    double fontSize = startFontSize;
    while (fontSize > minFontSize) {
      final lines = wrapWords(words, maxWidth, fontSize);
      if (lines != null && lines.length * _lineHeight(fontSize) <= maxHeight) {
        return (fontSize, lines);
      }
      fontSize -= 0.5;
    }
    // Floor reached: still prefer a real word-wrap over a mid-word split
    // if one exists at this size, even if it technically overflows
    // maxHeight — paintReadableLabel's own clip is what contains that,
    // and a clipped whole word reads better than a clipped word-fragment.
    final lines = wrapWords(words, maxWidth, minFontSize) ?? [text];
    return (minFontSize, lines);
  }

  // Draws [text] centered on [anchor], word-wrapped (D-126: never inside
  // a word) within a box up to [maxWidth] wide and [maxHeight] tall, with
  // a small padding inset from that box's own edges — a dark stroked
  // backing then a light fill on top, so labels stay legible over the
  // glow/gradient regardless of the underlying category color. Clipped to
  // the box, so a label that still doesn't fit even at the floor font
  // size truncates at its own block's boundary rather than bleeding into
  // whatever is drawn next to it.
  static void paintReadableLabel(
    Canvas canvas,
    String text,
    Offset anchor, {
    required double maxWidth,
    required double maxHeight,
    double fontSize = 15,
  }) {
    final paddedWidth = maxWidth * (1 - _labelPaddingFraction * 2);
    final paddedHeight = maxHeight * (1 - _labelPaddingFraction * 2);
    final (fitted, lines) =
        fitWrappedLabel(text, paddedWidth, paddedHeight, fontSize);
    if (lines.isEmpty) return;

    final baseStyle = _labelStyle(fitted);
    final lineHeight = _lineHeight(fitted);
    final blockHeight = lines.length * lineHeight;
    final blockTop = anchor.dy - blockHeight / 2;

    canvas.save();
    // A little slack for the stroke's own width (it extends past the
    // glyph outline) and for descenders, beyond the padded box itself.
    canvas.clipRect(Rect.fromCenter(
        center: anchor, width: maxWidth + 8, height: maxHeight + 8));

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final strokeSpan = TextSpan(
        text: line,
        style: baseStyle.copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = Colors.black.withOpacity(0.6),
        ),
      );
      final fillSpan = TextSpan(
        text: line,
        style: baseStyle.copyWith(color: Colors.white),
      );
      for (final span in [strokeSpan, fillSpan]) {
        final textPainter = TextPainter(
          text: span,
          textDirection: TextDirection.ltr,
        )..layout();
        final lineTopLeft = Offset(
            anchor.dx - textPainter.width / 2, blockTop + i * lineHeight);
        textPainter.paint(canvas, lineTopLeft);
      }
    }
    canvas.restore();
  }
}
