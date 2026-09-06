import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' as intl;
import 'package:life_ops/services/db.dart';
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

/// Characterization tests for the completion math.
///
/// These pin the behavior D-024's restructure (R2) must preserve, and enforce
/// D-019: the aggregate score stays an unweighted mean, so tiered weighting
/// must not change either function.
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
    tempDir = await Directory.systemTemp.createTemp('gp_char_test');
    PathProviderPlatform.instance = _TempPathProvider(tempDir.path);
  });

  tearDown(() async {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> addCategory(int id, String name) async {
    await db.insertCategory({
      DatabaseHelper.columnCategoryId: id,
      DatabaseHelper.columnCat: name,
    });
  }

  Future<void> addTask(String category, String desc) async {
    await db.insertTask({
      DatabaseHelper.columnCategory: category,
      DatabaseHelper.columnTaskDescription: desc,
      DatabaseHelper.columnCreateDate: today,
    });
  }

  Future<void> addLog(String category, String desc, bool checked) async {
    await db.insertTaskLog({
      DatabaseHelper.columnTLCategory: category,
      DatabaseHelper.columnTLTaskDescription: desc,
      DatabaseHelper.columnTLChecked: checked ? 'true' : 'false',
      DatabaseHelper.columnTLTaskDate: today,
    });
  }

  group('D-019: getCompletionPercentage', () {
    test('D-019: returns -1 when the category has no tasks defined', () async {
      expect(await db.getCompletionPercentage('Nothing', 7), -1);
    });

    test('D-019: returns 0 when tasks exist but no logs are in range',
        () async {
      await addTask('Health', 'Run');
      expect(await db.getCompletionPercentage('Health', 7), 0);
    });

    test('D-019: is checked logs over total logs, as a truncated percent',
        () async {
      await addTask('Health', 'Run');
      await addTask('Health', 'Lift');
      await addTask('Health', 'Walk');
      await addLog('Health', 'Run', true);
      await addLog('Health', 'Lift', false);
      await addLog('Health', 'Walk', false);
      // 1 of 3 checked -> 33 after int truncation, not 34.
      expect(await db.getCompletionPercentage('Health', 7), 33);
    });

    test('D-019: all checked is 100', () async {
      await addTask('Health', 'Run');
      await addLog('Health', 'Run', true);
      expect(await db.getCompletionPercentage('Health', 7), 100);
    });
  });

  group('D-019: getTotalPercentage is an unweighted mean', () {
    test('D-019: averages categories equally, regardless of tier', () async {
      // Health sits at categoryid 1 (foundational), Legacy at 6 (peak). Tier
      // must not affect the aggregate — that is the whole point of D-019.
      await addCategory(1, 'Health');
      await addCategory(6, 'Legacy');
      await addTask('Health', 'Run');
      await addLog('Health', 'Run', true); // 100
      await addTask('Legacy', 'Write');
      await addLog('Legacy', 'Write', false); // 0
      expect(await db.getTotalPercentage(7), '50');
    });

    test('D-019: categories with no tasks are skipped, not counted as zero',
        () async {
      await addCategory(1, 'Health');
      await addCategory(2, 'Empty');
      await addTask('Health', 'Run');
      await addLog('Health', 'Run', true); // 100
      // 'Empty' has no tasks, so getCompletionPercentage returns -1 and it is
      // skipped rather than averaged in as a zero.
      expect(await db.getTotalPercentage(7), '100');
    });

    test('D-019: returns 0 when no categories exist', () async {
      expect(await db.getTotalPercentage(7), '0');
    });

    test('D-019: only categoryid 1 through 6 are counted', () async {
      await addCategory(1, 'Health');
      await addTask('Health', 'Run');
      await addLog('Health', 'Run', true); // 100
      // categoryid 7 is outside the 1..6 window the aggregate scans.
      await addCategory(7, 'Extra');
      await addTask('Extra', 'Ignored');
      await addLog('Extra', 'Ignored', false); // 0, but must not be counted
      expect(await db.getTotalPercentage(7), '100');
    });
  });
}
