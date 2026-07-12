import 'dart:math' as math;
import 'dart:ui';

import 'package:vector_math/vector_math_64.dart';

// Pure geometry for the home-screen 3D pyramid: a square pyramid (4
// triangular walls) spinning around the vertical axis. This file owns all
// the projection, snap-rotation, and tap hit-test math so it can be unit
// tested without widgets; pyramid_3d.dart only paints and animates.
class Pyramid3DGeometry {
  Pyramid3DGeometry._();

  static const int faceCount = 4;
  static const double quarterTurn = math.pi / 2;

  // Model units. The wall slope is height / baseHalfWidth — this ratio is
  // what "steepness" means; raise height to make the sides steeper.
  static const double baseHalfWidth = 1.0;
  static const double height = 1.95;

  // Camera distance from the pyramid's axis, in model units.
  static const double cameraDistance = 7.0;

  // The flat face painting/hit-test coordinate space is a square of this
  // side length ("texture units"); the face triangle spans it fully.
  static const double textureSize = 640.0;

  // Seconds of momentum a fling carries before settling, and the angular
  // velocity (rad/s) below which a release just snaps to the nearest wall.
  static const double momentumSeconds = 0.30;
  static const double minFlingVelocity = 1.5;

  // Maps texture space (u,v,0,1) onto face 0's plane in model space:
  // texture (s/2, 0) is the apex (0, -h/2, 0); texture (0, s) and (s, s)
  // are the front base corners (-b, h/2, b) and (b, h/2, b). Model y points
  // down to match canvas coordinates; +z points toward the viewer.
  static final Matrix4 _faceAffine = Matrix4(
    2 * baseHalfWidth / textureSize, 0, 0, 0, // column 0: d/du
    0, height / textureSize, baseHalfWidth / textureSize, 0, // column 1: d/dv
    0, 0, 1, 0, // column 2: unused (face plane has no thickness)
    -baseHalfWidth, -height / 2, 0, 1, // column 3: texture origin (apex level)
  );

  // Outward unit normal of face 0 in model space (tilted up and toward the
  // viewer, since the wall leans back toward the apex).
  static final Vector3 _faceNormal =
      Vector3(0, -baseHalfWidth, height).normalized();

  static Vector3 _faceCentroid0() => Vector3(
      0, height / 6, 2 * baseHalfWidth / 3); // mean of apex + 2 base corners

  // Model-units-to-pixels scale, sized against the worst-case silhouette
  // (widest is corner-on at sqrt(2) * baseHalfWidth per side; tallest is
  // the near base edge, magnified by perspective) and then deliberately
  // scaled 10% past a guaranteed fit: face-on the pyramid stays inside the
  // viewport, and the corners poking slightly out mid-turn are accepted.
  static double pixelScale(double viewSize) {
    final nearMagnification = 1 / (1 - baseHalfWidth / cameraDistance);
    final widthNeeded = 2 * math.sqrt2 * baseHalfWidth;
    final heightNeeded = (height / 2) * (1 + nearMagnification);
    return 0.94 * 1.10 * viewSize / math.max(widthNeeded, heightNeeded);
  }

  // Vertical pixel offset that centers the projected silhouette (the near
  // base edge is perspective-magnified downward more than the apex reaches
  // up, so the shape is nudged up a little).
  static double _verticalCenteringOffset(double px) {
    final nearMagnification = 1 / (1 - baseHalfWidth / cameraDistance);
    final top = -px * height / 2;
    final bottom = px * (height / 2) * nearMagnification;
    return -(top + bottom) / 2;
  }

  static double faceAngle(int face, double rotation) =>
      rotation + face * quarterTurn;

  static Matrix4 _rotationFor(int face, double rotation) =>
      Matrix4.rotationY(faceAngle(face, rotation));

