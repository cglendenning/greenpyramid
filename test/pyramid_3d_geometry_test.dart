import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/models/pyramid_3d_geometry.dart';

import 'test_helpers.dart';

void main() {
  const s = Pyramid3DGeometry.textureSize;
  const viewSize = 340.0;
  const quarter = Pyramid3DGeometry.quarterTurn;

  group('faceMatrix projection', () {
    test('front face at rotation 0 projects symmetrically about center', () {
      final apex = projectTexturePoint(0, 0, viewSize, const Offset(s / 2, 0));
      final baseLeft = projectTexturePoint(0, 0, viewSize, const Offset(0, s));
      final baseRight =
          projectTexturePoint(0, 0, viewSize, const Offset(s, s));

      expect(apex.dx, closeTo(viewSize / 2, 0.001));
      expect(baseLeft.dy, closeTo(baseRight.dy, 0.001));
      expect(baseLeft.dx + baseRight.dx, closeTo(viewSize, 0.001));
      expect(apex.dy, lessThan(baseLeft.dy));
    });

    test('projected silhouette stays inside the viewport when face-on', () {
      // Mid-turn the base corners are allowed to poke past the viewport
      // (accepted trade-off for the larger pyramid), but at every settled
      // face-on angle the whole silhouette must be visible.
      for (int wall = 0; wall < 4; wall++) {
        final rotation = wall * quarter;
        for (final face in [0, 1, 2, 3]) {
          if (!Pyramid3DGeometry.isFaceVisible(face, rotation)) continue;
          for (final corner in const [
            Offset(s / 2, 0),
            Offset(0, s),
            Offset(s, s),
          ]) {
            final p = projectTexturePoint(face, rotation, viewSize, corner);
            expect(p.dx, inInclusiveRange(0, viewSize),
                reason: 'face $face rotation $rotation');
            expect(p.dy, inInclusiveRange(0, viewSize),
                reason: 'face $face rotation $rotation');
          }
        }
      }
    });

    test('face-on silhouette fills most of the portrait viewport', () {
      // The height/base ratio has been tuned by eye twice (2.55 -> 2.35 ->
      // 1.95, widening the base each time), so this pins the invariant
      // that survives tuning: face-on, the pyramid still reads tall enough
      // to fill the square viewport instead of going squat.
      final apex = projectTexturePoint(0, 0, viewSize, const Offset(s / 2, 0));
      final base = projectTexturePoint(0, 0, viewSize, const Offset(s / 2, s));
      expect(base.dy - apex.dy, greaterThan(viewSize * 0.55));
    });
  });

  group('screenToFace', () {
    test('round-trips texture points through the projection', () {
      for (final rotation in [0.0, quarter, -quarter, 2 * quarter]) {
        final face = Pyramid3DGeometry.frontFaceIndex(rotation);
        for (final point in const [
          Offset(s / 2, s / 6),
          Offset(s / 4, 3 * s / 4),
          Offset(s * 0.8, s * 0.95),
        ]) {
          final screen = projectTexturePoint(face, rotation, viewSize, point);
          final back =
              Pyramid3DGeometry.screenToFace(face, rotation, viewSize, screen);
          expect(back, isNotNull);
          expect(back!.dx, closeTo(point.dx, 0.01));
          expect(back.dy, closeTo(point.dy, 0.01));
        }
      }
    });
  });

  group('face visibility', () {
    test('front face visible and back face hidden at rotation 0', () {
      expect(Pyramid3DGeometry.isFaceVisible(0, 0), isTrue);
      expect(Pyramid3DGeometry.isFaceVisible(2, 0), isFalse);
    });

    test('never more than two walls visible, painted far to near', () {
      for (double rotation = 0; rotation < 2 * math.pi; rotation += 0.05) {
        final faces = Pyramid3DGeometry.visibleFacesBackToFront(rotation);
        expect(faces, isNotEmpty, reason: 'rotation $rotation');
        expect(faces.length, lessThanOrEqualTo(2),
            reason: 'rotation $rotation');
        for (int i = 1; i < faces.length; i++) {
          final prev = projectTexturePoint(
              faces[i - 1], rotation, viewSize, const Offset(s / 2, s));
          final next = projectTexturePoint(
              faces[i], rotation, viewSize, const Offset(s / 2, s));
          expect(prev.dy, lessThanOrEqualTo(next.dy + 0.001),
              reason:
                  'nearer wall should project lower (rotation $rotation)');
        }
      }
    });
  });

  group('frontFaceIndex', () {
    test('cycles through all four walls', () {
      expect(Pyramid3DGeometry.frontFaceIndex(0), 0);
      expect(Pyramid3DGeometry.frontFaceIndex(-quarter), 1);
      expect(Pyramid3DGeometry.frontFaceIndex(-2 * quarter), 2);
      expect(Pyramid3DGeometry.frontFaceIndex(-3 * quarter), 3);
      expect(Pyramid3DGeometry.frontFaceIndex(-4 * quarter), 0);
      expect(Pyramid3DGeometry.frontFaceIndex(quarter), 3);
    });
  });

  group('snapTarget', () {
    test('release without fling snaps to the nearest wall', () {
      expect(Pyramid3DGeometry.snapTarget(0.1, 0), closeTo(0, 1e-9));
      expect(Pyramid3DGeometry.snapTarget(quarter - 0.1, 0),
          closeTo(quarter, 1e-9));
    });

    test('target is always a wall-facing angle', () {
      final rand = math.Random(7);
      for (int i = 0; i < 200; i++) {
        final rotation = (rand.nextDouble() - 0.5) * 20;
        final velocity = (rand.nextDouble() - 0.5) * 40;
        final target = Pyramid3DGeometry.snapTarget(rotation, velocity);
        final remainder = (target / quarter) - (target / quarter).round();
        expect(remainder.abs(), lessThan(1e-9));
      }
    });

    test('a fling always advances at least one wall in its direction', () {
      final target = Pyramid3DGeometry.snapTarget(0.05, 5.0);
      expect(target, greaterThanOrEqualTo(quarter));

      final backTarget = Pyramid3DGeometry.snapTarget(0.05, -5.0);
      expect(backTarget, lessThanOrEqualTo(-quarter));
    });

    test('momentum carries a hard fling further than a soft one', () {
      final soft = Pyramid3DGeometry.snapTarget(0, 6.0);
      final hard = Pyramid3DGeometry.snapTarget(0, 20.0);
      expect(hard, greaterThan(soft));
    });
  });

  group('isSettledFaceOn', () {
    test('true face-on, false mid-spin', () {
      expect(Pyramid3DGeometry.isSettledFaceOn(0), isTrue);
      expect(Pyramid3DGeometry.isSettledFaceOn(2 * quarter + 0.01), isTrue);
      expect(Pyramid3DGeometry.isSettledFaceOn(quarter / 2), isFalse);
    });
  });

  group('PyramidFaceLayout.hitTest', () {
    test('maps texture points to the stepped block layout', () {
      // Apex block.
      expect(PyramidFaceLayout.hitTest(const Offset(s / 2, s / 6)), 5);
      // Middle row: left then right.
      expect(PyramidFaceLayout.hitTest(const Offset(s * 0.40, s * 0.55)), 3);
      expect(PyramidFaceLayout.hitTest(const Offset(s * 0.60, s * 0.55)), 4);
      // Bottom row: left, mid, right.
      expect(PyramidFaceLayout.hitTest(const Offset(s * 0.15, s * 0.9)), 0);
      expect(PyramidFaceLayout.hitTest(const Offset(s * 0.50, s * 0.9)), 1);
      expect(PyramidFaceLayout.hitTest(const Offset(s * 0.85, s * 0.9)), 2);
    });

    test('returns null outside the pyramid triangle', () {
      expect(PyramidFaceLayout.hitTest(const Offset(10, 10)), isNull);
      expect(PyramidFaceLayout.hitTest(const Offset(s - 10, 10)), isNull);
    });
  });
}
