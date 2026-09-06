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

/// D-062: a user whose old-flow setup was incomplete when this build lands
/// starts fresh; a user who completed it is untouched (D-002).
void main() {
  final db = DatabaseHelper.instance;
  late Directory tempDir;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('gp_r6_migration_test');
    PathProviderPlatform.instance = _TempPathProvider(tempDir.path);
  });
  tearDown(() async {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('D-062: fewer than six categories is incomplete — partial rows are '
      'discarded', () async {
    final d = await db.database;
    for (var i = 1; i <= 3; i++) {
      await db.insertCategory({DatabaseHelper.columnCategoryId: i, DatabaseHelper.columnCat: 'Cat$i'});
    }
    await db.insertTask({
      DatabaseHelper.columnCategory: 'Cat1',
      DatabaseHelper.columnTaskDescription: 'A habit',
      DatabaseHelper.columnCreateDate: '2026-01-01',
    });

    await DatabaseHelper.applyV8Migration(d);

    expect((await db.queryCategories()).length, 0);
    expect((await db.queryTasksByCategory('Cat1')).length, 0);
  });

  test('D-062: six categories but zero tasks is incomplete — partial rows '
      'are discarded', () async {
    final d = await db.database;
    for (var i = 1; i <= 6; i++) {
      await db.insertCategory({DatabaseHelper.columnCategoryId: i, DatabaseHelper.columnCat: 'Cat$i'});
    }

    await DatabaseHelper.applyV8Migration(d);

    expect((await db.queryCategories()).length, 0);
  });

  test('D-002/D-062: six categories and at least one task is complete — '
      'untouched', () async {
    final d = await db.database;
    for (var i = 1; i <= 6; i++) {
      await db.insertCategory({DatabaseHelper.columnCategoryId: i, DatabaseHelper.columnCat: 'Cat$i'});
    }
    await db.insertTask({
      DatabaseHelper.columnCategory: 'Cat1',
      DatabaseHelper.columnTaskDescription: 'A habit',
      DatabaseHelper.columnCreateDate: '2026-01-01',
    });

    await DatabaseHelper.applyV8Migration(d);

    expect((await db.queryCategories()).length, 6);
    expect((await db.queryTasksByCategory('Cat1')).length, 1);
  });

  test('D-062: a brand-new, empty database (no old-flow data at all) is '
      'also "incomplete" but there is nothing to discard', () async {
    final d = await db.database;
    await DatabaseHelper.applyV8Migration(d);
    expect((await db.queryCategories()).length, 0);
  });

  test('MIG-4: applyV8Migration is safe to run twice', () async {
    final d = await db.database;
    for (var i = 1; i <= 3; i++) {
      await db.insertCategory({DatabaseHelper.columnCategoryId: i, DatabaseHelper.columnCat: 'Cat$i'});
    }
    await DatabaseHelper.applyV8Migration(d);
    await DatabaseHelper.applyV8Migration(d);
    expect((await db.queryCategories()).length, 0);
  });
}
