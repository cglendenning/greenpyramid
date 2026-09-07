import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/screens/setup_completion_screen.dart';
import 'package:life_ops/services/db.dart';
import 'package:life_ops/theme/app_colors.dart';
import 'package:life_ops/widgets/pyramid_3d.dart';

/// D-046: regression test for the completion screen strand — previously
/// nothing ever called onDone() without a tap, so a user who didn't know
/// (or couldn't, if rendering had failed) to tap was stuck forever.
///
/// queryCategories is injected here rather than going through the real
/// DatabaseHelper singleton: its real implementation runs through
/// sqflite's platform channel, which needs genuine wall-clock time to
/// resolve and makes this screen's timer-based behavior untestable in
/// bounded, deterministic pumps — the db-layer defect itself
/// (query_categories_readonly_test.dart) is covered separately, directly
/// against the real plugin, where it belongs.
void main() {
  Map<String, dynamic> categoryRow(int id) => {
        DatabaseHelper.columnCategoryId: id,
        DatabaseHelper.columnCat: 'Category $id',
        DatabaseHelper.columnPosition: id,
      };

  Widget harness(VoidCallback onDone) => MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: SetupCompletionScreen(
            onDone: onDone,
            queryCategories: () async =>
                [for (var i = 1; i <= 6; i++) categoryRow(i)],
          ),
        ),
      );

  testWidgets(
      'D-046: onDone fires automatically a few seconds after the screen '
      'appears, with no tap required', (tester) async {
    var doneCalled = false;
    await tester.pumpWidget(harness(() => doneCalled = true));
    await tester.pumpAndSettle();

    expect(doneCalled, isFalse,
        reason: 'must not fire immediately — the spin/confetti moment '
            'should actually be seen');
    expect(tester.takeException(), isNull,
        reason: 'the completion screen must build without throwing');
    await tester.pump(const Duration(seconds: 6));
    expect(doneCalled, isTrue,
        reason: 'must fire on its own — previously nothing ever did '
            'without a tap, which could strand the user here forever');
  });

  testWidgets('D-046: tapping still fires onDone immediately, without '
      'waiting for the auto-advance timer', (tester) async {
    var doneCalled = false;
    await tester.pumpWidget(harness(() => doneCalled = true));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SetupCompletionScreen));
    expect(doneCalled, isTrue);
  });

  testWidgets(
      'D-046: every block is the celebratory brand green, not the real '
      '0%-complete red — nothing has been checked off yet at this moment, '
      'so the accurate color would read as a letdown right after the '
      'pyramid was just built. The home screen, which uses real '
      'completion data, is intentionally untouched by this and still '
      'shows red at 0%.', (tester) async {
    await tester.pumpWidget(harness(() {}));
    await tester.pumpAndSettle();

    final pyramid = tester.widget<Pyramid3D>(find.byType(Pyramid3D));
    expect(pyramid.categories, hasLength(6));
    for (final c in pyramid.categories) {
      expect(c.color, AppColors.brandGreen);
    }
  });
}