  // Full texture-space -> screen-space transform for one face, including
  // the y-axis spin, perspective, pixel scaling, and viewport centering.
  static Matrix4 faceMatrix(int face, double rotation, double viewSize) {
    final px = pixelScale(viewSize);
    final perspective = Matrix4.identity()
      ..setEntry(3, 2, -1 / cameraDistance);
    return Matrix4.identity()
      ..translateByDouble(
          viewSize / 2, viewSize / 2 + _verticalCenteringOffset(px), 0, 1)
      ..scaleByDouble(px, px, px, 1)
      ..multiply(perspective)
      ..multiply(_rotationFor(face, rotation))
      ..multiply(_faceAffine);
  }

  static Vector3 _worldNormal(int face, double rotation) =>
      _rotationFor(face, rotation).transform3(_faceNormal.clone());

  static Vector3 _worldCentroid(int face, double rotation) =>
      _rotationFor(face, rotation).transform3(_faceCentroid0());

  // A face is visible when its outward normal points toward the camera at
  // (0, 0, cameraDistance). At most two of the four walls pass this.
  static bool isFaceVisible(int face, double rotation) {
    final centroid = _worldCentroid(face, rotation);
    final toCamera = Vector3(0, 0, cameraDistance) - centroid;
    return _worldNormal(face, rotation).dot(toCamera) > 0;
  }

  // Visible faces ordered far-to-near, ready to paint back-to-front.
  static List<int> visibleFacesBackToFront(double rotation) {
    final faces = <int>[
      for (int f = 0; f < faceCount; f++)
        if (isFaceVisible(f, rotation)) f
    ];
    faces.sort((a, b) => _worldCentroid(a, rotation)
        .z
        .compareTo(_worldCentroid(b, rotation).z));
    return faces;
  }

  // 0 (facing the light) .. 1 (facing fully away); the painter darkens the
  // wall by this amount so the 3D form reads while spinning.
  static double shadeAmount(int face, double rotation) {
    final light = Vector3(0.35, -0.6, 0.72).normalized();
    final lit = _worldNormal(face, rotation).dot(light).clamp(0.0, 1.0);
    return 1.0 - lit;
  }

  // Index of the wall currently facing the viewer.
  static int frontFaceIndex(double rotation) {
    final k = (-rotation / quarterTurn).round();
    return ((k % faceCount) + faceCount) % faceCount;
  }

  // True when the pyramid is settled close enough to face-on that taps
  // should register.
  static bool isSettledFaceOn(double rotation, {double tolerance = 0.06}) {
    final nearest = (rotation / quarterTurn).round() * quarterTurn;
    return (rotation - nearest).abs() < tolerance;
  }

  // Where a released spin should settle: carry [angularVelocity] for
  // momentumSeconds, then snap to the nearest wall. A real fling always
  // advances at least one wall in the fling direction, so a hard swipe
  // never rubber-bands back to the wall it started on.
  static double snapTarget(double rotation, double angularVelocity) {
    final projected = rotation + angularVelocity * momentumSeconds;
    double target = (projected / quarterTurn).round() * quarterTurn;
    if (angularVelocity.abs() >= minFlingVelocity) {
      final direction = angularVelocity.sign;
      while ((target - rotation) * direction < quarterTurn * 0.5) {
        target += direction * quarterTurn;
      }
    }
    return target;
  }

  // Inverse of faceMatrix restricted to the face plane: maps a screen point
  // back to texture-space (u,v) via the 2D homography formed by the matrix
  // columns that act on (u, v, 1). Returns null if the mapping degenerates
  // (face edge-on to the camera).
  static Offset? screenToFace(
      int face, double rotation, double viewSize, Offset screenPoint) {
    final m = faceMatrix(face, rotation, viewSize);
    // Rows x, y, w of columns u, v, translation.
    final h = Matrix3(
      m.entry(0, 0), m.entry(1, 0), m.entry(3, 0),
      m.entry(0, 1), m.entry(1, 1), m.entry(3, 1),
      m.entry(0, 3), m.entry(1, 3), m.entry(3, 3),
    );
    final det = h.determinant();
    if (det.abs() < 1e-12) return null;
    final inverse = Matrix3.zero()..copyInverse(h);
    final v = inverse.transform(Vector3(screenPoint.dx, screenPoint.dy, 1));
    if (v.z.abs() < 1e-12) return null;
    return Offset(v.x / v.z, v.y / v.z);
  }
}

