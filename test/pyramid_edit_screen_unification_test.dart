import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D-151: the pyramid edit screen used to run six flat, old, separate
/// CustomPainters (`DrawCat1`..`DrawCat6`) nobody migrated when the main
/// pyramid screen was rebuilt on the real 3D `Pyramid3D` widget — found
/// live, five times over, the owner escalating each time: "The labels on
/// the edit screen in the pyramid are still jacked up" and finally "get
/// rid of the old bullshit code that is in the edit screen and ...
/// utilize the exact same code as the main screen so that whenever the
/// code changes in the main screen, they will also change in the edit
/// screen." `editpyramid.dart` and `pyramid.dart` both own live
/// Firebase/DatabaseHelper singletons (same class of screen as
/// tasklist.dart — see profile_wiring_test.dart's own comment), so this
/// is a structural (source-text) test; the extracted, DB/Firebase-free
/// `PyramidStack` widget itself is genuinely widget-tested in
/// pyramid_stack_test.dart.
void main() {
  final editPyramidSource =
      File('lib/screens/editpyramid.dart').readAsStringSync();
  final pyramidSource = File('lib/widgets/pyramid.dart').readAsStringSync();
  final homescreenSource =
      File('lib/screens/homescreen.dart').readAsStringSync();

  group('D-151: the old, separate flat-painter pipeline is gone', () {
    test('editpyramid.dart no longer defines or uses DrawCat1..DrawCat6, '
        'or the on/off color-toggle state that existed only to give them '
        'tap feedback', () {
      expect(editPyramidSource, isNot(contains('pyr.DrawCat')));
      expect(editPyramidSource, isNot(contains('_kGreenLG')));
      expect(editPyramidSource, isNot(contains('_kWhiteLG')));
      expect(editPyramidSource, isNot(contains('ColorToggled')));
      expect(editPyramidSource, isNot(contains('CustomPaint(')));
    });

    test('pyramid.dart no longer defines DrawCat1..DrawCat6 either — the '
        'six-painter pipeline is deleted outright, not just unreferenced',
        () {
      expect(pyramidSource, isNot(contains('class DrawCat')));
    });
  });

  group('D-151: both screens render the exact same shared widget', () {
    test('editpyramid.dart renders PyramidStack', () {
      expect(editPyramidSource, contains('PyramidStack('));
    });

    test('pyramid.dart (the main screen) also renders PyramidStack — not '
        'a second, parallel construction of Pyramid3D', () {
      expect(pyramidSource, contains('PyramidStack('));
      expect(pyramidSource, isNot(contains('Pyramid3D(')),
          reason: 'Pyramid3D should only be instantiated inside the '
              'shared PyramidStack now, not directly in pyramid.dart too');
    });
  });

  group('D-151: tapping a block still opens the rename/essence editor, '
      'and the underlying data actually refreshes afterward', () {
    test('EditPyramid wires PyramidStack\'s onCategoryTap to '
        'showEditDialog, mapping the 0-5 index to a 1-6 category id', () {
      expect(editPyramidSource,
          contains('showEditDialog(context, index + 1, category.cat)'));
    });

    test('showEditDialog calls onCategoryEdited after a successful edit, '
        'instead of only ever patching a local CustomPainter cache that '
        'never told the parent (or the main screen, which shares the '
        'same underlying futures) anything changed', () {
      final start = editPyramidSource.indexOf('Future<void> showEditDialog(');
      expect(start, greaterThan(-1));
      final body = editPyramidSource.substring(start);
      expect(body, contains('widget.onCategoryEdited?.call();'));
    });

    test('homescreen.dart wires EditPyramid\'s onCategoryEdited to the '
        'same setFutures() refresh Pyramid\'s own onReturnFromTaskList '
        'uses, so a rename shows up on both screens', () {
      final editPyramidCallStart = homescreenSource.indexOf('EditPyramid(');
      expect(editPyramidCallStart, greaterThan(-1));
      final callEnd = homescreenSource.indexOf('),\n              const Settings',
          editPyramidCallStart);
      expect(callEnd, greaterThan(editPyramidCallStart));
      final callBody =
          homescreenSource.substring(editPyramidCallStart, callEnd);
      expect(callBody, contains('onCategoryEdited:'));
      expect(callBody, contains('setFutures();'));
    });
  });
}
