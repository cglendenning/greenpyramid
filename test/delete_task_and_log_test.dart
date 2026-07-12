import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' as intl;
import 'package:life_ops/db.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Points path_provider at a real temp dir so DatabaseHelper can open its
// SQLite file under the ffi factory during a VM test.
class _TempPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _TempPathProvider(this.dir);
  final String dir;
  @override
  Future<String?> getApplicationDocumentsPath() async => dir;
}

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
    tempDir = await Directory.systemTemp.createTemp('gp_db_test');
    PathProviderPlatform.instance = _TempPathProvider(tempDir.path);
  });

  tearDown(() async {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> addTaskWithTodayLog(String category, String desc) async {
    await db.insertTask({
      DatabaseHelper.columnCategory: category,
      DatabaseHelper.columnTaskDescription: desc,
      DatabaseHelper.columnCreateDate: today,
    });
    await db.insertTaskLog({
      DatabaseHelper.columnTLCategory: category,
      DatabaseHelper.columnTLTaskDescription: desc,
      DatabaseHelper.columnTLChecked: 'false',
      DatabaseHelper.columnTLTaskDate: today,
    });
  }

  test('deleting a task also removes its current-day log entry', () async {
    await addTaskWithTodayLog('Health', 'Run');

    // Sanity: the log entry exists before deletion.
    var log = await db.queryTaskLogByCategory('Health', today);
    expect(log.length, 1);

    await db.deleteTaskAndLog('Health', 'Run');

    final tasks = await db.queryTasksByCategory('Health');
    log = await db.queryTaskLogByCategory('Health', today);
    expect(tasks, isEmpty, reason: 'task definition removed');
    expect(log, isEmpty, reason: "today's log entry removed — the bug");
  });

  test('deletion is scoped to the category', () async {
    await addTaskWithTodayLog('Health', 'Run');
    await addTaskWithTodayLog('Career', 'Run'); // same task name, other category

    await db.deleteTaskAndLog('Health', 'Run');

    final careerTasks = await db.queryTasksByCategory('Career');
    final careerLog = await db.queryTaskLogByCategory('Career', today);
    expect(careerTasks.length, 1, reason: 'other category untouched');
    expect(careerLog.length, 1, reason: 'other category log untouched');
  });
}