// The flat stepped layout of one pyramid wall in texture space: apex block
// on top (category index 5), a middle row of two (3, 4), and a bottom row
// of three (0, 1, 2) — the same ordering the original 2D pyramid used.
// Owns the block outlines for painting and tap hit-testing, plus label
// anchors.
class PyramidFaceLayout {
  static const double _s = Pyramid3DGeometry.textureSize;

  static double _leftEdge(double y) => _s / 2 - (_s / 2) * (y / _s);
  static double _rightEdge(double y) => _s / 2 + (_s / 2) * (y / _s);

  static final double _row1Y = _s / 3;
  static final double _row2Y = 2 * _s / 3;

  static Path _pathFrom(List<Offset> points) {
    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    path.close();
    return path;
  }

  // Block outlines indexed by category (0..5).
  static final List<Path> segmentPaths = _buildSegmentPaths();

  static List<Path> _buildSegmentPaths() {
    final thirdX1 = _s / 3;
    final thirdX2 = 2 * _s / 3;
    return [
      _pathFrom([
        Offset(_leftEdge(_row2Y), _row2Y),
        Offset(thirdX1, _row2Y),
        Offset(thirdX1, _s),
        Offset(0, _s),
      ]),
      _pathFrom([
        Offset(thirdX1, _row2Y),
        Offset(thirdX2, _row2Y),
        Offset(thirdX2, _s),
        Offset(thirdX1, _s),
      ]),
      _pathFrom([
        Offset(thirdX2, _row2Y),
        Offset(_rightEdge(_row2Y), _row2Y),
        Offset(_s, _s),
        Offset(thirdX2, _s),
      ]),
      _pathFrom([
        Offset(_leftEdge(_row1Y), _row1Y),
        Offset(_s / 2, _row1Y),
        Offset(_s / 2, _row2Y),
        Offset(_leftEdge(_row2Y), _row2Y),
      ]),
      _pathFrom([
        Offset(_s / 2, _row1Y),
        Offset(_rightEdge(_row1Y), _row1Y),
        Offset(_rightEdge(_row2Y), _row2Y),
        Offset(_s / 2, _row2Y),
      ]),
      _pathFrom([
        Offset(_s / 2, 0),
        Offset(_leftEdge(_row1Y), _row1Y),
        Offset(_rightEdge(_row1Y), _row1Y),
      ]),
    ];
  }

  // (label center, max label width, font size) per category, in texture
  // units. Width budgets are capped at roughly 80% of the block's width at
  // the label's height, so even the longest names keep clear padding from
  // the glowing block edges instead of touching them; the middle-row
  // anchors sit low in their blocks where the trapezoids are widest.
  static final List<(Offset, double, double)> labelAnchors = [
    (Offset(_s * 0.20, _s * 0.86), _s * 0.22, 34),
    (Offset(_s / 2, _s * 0.86), _s * 0.26, 34),
    (Offset(_s * 0.80, _s * 0.86), _s * 0.22, 34),
    (Offset(_s * 0.35, _s * 0.60), _s * 0.24, 30),
    (Offset(_s * 0.65, _s * 0.60), _s * 0.24, 30),
    (Offset(_s / 2, _s * 0.225), _s * 0.17, 27),
  ];

  // The wall's full triangular outline (used for the lighting overlay).
  static final Path faceTriangle = _pathFrom([
    Offset(_s / 2, 0),
    Offset(0, _s),
    Offset(_s, _s),
  ]);

  // Category index containing [texturePoint], or null if the point is
  // outside every block.
  static int? hitTest(Offset texturePoint) {
    for (int i = 0; i < segmentPaths.length; i++) {
      if (segmentPaths[i].contains(texturePoint)) return i;
    }
    return null;
  }
}
