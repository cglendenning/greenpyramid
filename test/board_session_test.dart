import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/models/board_session.dart';

BoardSession session({
  required BoardSessionType type,
  int? categoryId,
  List<BoardMessage> messages = const [],
}) {
  final now = DateTime(2026, 1, 1);
  return BoardSession(
    sessionId: 's1',
    type: type,
    categoryId: categoryId,
    createdAt: now,
    lastUpdatedAt: now,
    messages: messages,
    rotationOrder: const ['mira', 'kenji', 'noa', 'eli'],
    sliderSettings: const {'mira': 0.5, 'kenji': 0.5, 'noa': 0.5, 'eli': 0.5},
    isComplete: false,
    totalInputTokens: 0,
    totalOutputTokens: 0,
  );
}

BoardMessage msg(String advisorKey) => BoardMessage(
      advisorKey: advisorKey,
      text: 'hello',
      timestamp: DateTime(2026, 1, 1),
    );

void main() {
  group('D-082: session type and category scope are consistent', () {
    test('D-082: a category session requires a categoryId', () {
      expect(
        () => session(type: BoardSessionType.category, categoryId: null),
        throwsA(isA<AssertionError>()),
      );
    });

    test('D-082: a setup session must not carry a categoryId', () {
      expect(
        () => session(type: BoardSessionType.setup, categoryId: 3),
        throwsA(isA<AssertionError>()),
      );
    });

    test('D-082: a setup session with no categoryId constructs fine', () {
      final s = session(type: BoardSessionType.setup, categoryId: null);
      expect(s.type, BoardSessionType.setup);
    });
  });

  group('D-028: rotation and resume, ported from Kansei\'s BoardSession', () {
    test('resumeAction: an empty session retries the opening round', () {
      final s = session(type: BoardSessionType.category, categoryId: 1);
      expect(s.resumeAction, BoardResumeAction.retryOpeningRound);
    });

    test('resumeAction: a complete round of 4 offers to join in', () {
      final s = session(
        type: BoardSessionType.category,
        categoryId: 1,
        messages: ['mira', 'kenji', 'noa', 'eli'].map(msg).toList(),
      );
      expect(s.isRoundComplete, isTrue);
      expect(s.resumeAction, BoardResumeAction.showJoinIn);
    });

    test('resumeAction: an interrupted round resumes mid-round', () {
      final s = session(
        type: BoardSessionType.category,
        categoryId: 1,
        messages: ['mira', 'kenji'].map(msg).toList(),
      );
      expect(s.isRoundComplete, isFalse);
      expect(s.resumeAction, BoardResumeAction.resumeMidRound);
    });

    test('nextAdvisorKey follows rotationOrder by advisor turn count', () {
      final s = session(
        type: BoardSessionType.category,
        categoryId: 1,
        messages: ['mira', 'kenji'].map(msg).toList(),
      );
      expect(s.nextAdvisorKey, 'noa');
    });

    test('user messages do not count toward round tracking', () {
      final s = session(
        type: BoardSessionType.category,
        categoryId: 1,
        messages: [msg('mira'), msg('user'), msg('user')],
      );
      expect(s.advisorMessageCount, 1);
      expect(s.nextAdvisorKey, 'kenji');
    });

    test('withMessage appends without mutating the original session', () {
      final s = session(type: BoardSessionType.category, categoryId: 1);
      final updated = s.withMessage(msg('mira'));
      expect(s.messages, isEmpty);
      expect(updated.messages.length, 1);
    });
  });

  group('Firestore round-trip', () {
    test('toFirestore/fromFirestore-shaped map preserves type and categoryId '
        'for a category session', () {
      final s = session(type: BoardSessionType.category, categoryId: 4);
      final map = s.toFirestore();
      expect(map['type'], 'category');
      expect(map['categoryId'], 4);
    });

    test('toFirestore omits categoryId for a setup session', () {
      final s = session(type: BoardSessionType.setup, categoryId: null);
      final map = s.toFirestore();
      expect(map.containsKey('categoryId'), isFalse);
    });
  });
}
