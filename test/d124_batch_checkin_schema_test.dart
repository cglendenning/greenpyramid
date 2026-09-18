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

/// D-099: a tasklog row's optional voice-transcribed miss reason —
/// schema-shape checks on a fresh install, matching this repo's
/// established convention (`d123_scheduled_habit_schema_test.dart`)
/// rather than simulating a literal version-N-to-N+1 upgrade.
void main() {
  final db = DatabaseHelper.instance;
  late Directory tempDir;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('gp_d124_schema_test');
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

  test('D-099: tasklog gains missreason', () async {
    final cols = await columnsOf(DatabaseHelper.taskLogTable);
    expect(cols, contains(DatabaseHelper.columnTLMissReason));
  });

  test(
      'D-099: recordBatchCheckinResult creates a row when none exists yet '
      'for today — the push may have arrived on a device that never '
      'opened the task list today', () async {
    await db.recordBatchCheckinResult(
      category: 'Health',
      taskDescription: 'Walk 20 minutes',
      taskDate: '2026-09-09',
      checked: true,
    );
    final rows = await db.queryTaskLogByCategory('Health', '2026-09-09');
    expect(rows, hasLength(1));
    expect(rows.single[DatabaseHelper.columnTLChecked], 'true');
    expect(rows.single[DatabaseHelper.columnTLMissReason], isNull);
  });

  test(
      'D-099: a "No" answer records checked=false plus the '
      'voice-transcribed reason', () async {
    await db.recordBatchCheckinResult(
      category: 'Health',
      taskDescription: 'Walk 20 minutes',
      taskDate: '2026-09-09',
      checked: false,
      missReason: 'Got caught up in a meeting.',
    );
    final rows = await db.queryTaskLogByCategory('Health', '2026-09-09');
    expect(rows.single[DatabaseHelper.columnTLChecked], 'false');
    expect(rows.single[DatabaseHelper.columnTLMissReason],
        'Got caught up in a meeting.');
  });

  test(
      'D-099: recordBatchCheckinResult updates an already-existing row '
      'for today rather than creating a duplicate (the UNIQUE constraint '
      'on category+description+date)', () async {
    await db.insertTaskLog({
      DatabaseHelper.columnTLCategory: 'Health',
      DatabaseHelper.columnTLTaskDescription: 'Walk 20 minutes',
      DatabaseHelper.columnTLChecked: 'false',
      DatabaseHelper.columnTLTaskDate: '2026-09-09',
    });

    await db.recordBatchCheckinResult(
      category: 'Health',
      taskDescription: 'Walk 20 minutes',
      taskDate: '2026-09-09',
      checked: true,
    );

    final rows = await db.queryTaskLogByCategory('Health', '2026-09-09');
    expect(rows, hasLength(1));
    expect(rows.single[DatabaseHelper.columnTLChecked], 'true');
  });

  test(
      'D-099: Yes and No use the notification occurrence date, not the '
      'tap date', () {
    final source =
        File('lib/screens/batch_checkin_screen.dart').readAsStringSync();
    expect(source, contains('String get _occurrenceDate'));
    expect(
        RegExp(r'taskDate: _occurrenceDate').allMatches(source), hasLength(2));
    expect(
        source, isNot(contains('taskDate: _dateFmt.format(DateTime.now())')));
  });

  test('D-099: the Yes action has a contrasting label color', () {
    final source =
        File('lib/screens/batch_checkin_screen.dart').readAsStringSync();
    expect(source, contains("label: 'Yes'"));
    expect(source, contains("'YES'"));
    expect(source, contains('Center('));
    expect(source, contains('color: Colors.black'));
  });

  test(
      'D-099-AC-05: a submitted No explains receipt and future use of the note',
      () {
    final source =
        File('lib/screens/batch_checkin_screen.dart').readAsStringSync();
    expect(source, contains('Note received.'));
    expect(source, contains('check-in history to shape future guidance'));
    expect(
        source, contains('Recorded as missed. No explanation was provided.'));
    expect(source, contains('Your note: “\$reason”'));
  });
}
