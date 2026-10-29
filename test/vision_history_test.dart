import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/services/account_reset_service.dart';
import 'package:life_ops/services/auth_service.dart';
import 'package:life_ops/services/council_client.dart';
import 'package:life_ops/services/council_service.dart';
import 'package:life_ops/services/db.dart';
import 'package:life_ops/services/setup_draft_store.dart';
import 'package:life_ops/services/setup_service.dart';
import 'package:life_ops/services/sync_service.dart';
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

void main() {
  final db = DatabaseHelper.instance;
  late Directory tempDir;

  const first = "I'm the kind of person that works out every day.";
  const second = "I'm the kind of person that trains three times a week.";
  const third = "I'm the kind of person that moves with joy.";

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('gp_vision_history_test');
    PathProviderPlatform.instance = _TempPathProvider(tempDir.path);
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() async {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  SetupService buildService() {
    final auth = MockFirebaseAuth(
        signedIn: true, mockUser: MockUser(uid: 'u1', isAnonymous: true));
    final firestore = FakeFirebaseFirestore();
    final client = CouncilClient();
    return SetupService(
      council: CouncilService(firestore: firestore, auth: auth, client: client),
      drafts: SetupDraftStore(db: db, cloud: firestore),
      db: db,
      client: client,
      sync: SyncService(firestore: firestore, db: db),
      auth: AuthService(auth: auth),
      accountReset: AccountResetService(firestore: firestore, auth: auth),
    );
  }

  test(
      'D-042-AC-03: vision history lists every statement newest first, the active '
      'one leading', () async {
    final svc = buildService();
    await db.insertVisionStatement(first);
    await db.insertVisionStatement(second);
    await db.insertVisionStatement(third);

    expect(await svc.visionStatementHistory(), [third, second, first]);
    expect(await db.getLatestVisionStatement(), third);
  });

  test(
      'D-042-AC-03: restoring an earlier statement makes it active and keeps the '
      'full history, listing it once at its newest position', () async {
    final svc = buildService();
    await db.insertVisionStatement(first);
    await db.insertVisionStatement(second);

    final restored = await svc.restoreVisionStatement(first);

    expect(restored, first);
    expect(await db.getLatestVisionStatement(), first);
    expect(await svc.visionStatementHistory(), [first, second]);
    expect(await db.queryVisionStatementHistory(), [first, second, first]);
  });

  test('D-042: an empty history is empty, not an error', () async {
    expect(await buildService().visionStatementHistory(), isEmpty);
  });

  group('D-042-AC-03: the vision screen offers previous statements', () {
    final source = File('lib/screens/setup_screen.dart').readAsStringSync();

    test('the action appears only when there is an earlier statement', () {
      final start = source.indexOf('Widget _buildOpeningVision()');
      final end = source.indexOf('\n  Widget _buildVisionSteering()', start);
      final body = source.substring(start, end);
      expect(body, contains('_visionHistory.length > 1'));
      expect(body, contains("'Previous statements'"));
      expect(body, contains('_showVisionHistory'));
    });

    test('choosing a statement restores it through the service', () {
      final start = source.indexOf('Future<void> _showVisionHistory()');
      final end = source.indexOf('\n  Future<void> _startVisionSteering', start);
      final body = source.substring(start, end);
      expect(body, contains('_setup.restoreVisionStatement(chosen)'));
      expect(body, contains("'Current'"));
      expect(body, contains('_saveDraft()'));
    });

    test('history is refreshed after every new or steered statement', () {
      expect(
          RegExp(r'await _refreshVisionHistory\(\);').allMatches(source).length,
          greaterThanOrEqualTo(4));
    });
  });
}
