import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/widgets/pyramid_3d.dart';
import 'package:life_ops/models/pyramid_3d_geometry.dart';
import 'package:life_ops/widgets/pyramid_painting.dart';

import 'test_helpers.dart';

void main() {
  const size = 340.0;
  const s = Pyramid3DGeometry.textureSize;

  final categories = [
    for (final label in ['Health', 'Mindset', 'Wealth', 'Relationships', 'Growth', 'Fun'])
      PyramidCategoryData(label: label, color: const Color(0xFFF96E6E)),
  ];

  Future<void> pumpPyramid(WidgetTester tester, ValueChanged<int> onTap) {
    return tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: Pyramid3D(
            size: size,
            categories: categories,
            onCategoryTap: onTap,
          ),
        ),
      ),
    );
  }

  // Widget-local tap position for a texture point on whichever wall is
  // face-on (a settled front wall always projects like face 0 at rotation
  // 0).
  Offset frontFaceTapPosition(WidgetTester tester, Offset texturePoint) {
    final topLeft = tester.getTopLeft(find.byType(Pyramid3D));
    return topLeft + projectTexturePoint(0, 0, size, texturePoint);
  }

  testWidgets('stone texture decodes from the asset bundle', (tester) async {
    await tester.runAsync(() => PyramidPainting.ensureStoneLoaded());
    expect(PyramidPainting.stoneImage, isNotNull);
    expect(PyramidPainting.stoneImage!.width, greaterThan(0));
  });

  testWidgets('tapping blocks reports the right categories', (tester) async {
    int? tapped;
    await pumpPyramid(tester, (i) => tapped = i);

    await tester.tapAt(frontFaceTapPosition(tester, const Offset(s / 2, s / 6)));
    expect(tapped, 5, reason: 'apex block');

    await tester.tapAt(frontFaceTapPosition(tester, const Offset(s / 2, s * 0.9)));
    expect(tapped, 1, reason: 'bottom middle block');

    await tester.tapAt(frontFaceTapPosition(tester, const Offset(s * 0.4, s * 0.55)));
    expect(tapped, 3, reason: 'middle left block');
  });

  testWidgets('taps outside the pyramid do nothing', (tester) async {
    int? tapped;
    await pumpPyramid(tester, (i) => tapped = i);

    await tester.tapAt(frontFaceTapPosition(tester, const Offset(30, 30)));
    expect(tapped, isNull);
  });

  testWidgets('fling keeps spinning, settles face-on, then blocks are tappable',
      (tester) async {
    int? tapped;
    await pumpPyramid(tester, (i) => tapped = i);

    await tester.fling(find.byType(Pyramid3D), const Offset(-180, 0), 2500);

    // Still settling: taps must not register mid-spin.
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tapAt(frontFaceTapPosition(tester, const Offset(s / 2, s / 6)));
    expect(tapped, isNull, reason: 'no taps while the pyramid is spinning');

    // Once settled the front wall is face-on again and fully tappable.
    await tester.pumpAndSettle();
    await tester.tapAt(frontFaceTapPosition(tester, const Offset(s / 2, s / 6)));
    expect(tapped, 5, reason: 'apex tappable after the spin settles');
  });

  testWidgets('a slow partial drag still settles onto a wall', (tester) async {
    int? tapped;
    await pumpPyramid(tester, (i) => tapped = i);

    // Drag a third of a wall's worth and release gently: it should snap
    // back/forward to a face-on wall so taps work again.
    await tester.drag(find.byType(Pyramid3D), const Offset(-60, 0));
    await tester.pumpAndSettle();

    await tester.tapAt(frontFaceTapPosition(tester, const Offset(s / 2, s * 0.9)));
    expect(tapped, 1);
  });

  group('D-046: entrance spin (setup completion)', () {
    testWidgets('D-046: without playEntranceSpin, no spin animation runs — '
        'settles immediately', (tester) async {
      await pumpPyramid(tester, (_) {});
      await tester.pump();
      // No pending animation to settle; a bounded pump proves nothing is
      // still running (an unbounded entrance spin would time this out).
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
    });

    testWidgets('D-046: playEntranceSpin runs for exactly 3 seconds and '
        'ends face-on, tappable', (tester) async {
      int? tapped;
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: Pyramid3D(
              size: size,
              categories: categories,
              onCategoryTap: (i) => tapped = i,
              playEntranceSpin: true,
            ),
          ),
        ),
      );
      await tester.pump(); // post-frame callback starts the spin

      await tester.pump(const Duration(milliseconds: 1500));
      // Mid-spin: category taps must not land — the pyramid isn't settled.
      await tester.tapAt(frontFaceTapPosition(tester, const Offset(s / 2, s * 0.9)));
      expect(tapped, isNull, reason: 'no tap should register mid-spin');

      await tester.pump(const Duration(milliseconds: 1600)); // past 3s total
      await tester.pumpAndSettle();

      await tester.tapAt(frontFaceTapPosition(tester, const Offset(s / 2, s * 0.9)));
      expect(tapped, 1, reason: 'settled and tappable once the spin ends');
    });

    testWidgets('D-046: respects reduce-motion — settles immediately with '
        'no spin', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Center(
              child: Pyramid3D(
                size: size,
                categories: categories,
                playEntranceSpin: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
    });
  });
}
