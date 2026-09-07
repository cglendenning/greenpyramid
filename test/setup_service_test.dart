import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/models/board_session.dart';
import 'package:life_ops/services/auth_service.dart';
import 'package:life_ops/services/council_client.dart';
import 'package:life_ops/services/council_service.dart';
import 'package:life_ops/services/db.dart';
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
  List<CategoryProposal> categories = const [
    CategoryProposal(position: 1, name: 'Being present with my kids'),
    CategoryProposal(position: 2, name: 'Financial stability'),
    CategoryProposal(position: 3, name: 'Physical strength'),
    CategoryProposal(position: 4, name: 'Craft'),
    CategoryProposal(position: 5, name: 'Friendship'),
    CategoryProposal(position: 6, name: 'Legacy'),
  ];
  List<String> habits = const ['Walk 20 minutes', 'Drink water', 'Stretch'];
  String vision = 'I am someone who shows up fully for the people I love.';
  List<DomainFinding> findings = const [];

  @override
  Future<List<DomainFinding>> deriveDomainFindings({
    required String sessionId,
    required String categoryName,
    String? essence,
    required List<Map<String, String>> transcript,
    bool isSetup = false,
  }) async =>
      findings;

  List<CategoryProposal>? lastExistingCategories;

  @override
  Future<List<CategoryProposal>> deriveCategories({
    required String sessionId,
    required List<Map<String, String>> transcript,
    List<CategoryProposal>? existingCategories,
  }) async {
    lastExistingCategories = existingCategories;
    return categories;
  }

  @override
  Future<List<String>> deriveHabits({
    required String sessionId,
    required String categoryName,
    String? essence,
    List<String> existingHabits = const [],
  }) async =>
      habits;

  @override
  Future<String> deriveVisionStatement({
    required String sessionId,
    required List<Map<String, String>> essences,
    required List<Map<String, String>> transcript,
  }) async =>
      vision;
}

class _ThrowingCouncilClient extends _FakeCouncilClient {
  @override
  Future<List<DomainFinding>> deriveDomainFindings({
    required String sessionId,
    required String categoryName,
    String? essence,
    required List<Map<String, String>> transcript,
    bool isSetup = false,
  }) async =>
      throw CouncilClientException('backend unavailable');
}

