import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D-113: both category-editing entry points (the pyramid's own edit
/// mode, and the category detail screen) use the shared
/// showCategoryEditSheet — structural, matching this repo's convention
/// for screens built on live singletons (editpyramid.dart, tasklist.dart
/// aren't directly widget-tested elsewhere either).
void main() {
  test('D-113: editpyramid.dart uses the shared sheet, not its own '
      'AlertDialog', () {
    final source = File('lib/screens/editpyramid.dart').readAsStringSync();
    expect(source, contains('showCategoryEditSheet('));
    expect(source, isNot(contains('AlertDialog(')));
  });

  test('D-113: tasklist.dart uses the shared sheet, not its own '
      '"Your essence" AlertDialog', () {
    final source = File('lib/screens/tasklist.dart').readAsStringSync();
    expect(source, contains('showCategoryEditSheet('));
    expect(source, isNot(contains("'Your essence'")));
    expect(source, isNot(contains('AlertDialog(')));
  });

  test('D-113: renaming a category from the pyramid\'s edit mode no '
      'longer deletes its tasks and task-log history first — regression '
      'test for a real data-loss bug found live: '
      'renameCategoryCascading already moves every task/tasklog row to '
      'the new name (D-084), but a leftover deleteCategoryContents call '
      'immediately before it wiped them first, so the cascade that '
      'followed had nothing left to move. Fixing a category name typo '
      'was silently deleting the category\'s entire habit history.', () {
    final source = File('lib/screens/editpyramid.dart').readAsStringSync();
    expect(source, isNot(contains('dbHelper.deleteCategoryContents(')),
        reason: 'the destructive pre-cascade delete call must not reappear');
    expect(source, contains('renameCategoryCascading('));
  });

  test('D-113: tasklist.dart\'s category detail screen can rename the '
      'category too, not only edit its description — found live: '
      '"wherever I can edit the category, I should also be able to edit '
      'the description of the category" implies the reverse as well, '
      'and this screen previously had no way to touch the name at all',
      () {
    final source = File('lib/screens/tasklist.dart').readAsStringSync();
    expect(source, contains('renameCategoryCascading('));
  });

  test('D-113: a category with no description yet still gets an edit '
      'action on the category detail screen — found live, the whole '
      'block (name-editing included) used to be hidden whenever no '
      'essence existed, D-005/D-010\'s normal state for essential/peak '
      'categories', () {
    final source = File('lib/screens/tasklist.dart').readAsStringSync();
    final start = source.indexOf('FutureBuilder<(int?, String?)>');
    expect(start, greaterThan(-1));
    final end = source.indexOf('},\n                  ),', start);
    final body = source.substring(start, end == -1 ? source.length : end);
    expect(body, isNot(contains('data.\$2 == null')),
        reason: 'a null description must not hide the Edit action anymore');
  });
}
