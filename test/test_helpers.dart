import 'dart:ui';

import 'package:life_ops/pyramid_3d_geometry.dart';
import 'package:vector_math/vector_math_64.dart';

// Projects a texture-space point on [face] through the pyramid's full
// perspective transform to widget-local screen coordinates.
Offset projectTexturePoint(
    int face, double rotation, double viewSize, Offset texturePoint) {
  final m = Pyramid3DGeometry.faceMatrix(face, rotation, viewSize);
  final v = m.transform(Vector4(texturePoint.dx, texturePoint.dy, 0, 1));
  return Offset(v.x / v.w, v.y / v.w);
}
