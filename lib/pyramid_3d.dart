import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:life_ops/pyramid_3d_geometry.dart';
import 'package:life_ops/pyramid_painting.dart';

// One category slot on the pyramid: bottom row (0,1,2), middle row (3,4),
// apex (5) — matching the original 2D layout's category order.
class PyramidCategoryData {
  final String label;
  final Color color;
  const PyramidCategoryData({required this.label, required this.color});
}

// A four-walled stone pyramid spinning around its vertical axis, rendered
// with native canvas perspective transforms (no 3D engine). Every wall
// shows the same stepped six-block stone-and-glow layout painted by
// PyramidPainting. Dragging horizontally spins it; releasing carries the
// spin with momentum and settles face-on to the nearest wall, at which
// point each block is tappable via [onCategoryTap].
class Pyramid3D extends StatefulWidget {
  final List<PyramidCategoryData> categories; // exactly 6
  final double size;
  final ValueChanged<int>? onCategoryTap;

  const Pyramid3D({
    super.key,
    required this.categories,
    required this.size,
    this.onCategoryTap,
  });

  @override
  State<Pyramid3D> createState() => _Pyramid3DState();
}

class _Pyramid3DState extends State<Pyramid3D>
    with SingleTickerProviderStateMixin {
  // One full widget-width drag spins the pyramid half a revolution.
  static const double _radiansPerWidgetWidth = math.pi;

  late final AnimationController _settle;
  late final CurvedAnimation _settleCurve;
  double _rotation = 0;
  double _settleFrom = 0;
  double _settleTo = 0;

  // Every wall shows identical content (blocks, glow, stone, labels) — only
  // the perspective transform and a cheap shade overlay differ per face —
  // so it's rendered once into a bitmap and blitted per frame instead of
  // repainting ~60 GPU blur passes every frame. Measured on a low-end
  // Android device: this was the entire jank cause (raster thread averaged
  // 69ms/frame, 100% of frames missed the 16ms budget) while the UI thread
  // was never the bottleneck.
  ui.Image? _wallImage;
  String? _wallCacheKey;
  int _wallRenderToken = 0;

  @override
  void initState() {
    super.initState();
    PyramidPainting.ensureStoneLoaded().then((_) {
      if (mounted) setState(() {});
    });
    _settle = AnimationController(vsync: this);
    _settleCurve =
        CurvedAnimation(parent: _settle, curve: Curves.easeOutCubic);
    _settle.addListener(() {
      setState(() {
        _rotation =
            _settleFrom + (_settleTo - _settleFrom) * _settleCurve.value;
      });
    });
  }

  @override
  void dispose() {
    _wallImage?.dispose();
    _settleCurve.dispose();
    _settle.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails details) {
    _settle.stop();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _rotation +=
          details.delta.dx / widget.size * _radiansPerWidgetWidth;
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final angularVelocity = details.velocity.pixelsPerSecond.dx /
        widget.size *
        _radiansPerWidgetWidth;
    _animateTo(Pyramid3DGeometry.snapTarget(_rotation, angularVelocity));
  }

  void _animateTo(double target) {
    final distance = (target - _rotation).abs();
    if (distance < 1e-4) return;
    _settleFrom = _rotation;
    _settleTo = target;
    _settle.duration = Duration(
        milliseconds: (250 +
                400 * distance / Pyramid3DGeometry.quarterTurn)
            .round()
            .clamp(250, 1400));
    _settle.forward(from: 0);
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onCategoryTap == null) return;
    // Taps only register once the spin has settled face-on to a wall.
    if (_settle.isAnimating ||
        !Pyramid3DGeometry.isSettledFaceOn(_rotation)) {
      return;
    }
    final face = Pyramid3DGeometry.frontFaceIndex(_rotation);
    final texturePoint = Pyramid3DGeometry.screenToFace(
        face, _rotation, widget.size, details.localPosition);
    if (texturePoint == null) return;
    final category = PyramidFaceLayout.hitTest(texturePoint);
    if (category != null && category < widget.categories.length) {
      widget.onCategoryTap!(category);
    }
  }

  // Bitmap resolution for the cached wall: sized to the widget's actual
  // on-screen physical pixels (with the same ~10% overscan
  // Pyramid3DGeometry.pixelScale allows) so it stays crisp from phones up
  // to tablets, clamped so a huge display doesn't force an oversized cache.
  static int _resolutionFor(double size, double devicePixelRatio) {
    final physicalPixels = size * devicePixelRatio * 1.15;
    return physicalPixels.clamp(Pyramid3DGeometry.textureSize, 2048).round();
  }

  static String _keyFor(
      List<PyramidCategoryData> categories, bool stoneReady, int resolution) {
    final cats = categories.map((c) => '${c.label}#${c.color.value}').join('|');
    return '$cats#$stoneReady#$resolution';
  }

  void _syncWallCache() {
    if (widget.size <= 0) return;
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    final resolution = _resolutionFor(widget.size, devicePixelRatio);
    final key = _keyFor(
        widget.categories, PyramidPainting.stoneImage != null, resolution);
    if (key == _wallCacheKey) return;
    _wallCacheKey = key;

    final token = ++_wallRenderToken;
    final categories = widget.categories;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(resolution / Pyramid3DGeometry.textureSize);
    paintPyramidWallContent(canvas, categories);
    recorder.endRecording().toImage(resolution, resolution).then((image) {
      if (!mounted || token != _wallRenderToken) {
        image.dispose();
        return;
      }
      final old = _wallImage;
      setState(() => _wallImage = image);
      old?.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    _syncWallCache();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      onTapUp: _onTapUp,
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: _Pyramid3DPainter(
          rotation: _rotation,
          categories: widget.categories,
          wallImage: _wallImage,
        ),
      ),
    );
  }
}

