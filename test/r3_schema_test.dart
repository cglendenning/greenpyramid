import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' as intl;
import 'package:life_ops/services/db.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _TempPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _TempPathProvider(this.dir);
  final String dir;
  @override
  Future<String?> getApplicationDocumentsPath() async => dir;
}

/// R3: the Part IV schema and the D-084 rename cascade.
///
/// This is the highest data-risk release in the sequence, so the migration is
/// tested for idempotence and for leaving existing data intact, not just for
/// producing the right columns.
void main() {
  final db = DatabaseHelper.instance;
  final today = intl.DateFormat('yyyy-MM-dd').format(DateTime.now());
  late Directory tempDir;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('gp_r3_test');
    PathProviderPlatform.instance = _TempPathProvider(tempDir.path);
  });
  tearDown(() async {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<Set<String>> columnsOf(String table) async {
    final d = await db.database;
    final info = await d.rawQuery('PRAGMA table_info($table)');
    return info.map((c) => c['name'] as String).toSet();
  }

  group('Part IV: the v7 schema exists', () {
    test('Part IV: category gains position and created', () async {
      final cols = await columnsOf(DatabaseHelper.categoryTable);
      expect(cols, containsAll([
        DatabaseHelper.columnPosition,
        DatabaseHelper.columnCategoryCreated,
      ]));
    });

    test('Part IV: category_essence has its documented columns', () async {
      final cols = await columnsOf(DatabaseHelper.categoryEssenceTable);
      expect(cols, containsAll([
        DatabaseHelper.columnEssenceCategoryId,
        DatabaseHelper.columnEssenceText,
        DatabaseHelper.columnEssenceCreated,
        DatabaseHelper.columnEssenceSourceSession,
      ]));
    });

    test('Part IV: domain_finding has its documented columns', () async {
      final cols = await columnsOf(DatabaseHelper.domainFindingTable);
      expect(cols, containsAll([
        DatabaseHelper.columnFindingCategoryId,
        DatabaseHelper.columnFindingDomain,
        DatabaseHelper.columnFindingNote,
        DatabaseHelper.columnFindingCreated,
      ]));
    });

    test('Part IV: account_state is seeded with exactly one row', () async {
      final d = await db.database;
      final rows = await d.query(DatabaseHelper.accountStateTable);
      expect(rows.length, 1);
      expect(rows.first[DatabaseHelper.columnEntitlement], 'pre_trial');
    });

    test('Part IV: account_state cannot hold a second row', () async {
      final d = await db.database;
      await expectLater(
        d.insert(DatabaseHelper.accountStateTable,
            {DatabaseHelper.columnAccountId: 2}),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  group('MIG-4: the migration is idempotent', () {
    test('MIG-4: applyV7Schema can be re-run without error', () async {
      final d = await db.database;
      await DatabaseHelper.applyV7Schema(d);
      await DatabaseHelper.applyV7Schema(d);
      final rows = await d.query(DatabaseHelper.accountStateTable);
      expect(rows.length, 1, reason: 're-running must not duplicate the row');
    });
  });

  group('MIG-3: existing data survives', () {
    test('MIG-3: position is backfilled from categoryid', () async {
      await db.insertCategory({
        DatabaseHelper.columnCategoryId: 3,
        DatabaseHelper.columnCat: 'Craft',
      });
      final d = await db.database;
      await DatabaseHelper.applyV7Schema(d);
      final rows = await d.query(DatabaseHelper.categoryTable,
          where: '${DatabaseHelper.columnCategoryId} = ?', whereArgs: [3]);
      expect(rows.first[DatabaseHelper.columnPosition], 3);
    });
  });

  group('D-084: renaming a category cascades', () {
    Future<void> seed(String category) async {
      await db.insertCategory({
        DatabaseHelper.columnCategoryId: 1,
        DatabaseHelper.columnCat: category,
      });
      await db.insertTask({
        DatabaseHelper.columnCategory: category,
        DatabaseHelper.columnTaskDescription: 'Run',
        DatabaseHelper.columnCreateDate: today,
      });
      await db.insertTaskLog({
        DatabaseHelper.columnTLCategory: category,
        DatabaseHelper.columnTLTaskDescription: 'Run',
        DatabaseHelper.columnTLChecked: 'true',
        DatabaseHelper.columnTLTaskDate: today,
      });
    }

    test('D-084: habits follow the category to its new name', () async {
      await seed('Health');
      await db.renameCategoryCascading(categoryid: 1, newName: 'Vitality');
      final d = await db.database;
      final tasks = await d.query(DatabaseHelper.taskTable,
          where: '${DatabaseHelper.columnCategory} = ?',
          whereArgs: ['Vitality']);
      expect(tasks.length, 1,
          reason: 'without the cascade this habit would be orphaned (II-N)');
      final orphans = await d.query(DatabaseHelper.taskTable,
          where: '${DatabaseHelper.columnCategory} = ?', whereArgs: ['Health']);
      expect(orphans, isEmpty);
    });

    test('D-084: log history follows the rename too', () async {
      await seed('Health');
      await db.renameCategoryCascading(categoryid: 1, newName: 'Vitality');
      final d = await db.database;
      final logs = await d.query(DatabaseHelper.taskLogTable,
          where: '${DatabaseHelper.columnTLCategory} = ?',
          whereArgs: ['Vitality']);
      expect(logs.length, 1);
    });

    test('D-084: a name with an apostrophe does not break the rename',
        () async {
      // Previously this was interpolated into SQL and would have broken the
      // statement outright (D-024, R2).
      await seed('Health');
      await db.renameCategoryCascading(
          categoryid: 1, newName: "Craig's Health");
      final d = await db.database;
      final tasks = await d.query(DatabaseHelper.taskTable,
          where: '${DatabaseHelper.columnCategory} = ?',
          whereArgs: ["Craig's Health"]);
      expect(tasks.length, 1);
    });

    test('D-084: renaming to the same name is a no-op', () async {
      await seed('Health');
      await db.renameCategoryCascading(categoryid: 1, newName: 'Health');
      final d = await db.database;
      final tasks = await d.query(DatabaseHelper.taskTable);
      expect(tasks.length, 1);
    });
  });

  group('D-086: migration is best-effort, failure is surfaced', () {
    test('D-086: a healthy open leaves no recorded failure', () async {
      await db.database;
      expect(DatabaseHelper.openFailure, isNull);
    });

    test('D-086: the recovery screen tells the user what to do', () {
      final src =
          File('lib/screens/database_recovery_screen.dart').readAsStringSync();
      // It must say what happened, what to do, and must not promise recovery.
      expect(src.contains('delete Green Pyramid'), isTrue);
      expect(src.contains('cannot '), isTrue);
      expect(src.toLowerCase().contains('sorry'), isFalse,
          reason: 'state the situation, do not apologise');
    });

    test('D-086: startup routes to recovery instead of crashing', () {
      final main = File('lib/main.dart').readAsStringSync();
      expect(main.contains('DatabaseRecoveryScreen'), isTrue);
      expect(main.contains('catch'), isTrue,
          reason: 'database failure must be caught, never swallowed');
    });
  });
}