/// R6: SetupService orchestrates the single continuous setup conversation
/// (D-043/D-082) — tested against a real temp SQLite database and a fake
/// Council backend, no live Firebase project.
void main() {
  final db = DatabaseHelper.instance;
  late Directory tempDir;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('gp_setup_test');
    PathProviderPlatform.instance = _TempPathProvider(tempDir.path);
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() async {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  SetupService buildService(
      {_FakeCouncilClient? client, FakeFirebaseFirestore? firestore}) {
    final auth = MockFirebaseAuth(
        signedIn: true, mockUser: MockUser(uid: 'u1', isAnonymous: true));
    final fakeFirestore = firestore ?? FakeFirebaseFirestore();
    final council = CouncilService(firestore: fakeFirestore, auth: auth);
    return SetupService(
      council: council,
      db: db,
      client: client ?? _FakeCouncilClient(),
      sync: SyncService(firestore: fakeFirestore, db: db),
      auth: AuthService(auth: auth),
    );
  }

  group('D-082: exactly one setup session, resumed not duplicated', () {
    test('D-082: startOrResumeSetup creates the setup session on first call',
        () async {
      final svc = buildService();
      final session = await svc.startOrResumeSetup();
      expect(session.type, BoardSessionType.setup);
    });

    test('D-082: a second call resumes the same session', () async {
      final svc = buildService();
      final first = await svc.startOrResumeSetup();
      final second = await svc.startOrResumeSetup();
      expect(second.sessionId, first.sessionId);
    });

    test(
        'D-082: startOrResumeSetup refuses a second session once this '
        'device already has a real local pyramid and the account already '
        'completed one — regression test for owner feedback: repeated '
        'reinstalls accumulated four Firestore setup sessions because only '
        'an *active* session was ever checked, never whether one had ever '
        'been created at all', () async {
      final auth = MockFirebaseAuth(
          signedIn: true, mockUser: MockUser(uid: 'u-real-pyramid', isAnonymous: true));
      final firestore = FakeFirebaseFirestore();
      final council = CouncilService(firestore: firestore, auth: auth);
      final svc = SetupService(
        council: council,
        db: db,
        client: _FakeCouncilClient(),
        sync: SyncService(firestore: firestore, db: db),
        auth: AuthService(auth: auth),
      );

      final first = await svc.startOrResumeSetup();
      await council.endSession(first.sessionId);
      await svc.commitCategories(const [
        CategoryProposal(position: 1, name: 'Health'),
        CategoryProposal(position: 2, name: 'Craft'),
        CategoryProposal(position: 3, name: 'Family'),
        CategoryProposal(position: 4, name: 'Money'),
        CategoryProposal(position: 5, name: 'Friendship'),
        CategoryProposal(position: 6, name: 'Legacy'),
      ]);

      await expectLater(svc.startOrResumeSetup(),
          throwsA(isA<SetupAlreadyCompleteException>()));
    });

    test(
        'D-096: a device with no real local pyramid (e.g. after a '
        'reinstall), same account as one that already completed setup, '
        'restores the cloud pyramid rather than starting a new setup '
        'session', () async {
      final auth = MockFirebaseAuth(
          signedIn: true, mockUser: MockUser(uid: 'u-reinstall', isAnonymous: true));
      final firestore = FakeFirebaseFirestore();
      final council = CouncilService(firestore: firestore, auth: auth);
      final sync = SyncService(firestore: firestore, db: db);
      final authSvc = AuthService(auth: auth);

      // "First install": complete a setup session with a real pyramid,
      // then push it to Firestore the same way real setup completion does.
      final svc1 = SetupService(
          council: council, db: db, client: _FakeCouncilClient(), sync: sync, auth: authSvc);
      final first = await svc1.startOrResumeSetup();
      await council.endSession(first.sessionId);
      await svc1.commitCategories(const [
        CategoryProposal(position: 1, name: 'Health', description: 'my body carries me'),
        CategoryProposal(position: 2, name: 'Craft'),
        CategoryProposal(position: 3, name: 'Family'),
        CategoryProposal(position: 4, name: 'Money'),
        CategoryProposal(position: 5, name: 'Friendship'),
        CategoryProposal(position: 6, name: 'Legacy'),
      ]);
      await svc1.commitEssence(
          categoryId: 1, essence: 'my body carries me', sessionId: first.sessionId);
      await svc1.commitHabits('Health', const ['Walk 20 minutes']);
      await sync.syncAll('u-reinstall', setupComplete: true);

      // "Reinstall": a brand-new local database, same Firestore account.
      final freshDir =
          await Directory.systemTemp.createTemp('gp_setup_test_reinstall');
      addTearDown(() {
        if (freshDir.existsSync()) freshDir.deleteSync(recursive: true);
      });
      PathProviderPlatform.instance = _TempPathProvider(freshDir.path);

      final svc2 = SetupService(
          council: council, db: db, client: _FakeCouncilClient(), sync: sync, auth: authSvc);
      await expectLater(svc2.startOrResumeSetup(),
          throwsA(isA<SetupAlreadyCompleteException>()));

      final restoredCategories = await db.queryCategories();
      expect(restoredCategories.any((c) => c[DatabaseHelper.columnCat] == 'Health'), isTrue);
      final restoredTasks = await db.queryAllTasks();
      expect(restoredTasks.any((t) => t[DatabaseHelper.columnTaskDescription] == 'Walk 20 minutes'),
          isTrue);
    });

    test(
        'D-096: a device with no real local pyramid, and no real cloud '
        'data either (a genuinely new account), starts a fresh setup '
        'session as normal — restore finds nothing and gets out of the '
        'way', () async {
      final svc = buildService();
      final session = await svc.startOrResumeSetup();
      expect(session.type, BoardSessionType.setup);
    });
  });

  group('D-051: category proposals are committed at their proposed '
      'position', () {
    test('D-051: commitCategories writes categoryid = position for a fresh '
        'pyramid', () async {
      final svc = buildService();
      const categories = [
        CategoryProposal(position: 1, name: 'Health'),
        CategoryProposal(position: 2, name: 'Money'),
      ];
      await svc.commitCategories(categories);

      final rows = await db.queryCategories();
      final health = rows.firstWhere((r) => r[DatabaseHelper.columnCat] == 'Health');
      expect(health[DatabaseHelper.columnCategoryId], 1);
      expect(health[DatabaseHelper.columnPosition], 1);
    });

    test('proposeCategories returns the fake backend\'s six proposals',
        () async {
      final client = _FakeCouncilClient();
      final svc = buildService(client: client);
      final session = await svc.startOrResumeSetup();
      final proposed = await svc.proposeCategories(session);
      expect(proposed.length, 6);
      expect(proposed.first.name, 'Being present with my kids');
    });

    test('D-093: proposeCategories passes existingCategories through to the '
        'client as a refinement request', () async {
      final client = _FakeCouncilClient();
      final svc = buildService(client: client);
      final session = await svc.startOrResumeSetup();
      const priorCategories = [
        CategoryProposal(position: 1, name: 'Health', description: 'my body carries me'),
      ];

      await svc.proposeCategories(session, existingCategories: priorCategories);

      expect(client.lastExistingCategories, priorCategories);
    });

    test('D-093: proposeCategories with no existingCategories passes null '
        'through — a fresh derivation, not a refinement', () async {
      final client = _FakeCouncilClient();
      final svc = buildService(client: client);
      final session = await svc.startOrResumeSetup();

      await svc.proposeCategories(session);
      expect(client.lastExistingCategories, isNull);
    });
  });

  group('D-052/D-054: habits are committed scheduled every day', () {
    test('D-054: commitHabits writes every day column true, no '
        'day-of-week selection', () async {
      final svc = buildService();
      await svc.commitHabits('Health', ['Walk 20 minutes']);

      final tasks = await db.queryTasksByCategory('Health');
      final task = tasks.first;
      for (final day in [
        DatabaseHelper.columnSunday,
        DatabaseHelper.columnMonday,
        DatabaseHelper.columnTuesday,
        DatabaseHelper.columnWednesday,
        DatabaseHelper.columnThursday,
        DatabaseHelper.columnFriday,
        DatabaseHelper.columnSaturday,
      ]) {
        expect(task[day], 'true', reason: '$day should default true');
      }
    });

    test('proposeHabits returns the fake backend\'s habit list', () async {
      final client = _FakeCouncilClient();
      final svc = buildService(client: client);
      final session = await svc.startOrResumeSetup();
      final habits = await svc.proposeHabits(
          session: session, categoryName: 'Health', essence: null);
      expect(habits, ['Walk 20 minutes', 'Drink water', 'Stretch']);
    });
  });

  group('D-009/D-028: essence commitment', () {
    test('commitEssence writes a versioned essence for the category',
        () async {
      final svc = buildService();
      await svc.commitEssence(
          categoryId: 1, essence: 'my body carries me', sessionId: 's1');
      final essence = await db.getLatestEssenceForCategory(1);
      expect(essence, 'my body carries me');
    });
  });

  group('D-048: domain finding derivation', () {
    test('recordDomainFindings commits every finding the backend returns',
        () async {
      final client = _FakeCouncilClient()
        ..findings = const [
          DomainFinding(domain: 'biological', note: 'too tired most evenings'),
          DomainFinding(domain: 'relational', note: 'partner feels distant'),
        ];
      final svc = buildService(client: client);
      final session = await svc.startOrResumeSetup();

      await svc.recordDomainFindings(
        session: session,
        categoryId: 1,
        categoryName: 'Health',
        essence: 'my body carries me',
        isSetup: true,
      );

      final saved = await db.queryAllDomainFindings();
      expect(saved.length, 2);
      expect(saved.map((f) => f[DatabaseHelper.columnFindingDomain]),
          containsAll(['biological', 'relational']));
    });

    test('D-074: a session with no impediment named commits nothing — '
        'valid, not an error', () async {
      final svc = buildService();
      final session = await svc.startOrResumeSetup();

      await svc.recordDomainFindings(
        session: session,
        categoryId: 1,
        categoryName: 'Health',
        essence: 'my body carries me',
        isSetup: true,
      );

      expect(await db.queryAllDomainFindings(), isEmpty);
    });

    test('a backend failure is swallowed — never blocks setup progression',
        () async {
      final client = _ThrowingCouncilClient();
      final svc = buildService(client: client);
      final session = await svc.startOrResumeSetup();

      await svc.recordDomainFindings(
        session: session,
        categoryId: 1,
        categoryName: 'Health',
        essence: 'my body carries me',
        isSetup: true,
      );

      expect(await db.queryAllDomainFindings(), isEmpty);
    });
  });

  group('D-055: closing synthesis is written once and persisted locally',
      () {
    test('D-055: closeSynthesis persists the vision statement and ends the '
        'session', () async {
      final client = _FakeCouncilClient();
      final svc = buildService(client: client);
      final session = await svc.startOrResumeSetup();

      final vision = await svc.closeSynthesis(
        session: session,
        essences: const [(categoryName: 'Health', essence: 'my body carries me')],
      );

      expect(vision, client.vision);
      final stored = await db.getLatestVisionStatement();
      expect(stored, client.vision);
    });

    test('D-055: the fixed template opener is never imposed by this layer '
        '— whatever the backend returns is stored verbatim', () async {
      final client = _FakeCouncilClient()..vision = 'a completely different closing line';
      final svc = buildService(client: client);
      final session = await svc.startOrResumeSetup();
      await svc.closeSynthesis(session: session, essences: const []);
      expect(await db.getLatestVisionStatement(), 'a completely different closing line');
    });
  });
}
