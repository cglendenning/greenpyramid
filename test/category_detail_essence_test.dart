import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/services/db.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _TempPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _TempPathProvider(this.dir);
  final String dir;
  @override
  Future<String?> getApplicationDocumentsPath() async => dir;
}

/// D-047: the category detail screen surfaces the essence above the habit
/// checkboxes. The DB-layer lookup (name -> id -> latest essence) is
/// tested directly here; the screen's layout order and "no placeholder for
/// an empty essence" requirement are checked structurally, matching this
/// repo's convention for screens built on live singletons.
void main() {
  final db = DatabaseHelper.instance;
  late Directory tempDir;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('gp_tasklist_test');
    PathProviderPlatform.instance = _TempPathProvider(tempDir.path);
  });
  tearDown(() async {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('D-047: resolving a category\'s essence by name', () {
    test('D-047: getCategoryIdByName resolves an existing category', () async {
      await db.insertCategory(
          {DatabaseHelper.columnCategoryId: 1, DatabaseHelper.columnCat: 'Health'});
      expect(await db.getCategoryIdByName('Health'), 1);
    });

    test('D-047: an unknown category name resolves to null', () async {
      expect(await db.getCategoryIdByName('Nonexistent'), isNull);
    });

    test('D-005/D-010: a category with no essence yet resolves an id but a '
        'null essence — a first-class state, not an error', () async {
      await db.insertCategory(
          {DatabaseHelper.columnCategoryId: 4, DatabaseHelper.columnCat: 'Craft'});
      final id = await db.getCategoryIdByName('Craft');
      expect(id, 4);
      expect(await db.getLatestEssenceForCategory(id!), isNull);
    });

    test('D-047: an edited essence appends a new version rather than '
        'overwriting (D-061)', () async {
      await db.insertCategory(
          {DatabaseHelper.columnCategoryId: 1, DatabaseHelper.columnCat: 'Health'});
      await db.insertCategoryEssence(categoryId: 1, essence: 'first draft');
      await db.insertCategoryEssence(categoryId: 1, essence: 'revised');

      final versions = (await db.queryAllCategoryEssences())
          .where((r) => r[DatabaseHelper.columnEssenceCategoryId] == 1);
      expect(versions.length, 2);
      expect(await db.getLatestEssenceForCategory(1), 'revised');
    });
  });

  group('D-166: insertCategoryEssence is a no-op when the text is '
      'identical to the category\'s current latest version — found live, '
      "on the owner's own account: SyncService.restoreFromCloud called "
      "this unconditionally on every restore, manufacturing a brand-new "
      '"version" identical to the existing one purely as a side effect '
      'of syncing (7+ phantom rows per category, all tagged '
      "sourceSessionId: 'restored')", () {
    test('inserting the same text twice in a row creates only one row, '
        'and returns false for the no-op call', () async {
      await db.insertCategory(
          {DatabaseHelper.columnCategoryId: 1, DatabaseHelper.columnCat: 'Health'});
      final first =
          await db.insertCategoryEssence(categoryId: 1, essence: 'Stay strong.');
      final second =
          await db.insertCategoryEssence(categoryId: 1, essence: 'Stay strong.');

      expect(first, isTrue);
      expect(second, isFalse);
      final versions = (await db.queryAllCategoryEssences())
          .where((r) => r[DatabaseHelper.columnEssenceCategoryId] == 1);
      expect(versions.length, 1);
    });

    test('a genuinely different text still inserts a new version and '
        'returns true', () async {
      await db.insertCategory(
          {DatabaseHelper.columnCategoryId: 1, DatabaseHelper.columnCat: 'Health'});
      await db.insertCategoryEssence(categoryId: 1, essence: 'Stay strong.');
      final inserted =
          await db.insertCategoryEssence(categoryId: 1, essence: 'Stay healthy.');

      expect(inserted, isTrue);
      final versions = (await db.queryAllCategoryEssences())
          .where((r) => r[DatabaseHelper.columnEssenceCategoryId] == 1);
      expect(versions.length, 2);
    });

    test('a category\'s very first essence always inserts — nothing to '
        'compare against yet', () async {
      await db.insertCategory(
          {DatabaseHelper.columnCategoryId: 1, DatabaseHelper.columnCat: 'Health'});
      final inserted =
          await db.insertCategoryEssence(categoryId: 1, essence: 'First ever.');
      expect(inserted, isTrue);
    });

    test('the same text can recur later for a category, as long as it '
        "isn't back-to-back with itself — real reverting to an earlier "
        'wording is a genuine event, not a duplicate', () async {
      await db.insertCategory(
          {DatabaseHelper.columnCategoryId: 1, DatabaseHelper.columnCat: 'Health'});
      await db.insertCategoryEssence(categoryId: 1, essence: 'A.');
      await db.insertCategoryEssence(categoryId: 1, essence: 'B.');
      final revertedBack =
          await db.insertCategoryEssence(categoryId: 1, essence: 'A.');

      expect(revertedBack, isTrue);
      final versions = (await db.queryAllCategoryEssences())
          .where((r) => r[DatabaseHelper.columnEssenceCategoryId] == 1);
      expect(versions.length, 3);
    });
  });

  group('D-127: clearing a category description actually saves the clear', () {
    test('D-127: insertCategoryEssence with an empty string persists an '
        'empty latest essence, not null — the DB layer already supports '
        'this, so the defect was purely in the two screens deciding '
        'whether to call it', () async {
      await db.insertCategory(
          {DatabaseHelper.columnCategoryId: 1, DatabaseHelper.columnCat: 'Health'});
      await db.insertCategoryEssence(categoryId: 1, essence: 'old text');
      expect(await db.getLatestEssenceForCategory(1), 'old text');

      await db.insertCategoryEssence(categoryId: 1, essence: '');
      expect(await db.getLatestEssenceForCategory(1), '',
          reason: 'the clear must land as the new latest version, not be '
              'skipped and leave the old text as latest');
    });

    test('D-127: neither editpyramid.dart nor tasklist.dart gate the '
        'essence write on result.description being non-null anymore — '
        'that was the exact bug (an empty save was silently skipped)', () {
      final editPyramidSource =
          File('lib/screens/editpyramid.dart').readAsStringSync();
      final taskListSource = File('lib/screens/tasklist.dart').readAsStringSync();

      for (final source in [editPyramidSource, taskListSource]) {
        expect(source, isNot(contains('result.description != null')));
        expect(source, contains('result.description != (currentEssence ?? \'\')'));
      }
    });
  });

  group('D-047: the category detail screen structure', () {
    test('D-047: category name, then essence, then habit checkboxes, in '
        'that order', () {
      final source = File('lib/screens/tasklist.dart').readAsStringSync();
      final nameIdx = source.indexOf('Text(category, style: _categoryNameStyle)');
      final essenceIdx = source.indexOf('FutureBuilder<(int?, String?)>');
      final checkboxIdx = source.indexOf('CheckboxListTile');
      expect(nameIdx, greaterThan(-1));
      expect(essenceIdx, greaterThan(nameIdx));
      expect(checkboxIdx, greaterThan(essenceIdx));
    });

    test('D-047: an empty essence renders no placeholder text', () {
      final source = File('lib/screens/tasklist.dart').readAsStringSync();
      expect(source, isNot(contains('Add an essence')));
      expect(source, isNot(contains('No essence yet')));
    });
  });
}
