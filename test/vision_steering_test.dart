import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/services/account_reset_service.dart';
import 'package:life_ops/services/ai_guard.dart';
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

class _FakeCouncilClient extends CouncilClient {
  String vision = "I'm the kind of person that works out every day.";
  String question =
      'Was it the part about working out every day, or something else?';
  String regenerated = "I'm the kind of person that trains three times a week.";
  Map<String, Object?>? lastSteering;

  @override
  Future<String> deriveVisionStatement({
    required List<Map<String, String>> essences,
    required bool isSetup,
    String? sessionId,
    List<Map<String, String>>? transcript,
  }) async =>
      vision;

  @override
  Future<String> deriveVisionSteeringQuestion({
    required String sessionId,
    required String vision,
  }) async =>
      question;

  @override
  Future<String> regenerateVisionStatement({
    required String sessionId,
    required List<Map<String, String>> transcript,
    required String previousVision,
    required String question,
    required String feedback,
  }) async {
    lastSteering = {
      'sessionId': sessionId,
      'previousVision': previousVision,
      'question': question,
      'feedback': feedback,
    };
    return regenerated;
  }
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
    tempDir = await Directory.systemTemp.createTemp('gp_vision_steering_test');
    PathProviderPlatform.instance = _TempPathProvider(tempDir.path);
    SharedPreferences.setMockInitialValues({});
    AiGuard.instance.resetForTest();
  });
  tearDown(() async {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  SetupService buildService(_FakeCouncilClient client) {
    final auth = MockFirebaseAuth(
        signedIn: true, mockUser: MockUser(uid: 'u1', isAnonymous: true));
    final firestore = FakeFirebaseFirestore();
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
      'D-093-AC-04: a steered regeneration replaces the stored initial vision, so '
      'at most one initial vision is accepted', () async {
    final client = _FakeCouncilClient();
    final svc = buildService(client);
    final session = await svc.startOrResumeSetup();
    final first = await svc.deriveOpeningVisionStatement(session);

    final regenerated = await svc.regenerateOpeningVisionStatement(session,
        previousVision: first,
        question: client.question,
        feedback: 'I train three times a week, not every day.');

    expect(regenerated, client.regenerated);
    expect(await db.getLatestVisionStatement(), client.regenerated);
  });

  test(
      'D-093-AC-04: the steering request carries the previous statement, the '
      'question asked and the sanitized answer for the same session',
      () async {
    final client = _FakeCouncilClient();
    final svc = buildService(client);
    final session = await svc.startOrResumeSetup();

    await svc.regenerateOpeningVisionStatement(session,
        previousVision: client.vision,
        question: client.question,
        feedback: 'Not every day "really"');

    expect(client.lastSteering?['sessionId'], session.sessionId);
    expect(client.lastSteering?['previousVision'], client.vision);
    expect(client.lastSteering?['question'], client.question);
    expect(client.lastSteering?['feedback'],
        AiGuard.sanitizeField('Not every day "really"', maxChars: 1000));
  });

  test('D-093-AC-04: an empty steering question is an error, not a blank bubble',
      () async {
    final client = _FakeCouncilClient()..question = '';
    final svc = buildService(client);
    final session = await svc.startOrResumeSetup();

    expect(() => svc.deriveVisionSteeringQuestion(session, client.vision),
        throwsA(isA<CouncilClientException>()));
  });

  group('D-093-AC-04: the vision screen offers one steering turn', () {
    final source = File('lib/screens/setup_screen.dart').readAsStringSync();

    test('a "Change this statement" action sits under Next', () {
      final start = source.indexOf('Widget _buildOpeningVision()');
      final end = source.indexOf('\n  Widget _buildVisionSteering()', start);
      final body = source.substring(start, end);
      expect(body, contains("'Change this statement'"));
      expect(body, contains('_startVisionSteering'));
      expect(body.indexOf("'Next'"),
          lessThan(body.indexOf("'Change this statement'")));
    });

    test('the reply box appears only for the single steering answer', () {
      final getter = source.indexOf('bool get _awaitingVisionSteeringReply');
      expect(getter, greaterThan(-1));
      final body = source.substring(getter, source.indexOf(';', getter));
      expect(body, contains('_visionSteeringQuestion != null'));
      expect(body, contains('_visionSteeringReply == null'));
    });

    test('the answer goes straight to regeneration, which ends steering', () {
      final start = source.indexOf('Future<void> _regenerateSteeredVision()');
      final end = source.indexOf('\n  void _cancelVisionSteering', start);
      final body = source.substring(start, end);
      expect(body, contains('regenerateOpeningVisionStatement'));
      expect(body, contains('_visionSteering = false'));
    });

    test('steering can be cancelled, keeping the current statement', () {
      expect(source, contains("'Keep the current statement'"));
      final start = source.indexOf('void _cancelVisionSteering()');
      final body = source.substring(start, source.indexOf('});', start));
      expect(body, isNot(contains('_visionStatement =')));
    });
  });
}
