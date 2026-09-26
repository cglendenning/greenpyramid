import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
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

void main() {
  final db = DatabaseHelper.instance;
  late Directory tempDir;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('gp_current_day_test');
    PathProviderPlatform.instance = _TempPathProvider(tempDir.path);
  });

  tearDown(() async {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test(
      'current-day task list excludes an existing log when its weekday is disabled',
      () async {
    await db.insertTask({
      DatabaseHelper.columnCategory: 'Health',
      DatabaseHelper.columnTaskDescription: 'Run',
      DatabaseHelper.columnCreateDate: '2026-09-22',
    });
    await db.insertTaskLog({
      DatabaseHelper.columnTLCategory: 'Health',
      DatabaseHelper.columnTLTaskDescription: 'Run',
      DatabaseHelper.columnTLChecked: 'false',
      DatabaseHelper.columnTLTaskDate: '2026-09-22',
    });

    await db.setTaskDayFlag(
      category: 'Health',
      taskDescription: 'Run',
      day: 'tuesday',
      value: false,
    );

    final rows = await db.queryScheduledTaskLogByCategory(
        'Health', '2026-09-22', 'Tuesday');
    expect(rows, isEmpty);
  });

  test('current-day task list keeps a log when its weekday is enabled',
      () async {
    await db.insertTask({
      DatabaseHelper.columnCategory: 'Health',
      DatabaseHelper.columnTaskDescription: 'Run',
      DatabaseHelper.columnCreateDate: '2026-09-22',
    });
    await db.insertTaskLog({
      DatabaseHelper.columnTLCategory: 'Health',
      DatabaseHelper.columnTLTaskDescription: 'Run',
      DatabaseHelper.columnTLChecked: 'false',
      DatabaseHelper.columnTLTaskDate: '2026-09-22',
    });

    final rows = await db.queryScheduledTaskLogByCategory(
        'Health', '2026-09-22', 'Tuesday');
    expect(rows, hasLength(1));
  });

  test('changing today off deletes only today\'s task log', () async {
    final now = DateTime.now();
    final todayDay = DateFormat('EEEE').format(now).toLowerCase();
    final todayDate = DateFormat('yyyy-MM-dd').format(now);

    await db.insertTask({
      DatabaseHelper.columnCategory: 'Health',
      DatabaseHelper.columnTaskDescription: 'Run',
      DatabaseHelper.columnCreateDate: todayDate,
    });
    await db.insertTaskLog({
      DatabaseHelper.columnTLCategory: 'Health',
      DatabaseHelper.columnTLTaskDescription: 'Run',
      DatabaseHelper.columnTLChecked: 'true',
      DatabaseHelper.columnTLTaskDate: todayDate,
    });
    await db.insertTaskLog({
      DatabaseHelper.columnTLCategory: 'Health',
      DatabaseHelper.columnTLTaskDescription: 'Run',
      DatabaseHelper.columnTLChecked: 'false',
      DatabaseHelper.columnTLTaskDate: '2026-01-01',
    });

    await db.setTaskDayFlag(
      category: 'Health',
      taskDescription: 'Run',
      day: todayDay,
      value: false,
    );

    expect(await db.queryTaskLogByCategory('Health', todayDate), isEmpty);
    expect(
      await db.queryTaskLogByCategory('Health', '2026-01-01'),
      hasLength(1),
    );
  });

  test('changing today on recreates today\'s task log when missing', () async {
    final now = DateTime.now();
    final todayDay = DateFormat('EEEE').format(now).toLowerCase();
    final todayDate = DateFormat('yyyy-MM-dd').format(now);

    await db.insertTask({
      DatabaseHelper.columnCategory: 'Health',
      DatabaseHelper.columnTaskDescription: 'Run',
      DatabaseHelper.columnCreateDate: todayDate,
    });

    await db.setTaskDayFlag(
      category: 'Health',
      taskDescription: 'Run',
      day: todayDay,
      value: true,
    );

    final rows = await db.queryTaskLogByCategory('Health', todayDate);
    expect(rows, hasLength(1));
    expect(rows.single[DatabaseHelper.columnTLChecked], 'false');
  });
}
