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

/// D-123: a habit's optional recurring scheduled time and its native
/// calendar event id — schema-shape checks on a fresh install, matching
/// this repo's established convention (`r3_schema_test.dart`) rather than
/// simulating a literal version-N-to-N+1 upgrade.
void main() {
  final db = DatabaseHelper.instance;
  late Directory tempDir;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('gp_d123_schema_test');
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

  test('D-123: task gains scheduledtime and scheduledcalendareventid',
      () async {
    final cols = await columnsOf(DatabaseHelper.taskTable);
    expect(cols, contains(DatabaseHelper.columnScheduledTime));
    expect(cols, contains(DatabaseHelper.columnScheduledCalendarEventId));
  });

  test('D-123: a habit inserted without a scheduled time defaults to '
      'unscheduled (null), not some other default — today\'s existing '
      'flexible behavior must be exactly what a task gets by default',
      () async {
    final id = await db.insertTask({
      DatabaseHelper.columnCategory: 'Health',
      DatabaseHelper.columnTaskDescription: 'Walk 20 minutes',
      DatabaseHelper.columnCreateDate: '2026-01-01',
    });
    final tasks = await db.queryTasksByCategory('Health');
    final row = tasks.firstWhere((t) => t[DatabaseHelper.columnId] == id);
    expect(row[DatabaseHelper.columnScheduledTime], isNull);
    expect(row[DatabaseHelper.columnScheduledCalendarEventId], isNull);
  });

  test('D-123: scheduling a habit sets both fields; unscheduling clears '
      'both — using the existing generic update(), no bespoke method '
      'needed', () async {
    final id = await db.insertTask({
      DatabaseHelper.columnCategory: 'Health',
      DatabaseHelper.columnTaskDescription: 'Walk 20 minutes',
      DatabaseHelper.columnCreateDate: '2026-01-01',
    });

    await db.update({
      DatabaseHelper.columnId: id,
      DatabaseHelper.columnScheduledTime: '07:00',
      DatabaseHelper.columnScheduledCalendarEventId: 'native-event-123',
    });
    var tasks = await db.queryTasksByCategory('Health');
    var row = tasks.firstWhere((t) => t[DatabaseHelper.columnId] == id);
    expect(row[DatabaseHelper.columnScheduledTime], '07:00');
    expect(row[DatabaseHelper.columnScheduledCalendarEventId],
        'native-event-123');

    await db.update({
      DatabaseHelper.columnId: id,
      DatabaseHelper.columnScheduledTime: null,
      DatabaseHelper.columnScheduledCalendarEventId: null,
    });
    tasks = await db.queryTasksByCategory('Health');
    row = tasks.firstWhere((t) => t[DatabaseHelper.columnId] == id);
    expect(row[DatabaseHelper.columnScheduledTime], isNull);
    expect(row[DatabaseHelper.columnScheduledCalendarEventId], isNull);
  });
}
