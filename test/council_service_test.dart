import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/models/board_session.dart';
import 'package:life_ops/services/ai_guard.dart';
import 'package:life_ops/services/council_client.dart';
import 'package:life_ops/services/council_service.dart';
import 'package:life_ops/services/db.dart';
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
  AdvisorTurnResult response = const AdvisorTurnResult(
      reply: 'a reply', inputTokens: 10, outputTokens: 5);
  Map<String, dynamic>? lastCategoryContext;
  List<Map<String, String>>? lastConversationHistory;

  List<Map<String, String>>? lastExistingCategories;
  List<Map<String, String?>>? lastPyramidContext;
  bool? lastSoloSetup;

  List<DomainFinding> domainFindingsResponse = const [];
  String? lastDomainFindingsCategoryName;
  List<Map<String, String?>>? lastDomainFindingsPyramidContext;
  bool domainFindingsShouldThrow = false;

  @override
  Future<AdvisorTurnResult> boardAdvisorTurn({
    required String advisorKey,
    required Map<String, dynamic> categoryContext,
    required List<Map<String, String>> conversationHistory,
    double sliderValue = 0.5,
    bool isSetup = false,
    bool soloSetup = false,
    String? sessionId,
    List<Map<String, String>>? existingCategories,
    List<Map<String, String?>>? pyramidContext,
  }) async {
    lastCategoryContext = categoryContext;
    lastConversationHistory = conversationHistory;
    lastExistingCategories = existingCategories;
    lastPyramidContext = pyramidContext;
    lastSoloSetup = soloSetup;
    return response;
  }

  @override
  Future<List<DomainFinding>> deriveDomainFindings({
    required String sessionId,
    String? categoryName,
    String? essence,
    required List<Map<String, String>> transcript,
    bool isSetup = false,
    List<Map<String, String?>>? pyramidContext,
  }) async {
    lastDomainFindingsCategoryName = categoryName;
    lastDomainFindingsPyramidContext = pyramidContext;
    if (domainFindingsShouldThrow) throw CouncilClientException('backend unavailable');
    return domainFindingsResponse;
  }
}

