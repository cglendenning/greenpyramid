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

/// D-095: queryPyramidSummary() is what grounds the general Council
/// conversation (D-091) in the user's actual pyramid instead of the
/// "their life" placeholder that produced disconnected, non-sequitur
/// advisor replies (found live). Tested against the real sqflite FFI
/// plugin, not fakes — the read-only-list defect this codebase has hit
/// twice already (setup_completion_screen.dart, council_category_picker.dart)
/// only reproduces against the real plugin.
void main() {
  final db = DatabaseHelper.instance;
  late Directory tempDir;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('gp_pyramid_summary_test');
    PathProviderPlatform.instance = _TempPathProvider(tempDir.path);
  });
  tearDown(() async {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test(
      'D-095: returns all six categories, ordered by position, tiered '
      '1-3 foundational / 4-5 essential / 6 peak', () async {
    for (var i = 1; i <= 6; i++) {
      await db.insertCategory({
        DatabaseHelper.columnCategoryId: i,
        DatabaseHelper.columnCat: 'Category $i',
        DatabaseHelper.columnPosition: i,
      });
    }

    final summary = await db.queryPyramidSummary();
    expect(summary, hasLength(6));
    expect(summary.map((c) => c['name']),
        ['Category 1', 'Category 2', 'Category 3', 'Category 4', 'Category 5', 'Category 6']);
    expect(summary[0]['tier'], 'foundational');
    expect(summary[2]['tier'], 'foundational');
    expect(summary[3]['tier'], 'essential');
    expect(summary[4]['tier'], 'essential');
    expect(summary[5]['tier'], 'peak');
  });

  test('D-095: each category carries its latest essence, or null if none '
      'has ever been captured', () async {
    await db.insertCategory({
      DatabaseHelper.columnCategoryId: 1,
      DatabaseHelper.columnCat: 'Health',
      DatabaseHelper.columnPosition: 1,
    });
    await db.insertCategory({
      DatabaseHelper.columnCategoryId: 2,
      DatabaseHelper.columnCat: 'Craft',
      DatabaseHelper.columnPosition: 2,
    });
    await db.insertCategoryEssence(
        categoryId: 1, essence: 'my body carries me', sourceSessionId: 's1');

    final summary = await db.queryPyramidSummary();
    final health = summary.singleWhere((c) => c['name'] == 'Health');
    final craft = summary.singleWhere((c) => c['name'] == 'Craft');
    expect(health['essence'], 'my body carries me');
    expect(craft['essence'], isNull);
  });

  test('D-095: a category with more than one essence version reports the '
      'latest, not the first', () async {
    await db.insertCategory({
      DatabaseHelper.columnCategoryId: 1,
      DatabaseHelper.columnCat: 'Health',
      DatabaseHelper.columnPosition: 1,
    });
    await db.insertCategoryEssence(
        categoryId: 1, essence: 'an early draft', sourceSessionId: 's1');
    await db.insertCategoryEssence(
        categoryId: 1, essence: 'the real one', sourceSessionId: 's2');

    final summary = await db.queryPyramidSummary();
    expect(summary.single['essence'], 'the real one');
  });
}