// The full stepped six-block stone-and-glow wall content, shared by the
// cache-rendering pass (drawn once into a bitmap) and the live painter's
// one-time fallback for the handful of frames before that bitmap is ready.
void paintPyramidWallContent(
    Canvas canvas, List<PyramidCategoryData> categories) {
  for (int i = 0; i < categories.length && i < 6; i++) {
    final path = PyramidFaceLayout.segmentPaths[i];
    final (anchor, maxWidth, fontSize) = PyramidFaceLayout.labelAnchors[i];
    PyramidPainting.paintGlowingSegment(canvas, path, categories[i].color);
    final textWidth = PyramidPainting.measureWidth(categories[i].label,
        maxWidth: maxWidth, fontSize: fontSize);
    PyramidPainting.paintReadableLabel(
      canvas,
      categories[i].label,
      Offset(anchor.dx - textWidth / 2, anchor.dy),
      maxWidth: maxWidth,
      fontSize: fontSize,
    );
  }
}

class _Pyramid3DPainter extends CustomPainter {
  final double rotation;
  final List<PyramidCategoryData> categories;
  final ui.Image? wallImage;

  _Pyramid3DPainter(
      {required this.rotation, required this.categories, this.wallImage});

  static const Rect _dstRect = Rect.fromLTWH(
      0, 0, Pyramid3DGeometry.textureSize, Pyramid3DGeometry.textureSize);
  static final Paint _imagePaint = Paint()
    ..filterQuality = FilterQuality.medium;

  @override
  void paint(Canvas canvas, Size size) {
    for (final face in Pyramid3DGeometry.visibleFacesBackToFront(rotation)) {
      final matrix = Pyramid3DGeometry.faceMatrix(face, rotation, size.width);
      canvas.save();
      canvas.transform(matrix.storage);
      final image = wallImage;
      if (image != null) {
        final srcRect =
            Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
        canvas.drawImageRect(image, srcRect, _dstRect, _imagePaint);
      } else {
        // Cache not ready yet (first frame or two) — paint directly so
        // there's never a blank wall while it renders.
        paintPyramidWallContent(canvas, categories);
      }

      // Directional lighting: darken walls angled away from the light so
      // the solid form reads while spinning. Left as a live per-frame draw
      // (cheap: one solid path fill) since it depends on rotation, unlike
      // everything else on the wall.
      final shade = Pyramid3DGeometry.shadeAmount(face, rotation);
      if (shade > 0.01) {
        canvas.drawPath(
          PyramidFaceLayout.faceTriangle,
          Paint()..color = Colors.black.withOpacity(0.32 * shade),
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_Pyramid3DPainter oldDelegate) {
    if (oldDelegate.rotation != rotation) return true;
    if (oldDelegate.wallImage != wallImage) return true;
    if (oldDelegate.categories.length != categories.length) return true;
    for (int i = 0; i < categories.length; i++) {
      if (oldDelegate.categories[i].label != categories[i].label ||
          oldDelegate.categories[i].color != categories[i].color) {
        return true;
      }
    }
    return false;
  }
}