/// R5: Council session orchestration (D-028, D-082), tested against a fake
/// Firestore and Auth — no live Firebase project, no live backend call.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  // D-100: recordDomainFindings' tests exercise real insertDomainFinding
  // calls against sqflite FFI, same convention as
  // query_pyramid_summary_test.dart — no other test in this file touches
  // local SQLite, so this setup is additive and harmless to them.
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('gp_council_service_test');
    PathProviderPlatform.instance = _TempPathProvider(tempDir.path);
  });
  tearDown(() async {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  CouncilService buildService({_FakeCouncilClient? client}) {
    final auth = MockFirebaseAuth(
        signedIn: true, mockUser: MockUser(uid: 'test-uid', isAnonymous: true));
    return CouncilService(
      firestore: FakeFirebaseFirestore(),
      auth: auth,
      client: client ?? _FakeCouncilClient(),
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // AiGuard.instance is a singleton whose per-minute call history is
    // in-memory, not read from SharedPreferences — without this, enough
    // real acquire() calls across this file's whole run trips the 5/min
    // cap regardless of test order.
    AiGuard.instance.resetForTest();
  });

  group('D-082: exactly one setup session may exist per account', () {
    test('D-082: hasEverCreatedSetupSession is false before any session',
        () async {
      final svc = buildService();
      expect(await svc.hasEverCreatedSetupSession(), isFalse);
    });

    test('D-082: hasEverCreatedSetupSession is true once one is created',
        () async {
      final svc = buildService();
      await svc.createSession(type: BoardSessionType.setup);
      expect(await svc.hasEverCreatedSetupSession(), isTrue);
    });
  });

  group('D-028: category sessions are scoped and rotation is randomized', () {
    test('D-028: createSession for a category carries that categoryId',
        () async {
      final svc = buildService();
      final s = await svc.createSession(
          type: BoardSessionType.category, categoryId: 3);
      expect(s.type, BoardSessionType.category);
      expect(s.categoryId, 3);
    });

    test('rotationOrder contains exactly the four advisors', () async {
      final svc = buildService();
      final s = await svc.createSession(
          type: BoardSessionType.category, categoryId: 1);
      expect(s.rotationOrder.toSet(), {'mira', 'kenji', 'noa', 'eli'});
    });

    test('getActiveSession finds the session just created, scoped to its '
        'category', () async {
      final svc = buildService();
      final created = await svc.createSession(
          type: BoardSessionType.category, categoryId: 2);
      final active = await svc.getActiveSession(
          type: BoardSessionType.category, categoryId: 2);
      expect(active?.sessionId, created.sessionId);

      final wrongCategory = await svc.getActiveSession(
          type: BoardSessionType.category, categoryId: 99);
      expect(wrongCategory, isNull);
    });
  });

  group('D-028: an advisor turn is persisted and category context reaches '
      'the client', () {
    test('runAdvisorTurn appends the reply and passes sanitized category '
        'context', () async {
      final client = _FakeCouncilClient();
      final svc = buildService(client: client);
      final session = await svc.createSession(
          type: BoardSessionType.category, categoryId: 1);

      final msg = await svc.runAdvisorTurn(
        session: session,
        advisorKey: 'mira',
        categoryName: 'Health',
        categoryTier: 1,
        priorEssence: 'My body carries me through every challenge.',
      );

      expect(msg?.advisorKey, 'mira');
      expect(msg?.text, 'a reply');
      expect(client.lastCategoryContext?['categoryName'], 'Health');
      expect(client.lastCategoryContext?['categoryTier'], 1);

      final active = await svc.getActiveSession(
          type: BoardSessionType.category, categoryId: 1);
      expect(active?.messages.length, 1);
      expect(active?.totalInputTokens, 10);
      expect(active?.totalOutputTokens, 5);
    });

    test('D-108: with no override, conversationHistory is derived from '
        'session.messages, as before', () async {
      final client = _FakeCouncilClient();
      final svc = buildService(client: client);
      final session = await svc.createSession(
          type: BoardSessionType.category, categoryId: 1);

      await svc.runAdvisorTurn(
          session: session, advisorKey: 'mira', categoryName: 'Health');

      expect(client.lastConversationHistory, isEmpty,
          reason: 'a freshly-created session has no prior messages');
    });

    test('D-108: conversationHistoryOverride replaces the derived history '
        'entirely — this is what lets essence-deepening ask a fresh '
        'question about a new category instead of reacting to another '
        'category\'s leftover closing message, since setup shares one '
        'session across all three foundational categories (D-043)',
        () async {
      final client = _FakeCouncilClient();
      final svc = buildService(client: client);
      var session = await svc.createSession(type: BoardSessionType.setup);
      await svc.appendUserMessage(session.sessionId, 'category 1 stuff');
      session = (await svc.getActiveSession(type: BoardSessionType.setup))!;
      expect(session.messages, isNotEmpty);

      await svc.runAdvisorTurn(
        session: session,
        advisorKey: 'kenji',
        categoryName: 'Fitness Mindset',
        conversationHistoryOverride: const [],
      );

      expect(client.lastConversationHistory, isEmpty,
          reason: 'the override must win over the session\'s real, '
              'non-empty message history');
    });

    test('D-095: runAdvisorTurn passes pyramidContext through, sanitized '
        'the same way any user-derived text reaches a prompt', () async {
      final client = _FakeCouncilClient();
      final svc = buildService(client: client);
      final session = await svc.createSession(type: BoardSessionType.general);

      await svc.runAdvisorTurn(
        session: session,
        advisorKey: 'noa',
        categoryName: 'their life',
        pyramidContext: const [
          {'name': 'Health', 'tier': 'foundational', 'essence': 'my body carries me'},
          {'name': 'Legacy', 'tier': 'peak', 'essence': null},
        ],
      );

      expect(client.lastPyramidContext, hasLength(2));
      expect(client.lastPyramidContext![0]['name'], 'Health');
      expect(client.lastPyramidContext![0]['tier'], 'foundational');
      expect(client.lastPyramidContext![0]['essence'], 'my body carries me');
      expect(client.lastPyramidContext![1]['essence'], isNull);
    });

    test('D-095: runAdvisorTurn with no pyramidContext passes null through '
        '— the category-scoped path is unaffected', () async {
      final client = _FakeCouncilClient();
      final svc = buildService(client: client);
      final session = await svc.createSession(
          type: BoardSessionType.category, categoryId: 1);

      await svc.runAdvisorTurn(
          session: session, advisorKey: 'mira', categoryName: 'Health');
      expect(client.lastPyramidContext, isNull);
    });

    test(
        'D-097: runAdvisorTurn never sets soloSetup, even inside a '
        'setup-typed session — regression test for a defect found live: '
        'essence-deepening (a setup-typed session\'s four-advisor '
        'rotation) was being routed through the solo-Mira pyramid-'
        'building backend logic because isSetup (billing) and the '
        'solo-Mira routing signal used to be the same flag', () async {
      final client = _FakeCouncilClient();
      final svc = buildService(client: client);
      final session = await svc.createSession(type: BoardSessionType.setup);

      await svc.runAdvisorTurn(
          session: session, advisorKey: 'kenji', categoryName: 'Bioenergetics');
      expect(client.lastSoloSetup, isFalse);
    });

    test(
        'D-097: runMiraSetupTurn always sets soloSetup — the one caller '
        'that actually is the solo-Mira pyramid-building conversation',
        () async {
      final client = _FakeCouncilClient();
      final svc = buildService(client: client);
      final session = await svc.createSession(type: BoardSessionType.setup);

      await svc.runMiraSetupTurn(session);
      expect(client.lastSoloSetup, isTrue);
    });
  });

  group('D-090: the solo setup turn persists Mira\'s reply and surfaces '
      'readiness', () {
    test('runMiraSetupTurn appends Mira\'s message and returns readyToBuild',
        () async {
      final client = _FakeCouncilClient()
        ..response = const AdvisorTurnResult(
            reply: 'Tell me more about that.',
            inputTokens: 8,
            outputTokens: 4,
            readyToBuild: false);
      final svc = buildService(client: client);
      final session = await svc.createSession(type: BoardSessionType.setup);

      final result = await svc.runMiraSetupTurn(session);

      expect(result.readyToBuild, isFalse);
      expect(result.session.messages.single.advisorKey, 'mira');
      expect(result.session.messages.single.text, 'Tell me more about that.');

      final active =
          await svc.getActiveSession(type: BoardSessionType.setup);
      expect(active?.messages.length, 1);
      expect(active?.totalInputTokens, 8);
    });

    test('runMiraSetupTurn surfaces readyToBuild: true once the client '
        'signals it', () async {
      final client = _FakeCouncilClient()
        ..response = const AdvisorTurnResult(
            reply: 'I have what I need — let\'s build this.',
            inputTokens: 8,
            outputTokens: 4,
            readyToBuild: true);
      final svc = buildService(client: client);
      final session = await svc.createSession(type: BoardSessionType.setup);

      final result = await svc.runMiraSetupTurn(session);
      expect(result.readyToBuild, isTrue);
    });

    test('D-093: runMiraSetupTurn passes existingCategories through to the '
        'client as a refinement signal', () async {
      final client = _FakeCouncilClient();
      final svc = buildService(client: client);
      final session = await svc.createSession(type: BoardSessionType.setup);

      await svc.runMiraSetupTurn(session, existingCategories: const [
        CategoryProposal(position: 1, name: 'Health', description: 'my body carries me'),
      ]);

      expect(client.lastExistingCategories, hasLength(1));
      expect(client.lastExistingCategories!.single['name'], 'Health');
      expect(client.lastExistingCategories!.single['description'], 'my body carries me');
    });

    test('D-093: runMiraSetupTurn with no existingCategories passes null '
        'through — a fresh build, not a refinement', () async {
      final client = _FakeCouncilClient();
      final svc = buildService(client: client);
      final session = await svc.createSession(type: BoardSessionType.setup);

      await svc.runMiraSetupTurn(session);
      expect(client.lastExistingCategories, isNull);
    });
  });

  group('D-093: a fixed advisor line can be appended without a model call',
      () {
    test('appendAdvisorMessage persists the given text under the given '
        'advisor key, at zero token cost', () async {
      final svc = buildService();
      final session = await svc.createSession(type: BoardSessionType.setup);

      final msg = await svc.appendAdvisorMessage(
          session.sessionId, 'mira', "What didn't feel right about this?");

      expect(msg.advisorKey, 'mira');
      expect(msg.text, "What didn't feel right about this?");

      final active = await svc.getActiveSession(type: BoardSessionType.setup);
      expect(active?.messages.single.text, "What didn't feel right about this?");
      expect(active?.totalInputTokens, 0);
      expect(active?.totalOutputTokens, 0);
    });
  });

  group('D-028: ending a session removes it from the active set', () {
    test('endSession marks isComplete and it drops out of getActiveSession',
        () async {
      final svc = buildService();
      final session = await svc.createSession(
          type: BoardSessionType.category, categoryId: 1);
      await svc.endSession(session.sessionId);

      final active = await svc.getActiveSession(
          type: BoardSessionType.category, categoryId: 1);
      expect(active, isNull);

      final completed =
          await svc.getCompletedSessions(type: BoardSessionType.category, categoryId: 1);
      expect(completed.map((s) => s.sessionId), contains(session.sessionId));
    });
  });

  group('D-032/D-042: session access before sign-in resolves', () {
    // Regression test for the setup-screen startup race: main.dart kicks
    // off anonymous sign-in unawaited so it never gates the first frame
    // (D-032), but SetupScreen's own load path must never reach Firestore
    // before that sign-in has actually completed — on a device with no
    // cached Firebase Auth session (a fresh install), losing this race
    // surfaced in production as "Could not start setup." This test pins
    // the invariant SetupScreen._load() depends on: createSession and
    // getActiveSession fail fast, rather than silently succeeding as some
    // other uid, when there is no authenticated user yet.
    test('createSession throws StateError, not a Firestore call, when no '
        'user is signed in', () async {
      final svc = CouncilService(
        firestore: FakeFirebaseFirestore(),
        auth: MockFirebaseAuth(), // signedIn: false by default
        client: _FakeCouncilClient(),
      );
      await expectLater(
        svc.createSession(type: BoardSessionType.setup),
        throwsA(isA<StateError>()),
      );
    });

    test('getActiveSession throws StateError, not a Firestore call, when no '
        'user is signed in', () async {
      final svc = CouncilService(
        firestore: FakeFirebaseFirestore(),
        auth: MockFirebaseAuth(),
        client: _FakeCouncilClient(),
      );
      await expectLater(
        svc.getActiveSession(type: BoardSessionType.setup),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('D-048/D-100: recordDomainFindings', () {
    BoardSession testSession() => BoardSession(
          sessionId: 's1',
          type: BoardSessionType.general,
          categoryId: null,
          createdAt: DateTime(2026, 1, 1),
          lastUpdatedAt: DateTime(2026, 1, 1),
          messages: const [],
          rotationOrder: const ['mira', 'kenji', 'noa', 'eli'],
          sliderSettings: const {},
          isComplete: false,
          totalInputTokens: 0,
          totalOutputTokens: 0,
        );

    test('single-category shape: findings are inserted against the given '
        'categoryId — the pre-existing setup/re-clarification path, '
        'unchanged by the D-100 refactor', () async {
      final client = _FakeCouncilClient()
        ..domainFindingsResponse = const [
          DomainFinding(domain: 'psychological', note: 'a note'),
        ];
      final svc = buildService(client: client);

      await svc.recordDomainFindings(
        session: testSession(),
        isSetup: true,
        categoryId: 42,
        categoryName: 'Health',
        essence: 'my body carries me',
      );

      expect(client.lastDomainFindingsCategoryName, 'Health');
      expect(client.lastDomainFindingsPyramidContext, isNull);
      final findings = await DatabaseHelper.instance.queryAllDomainFindings();
      expect(findings, hasLength(1));
      expect(findings.single[DatabaseHelper.columnFindingCategoryId], 42);
      expect(findings.single[DatabaseHelper.columnFindingDomain], 'psychological');
    });

    test('pyramidContext shape: a finding is resolved to the real '
        'categoryId by matching the model\'s categoryName against '
        'pyramidContext', () async {
      final client = _FakeCouncilClient()
        ..domainFindingsResponse = const [
          DomainFinding(domain: 'psychological', note: 'a note', categoryName: 'Box Breathing'),
        ];
      final svc = buildService(client: client);

      await svc.recordDomainFindings(
        session: testSession(),
        isSetup: false,
        pyramidContext: [
          {'id': 7, 'name': 'Box Breathing', 'tier': 'foundational', 'essence': 'skipped when grinding'},
          {'id': 8, 'name': 'Peak Physical Condition', 'tier': 'foundational', 'essence': 'load-bearing walls'},
        ],
      );

      expect(client.lastDomainFindingsCategoryName, isNull);
      expect(client.lastDomainFindingsPyramidContext, hasLength(2));
      final findings = await DatabaseHelper.instance.queryAllDomainFindings();
      expect(findings.single[DatabaseHelper.columnFindingCategoryId], 7);
    });

    test('pyramidContext shape: a finding naming a category that doesn\'t '
        'match any given category is dropped, never guessed at', () async {
      final client = _FakeCouncilClient()
        ..domainFindingsResponse = const [
          DomainFinding(domain: 'psychological', note: 'a note', categoryName: 'Not A Real Category'),
        ];
      final svc = buildService(client: client);

      await svc.recordDomainFindings(
        session: testSession(),
        isSetup: false,
        pyramidContext: [
          {'id': 7, 'name': 'Box Breathing', 'tier': 'foundational', 'essence': null},
        ],
      );

      expect(await DatabaseHelper.instance.queryAllDomainFindings(), isEmpty);
    });

    test('a backend failure is swallowed — advisory, never blocks the '
        'caller (D-074)', () async {
      final client = _FakeCouncilClient()..domainFindingsShouldThrow = true;
      final svc = buildService(client: client);

      await expectLater(
        svc.recordDomainFindings(
          session: testSession(),
          isSetup: false,
          pyramidContext: const [],
        ),
        completes,
      );
    });
  });
}
