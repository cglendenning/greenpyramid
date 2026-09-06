import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/models/board_session.dart';
import 'package:life_ops/services/council_client.dart';
import 'package:life_ops/services/council_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeCouncilClient extends CouncilClient {
  AdvisorTurnResult response = const AdvisorTurnResult(
      reply: 'a reply', inputTokens: 10, outputTokens: 5);
  Map<String, dynamic>? lastCategoryContext;

  @override
  Future<AdvisorTurnResult> boardAdvisorTurn({
    required String advisorKey,
    required Map<String, dynamic> categoryContext,
    required List<Map<String, String>> conversationHistory,
    double sliderValue = 0.5,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    lastCategoryContext = categoryContext;
    return response;
  }
}

/// R5: Council session orchestration (D-028, D-082), tested against a fake
/// Firestore and Auth — no live Firebase project, no live backend call.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
}
