import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/services/db.dart';
import 'package:life_ops/services/local_pyramid_reset_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Points path_provider at a real temp dir so DatabaseHelper can open its
// SQLite file under the ffi factory during a VM test — same pattern
// characterization_completion_test.dart already uses.
class _TempPathProvider extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _TempPathProvider(this.dir);
  final String dir;
  @override
  Future<String?> getApplicationDocumentsPath() async => dir;
}

/// D-132: the destructive "start fresh" piece of sign-out — wipes the
/// local pyramid and re-seeds the exact placeholder state a genuinely
/// fresh install starts in.
void main() {
  final db = DatabaseHelper.instance;
  final resetService = LocalPyramidResetService(dbHelper: db);
  late Directory tempDir;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('gp_reset_test');
    PathProviderPlatform.instance = _TempPathProvider(tempDir.path);
  });

  tearDown(() async {
    final sqlDb = await db.database;
    await sqlDb.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test(
      'D-132: wipeLocalPyramid deletes every real category/task/essence/log '
      'row and re-seeds the six "EmptyN" placeholders a fresh install '
      'starts with', () async {
    await db.insertCategory({
      DatabaseHelper.columnCategoryId: 1,
      DatabaseHelper.columnCat: 'Health',
    });
    await db.insertTask({
      DatabaseHelper.columnCategory: 'Health',
      DatabaseHelper.columnTaskDescription: 'Walk',
      DatabaseHelper.columnCreateDate: '2026-09-10',
    });
    await db.insertTaskLog({
      DatabaseHelper.columnTLCategory: 'Health',
      DatabaseHelper.columnTLTaskDescription: 'Walk',
      DatabaseHelper.columnTLChecked: 'true',
      DatabaseHelper.columnTLTaskDate: '2026-09-10',
    });

    await resetService.wipeLocalPyramid();

    final Database sqlDb = await db.database;
    final tasks = await sqlDb.query(DatabaseHelper.taskTable);
    final logs = await sqlDb.query(DatabaseHelper.taskLogTable);
    expect(tasks, isEmpty, reason: 'every real task must be gone after a wipe');
    expect(logs, isEmpty, reason: 'every real task log must be gone after a wipe');
    expect(await db.queryLaunchSetup(), 6,
        reason: 'the category table must be back to the six "EmptyN" '
            'placeholders queryLaunchSetup() uses to route a fresh '
            'install to /setup');
  });

  test(
      'D-132: wipeLocalPyramid never touches demo tables — this must '
      'always wipe the real pyramid regardless of Demo Mode state',
      () async {
    DatabaseHelper.toggleDemoMode();
    addTearDown(() {
      if (DatabaseHelper.isDemoMode) DatabaseHelper.toggleDemoMode();
    });
    await db.insertCategory({
      DatabaseHelper.columnCategoryId: 1,
      DatabaseHelper.columnCat: 'Health',
    });

    await resetService.wipeLocalPyramid();

    final Database sqlDb = await db.database;
    final realCategories = await sqlDb.query(DatabaseHelper.categoryTable);
    expect(realCategories, hasLength(6),
        reason: 'the real category table (not the demo one) must hold '
            'the six re-seeded placeholders');
  });
}
