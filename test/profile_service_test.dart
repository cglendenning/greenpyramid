import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/services/ai_guard.dart';
import 'package:life_ops/services/council_client.dart';
import 'package:life_ops/services/db.dart';
import 'package:life_ops/services/profile_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _TempPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _TempPathProvider(this.dir);
  final String dir;
  @override
  Future<String?> getApplicationDocumentsPath() async => dir;
}

class _FakeCouncilClient extends CouncilClient {
  List<Map<String, String>>? lastVisionEssences;
  bool? lastVisionIsSetup;
  String? lastVisionSessionId;
  List<Map<String, String>>? lastVisionTranscript;
  String visionResult = 'I am becoming someone who follows through.';

  List<Map<String, String>>? lastProgressTaskLogs;
  String progressResult = 'You showed up for Health four times this week.';

  Object? throwOnVision;
  Object? throwOnProgress;

  @override
  Future<String> deriveVisionStatement({
    required List<Map<String, String>> essences,
    required bool isSetup,
    String? sessionId,
    List<Map<String, String>>? transcript,
  }) async {
    if (throwOnVision != null) throw throwOnVision!;
    lastVisionEssences = essences;
    lastVisionIsSetup = isSetup;
    lastVisionSessionId = sessionId;
    lastVisionTranscript = transcript;
    return visionResult;
  }

  @override
  Future<String> deriveProgressAnalysis({
    required List<Map<String, String>> taskLogs,
  }) async {
    if (throwOnProgress != null) throw throwOnProgress!;
    lastProgressTaskLogs = taskLogs;
    return progressResult;
  }
}

/// D-114: ProfileService wires the profile screen's two AI features
/// (regenerating the vision statement, the 30-day progress analysis) onto
/// Claude — tested against a real temp SQLite database and a fake Council
/// backend, no live network.
void main() {
  final db = DatabaseHelper.instance;
  late Directory tempDir;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('gp_profile_test');
    PathProviderPlatform.instance = _TempPathProvider(tempDir.path);
    SharedPreferences.setMockInitialValues({});
    AiGuard.instance.resetForTest();
  });
  tearDown(() async {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test(
      'D-114: regenerateVisionStatement sends only the pyramid\'s current '
      'essences, isSetup: false, and no sessionId/transcript — this is a '
      'regeneration outside any live Council conversation', () async {
    await db.insertCategory({
      DatabaseHelper.columnCategoryId: 1,
      DatabaseHelper.columnCat: 'Health',
      DatabaseHelper.columnPosition: 1,
      DatabaseHelper.columnCategoryCreated: DateTime.now().toIso8601String(),
    });
    await db.insertCategoryEssence(
        categoryId: 1, essence: 'my body carries me', sourceSessionId: 's1');
    await db.insertCategory({
      DatabaseHelper.columnCategoryId: 2,
      DatabaseHelper.columnCat: 'Craft',
      DatabaseHelper.columnPosition: 2,
      DatabaseHelper.columnCategoryCreated: DateTime.now().toIso8601String(),
    });

    final client = _FakeCouncilClient();
    final svc = ProfileService(db: db, client: client);
    final vision = await svc.regenerateVisionStatement();

    expect(vision, client.visionResult);
    expect(client.lastVisionIsSetup, false);
    expect(client.lastVisionSessionId, isNull);
    expect(client.lastVisionTranscript, isNull);
    expect(client.lastVisionEssences,
        [{'categoryName': 'Health', 'essence': 'my body carries me'}]);
  });

  test(
      'D-114: regenerateVisionStatement omits a category with no essence '
      'yet rather than sending a null one — D-010\'s normal state for a '
      'category that hasn\'t been deepened', () async {
    await db.insertCategory({
      DatabaseHelper.columnCategoryId: 1,
      DatabaseHelper.columnCat: 'Craft',
      DatabaseHelper.columnPosition: 1,
      DatabaseHelper.columnCategoryCreated: DateTime.now().toIso8601String(),
    });
    final client = _FakeCouncilClient();
    final svc = ProfileService(db: db, client: client);
    await svc.regenerateVisionStatement();
    expect(client.lastVisionEssences, isEmpty);
  });

  test(
      'D-114: generateProgressAnalysis sanitizes and shapes each task_log '
      'row into date/category/taskDescription/checked before sending it',
      () async {
    // queryTaskLogs(30) excludes today (its upper bound is a strict "<
    // today"), so this uses yesterday to land inside the window.
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    await db.insertTaskLog({
      DatabaseHelper.columnTLCategory: 'Health',
      DatabaseHelper.columnTLTaskDescription: 'Walk 20 minutes',
      DatabaseHelper.columnTLChecked: 'true',
      DatabaseHelper.columnTLTaskDate:
          yesterday.toIso8601String().substring(0, 10),
    });

    final client = _FakeCouncilClient();
    final svc = ProfileService(db: db, client: client);
    final analysis = await svc.generateProgressAnalysis();

    expect(analysis, client.progressResult);
    expect(client.lastProgressTaskLogs, hasLength(1));
    final row = client.lastProgressTaskLogs!.single;
    expect(row['category'], 'Health');
    expect(row['taskDescription'], 'Walk 20 minutes');
    expect(row['checked'], 'true');
  });

  test(
      'D-114: generateProgressAnalysis bounds task_log data to '
      'AiGuard.maxTaskLogRows — D-075\'s same cap on how much task_log '
      'data any AI surface may see, kept to the most recent rows', () async {
    final now = DateTime.now();
    for (var i = 0; i < AiGuard.maxTaskLogRows + 10; i++) {
      // Cycled within the last 28 days, all inside queryTaskLogs(30)'s
      // window — distinguished by taskDescription (part of the table's
      // UNIQUE constraint), not by date, so every insert survives.
      await db.insertTaskLog({
        DatabaseHelper.columnTLCategory: 'Health',
        DatabaseHelper.columnTLTaskDescription: 'Task $i',
        DatabaseHelper.columnTLChecked: 'true',
        DatabaseHelper.columnTLTaskDate: now
            .subtract(Duration(days: (i % 28) + 1))
            .toIso8601String()
            .substring(0, 10),
      });
    }
    final client = _FakeCouncilClient();
    final svc = ProfileService(db: db, client: client);
    await svc.generateProgressAnalysis();
    expect(client.lastProgressTaskLogs!.length,
        lessThanOrEqualTo(AiGuard.maxTaskLogRows));
  });

  test(
      'D-114: a spend-limit refusal from the backend propagates unchanged '
      'out of regenerateVisionStatement — the screen distinguishes it from '
      'a generic failure', () async {
    final client = _FakeCouncilClient()
      ..throwOnVision =
          SpendLimitException(totalSpendUsd: 5.0, spendCapUsd: 5.0);
    final svc = ProfileService(db: db, client: client);
    await expectLater(
        svc.regenerateVisionStatement(), throwsA(isA<SpendLimitException>()));
  });

  test(
      'D-114: saveVisionStatement/loadVisionStatement round-trip through '
      'the local database', () async {
    final svc = ProfileService(db: db, client: _FakeCouncilClient());
    expect(await svc.loadVisionStatement(), isNull);
    await svc.saveVisionStatement('I show up fully.');
    expect(await svc.loadVisionStatement(), 'I show up fully.');
  });
}
