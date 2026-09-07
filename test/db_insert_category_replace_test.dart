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

/// D-051/D-084: regression test for a defect found live — a real setup
/// completed, essences and all, but every category synced to Firestore
/// still literally named "Empty1".."Empty6" (populateCategory()'s seed
/// values), each stuck at position 0. Root cause: category.categoryid is
/// the PRIMARY KEY, every fresh install already has rows 1-6 seeded, and
/// insertCategory() had no conflict policy — sqflite's ABORT default threw
/// on the second insert, which insertCategory()'s own catch block
/// silently swallowed in release builds (only `if (kDebugMode) print(e)`).
/// The completion screen then built its pyramid from six identical,
/// degenerate category rows and rendered a blank screen instead of the
/// user's actual pyramid.
void main() {
  final db = DatabaseHelper.instance;
  late Directory tempDir;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('gp_category_replace_test');
    PathProviderPlatform.instance = _TempPathProvider(tempDir.path);
  });
  tearDown(() async {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test(
      'D-051: committing a real category over a seeded placeholder id '
      'replaces it — the seed name and default position=0 must not '
      'survive', () async {
    // Simulates populateCategory()'s unconditional seed at every launch.
    await db.insertCategory(
        {DatabaseHelper.columnCategoryId: 1, DatabaseHelper.columnCat: 'Empty1'});

    // Simulates SetupService.commitCategories() writing the Council's
    // real derivation over the same id.
    await db.insertCategory({
      DatabaseHelper.columnCategoryId: 1,
      DatabaseHelper.columnCat: 'Health',
      DatabaseHelper.columnPosition: 1,
    });

    final rows = await db.queryCategories();
    final row = rows.singleWhere(
        (r) => r[DatabaseHelper.columnCategoryId] == 1);
    expect(row[DatabaseHelper.columnCat], 'Health',
        reason: 'the seed placeholder must be overwritten, not left in '
            'place alongside a silently-dropped real insert');
    expect(row[DatabaseHelper.columnPosition], 1,
        reason: 'position must carry through too — a defaulted 0 is what '
            'broke the completion screen\'s pyramid rendering');
  });

  test('D-051: all six categories can be committed over all six seeded '
      'placeholders in one pass, matching real setup completion', () async {
    for (var i = 1; i <= 6; i++) {
      await db.insertCategory(
          {DatabaseHelper.columnCategoryId: i, DatabaseHelper.columnCat: 'Empty$i'});
    }
    for (var i = 1; i <= 6; i++) {
      await db.insertCategory({
        DatabaseHelper.columnCategoryId: i,
        DatabaseHelper.columnCat: 'Category $i',
        DatabaseHelper.columnPosition: i,
      });
    }

    final rows = List<Map<String, dynamic>>.from(await db.queryCategories())
      ..sort((a, b) => (a[DatabaseHelper.columnCategoryId] as int)
          .compareTo(b[DatabaseHelper.columnCategoryId] as int));
    expect(rows.length, 6);
    for (var i = 0; i < 6; i++) {
      expect(rows[i][DatabaseHelper.columnCat], 'Category ${i + 1}');
      expect(rows[i][DatabaseHelper.columnPosition], i + 1);
    }
  });
}
