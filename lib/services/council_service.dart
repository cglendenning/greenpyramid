import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import '../models/board_session.dart';
import 'ai_guard.dart';
import 'council_client.dart';

/// D-028/D-082: orchestrates Council sessions, ported from Kansei's
/// `BoardService`. Sessions live flat under `users/{uid}/councilSessions`
/// (IV-D) rather than nested per-goal — this is what resolves II-K
/// mismatches 1 and 3 (persistence and scope) for Green Pyramid.
class CouncilService {
  CouncilService({FirebaseFirestore? firestore, FirebaseAuth? auth, CouncilClient? client})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _client = client ?? CouncilClient.instance;

  static final CouncilService instance = CouncilService();

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final CouncilClient _client;
  static const _uuid = Uuid();

  String get _uid {
    final u = _auth.currentUser;
    if (u == null) throw StateError('CouncilService: no authenticated user');
    return u.uid;
  }

  CollectionReference<Map<String, dynamic>> get _sessionsCol =>
      _db.collection('users').doc(_uid).collection('councilSessions');

  /// D-082: exactly one `setup` session may exist per account, ever. Callers
  /// check this before offering setup — a second attempt is a `category`
  /// session or is refused, never a second `setup` session.
  Future<bool> hasEverCreatedSetupSession() async {
    final snap = await _sessionsCol
        .where('type', isEqualTo: BoardSessionType.setup.name)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  Future<BoardSession?> getActiveSession({
    required BoardSessionType type,
    int? categoryId,
  }) async {
    var query = _sessionsCol
        .where('type', isEqualTo: type.name)
        .where('isComplete', isEqualTo: false);
    if (categoryId != null) {
      query = query.where('categoryId', isEqualTo: categoryId);
    }
    final snap = await query.get();
    if (snap.docs.isEmpty) return null;
    // Sort client-side — avoids a composite index on (type, isComplete, categoryId, createdAt).
    final docs = snap.docs
      ..sort((a, b) {
        final aT = (a.data()['createdAt'] as Timestamp).toDate();
        final bT = (b.data()['createdAt'] as Timestamp).toDate();
        return bT.compareTo(aT);
      });
    return BoardSession.fromFirestore(docs.first);
  }

  Future<List<BoardSession>> getCompletedSessions({
    required BoardSessionType type,
    int? categoryId,
  }) async {
    var query = _sessionsCol
        .where('type', isEqualTo: type.name)
        .where('isComplete', isEqualTo: true);
    if (categoryId != null) {
      query = query.where('categoryId', isEqualTo: categoryId);
    }
    final snap = await query.get();
    final sessions = snap.docs.map(BoardSession.fromFirestore).toList();
    sessions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sessions;
  }

  Future<BoardSession> createSession({
    required BoardSessionType type,
    int? categoryId,
  }) async {
    final id = _uuid.v4();
    final order = [...AdvisorRotation.keys]..shuffle(Random());
    final now = DateTime.now();
    final session = BoardSession(
      sessionId: id,
      type: type,
      categoryId: categoryId,
      createdAt: now,
      lastUpdatedAt: now,
      messages: const [],
      rotationOrder: order,
      sliderSettings: const {'mira': 0.5, 'kenji': 0.5, 'noa': 0.5, 'eli': 0.5},
      isComplete: false,
      totalInputTokens: 0,
      totalOutputTokens: 0,
    );
    await _sessionsCol.doc(id).set(session.toFirestore());
    return session;
  }

  /// Calls the backend for one advisor turn, persists the message, and
  /// returns it. [categoryName], [categoryTier], and [priorEssence] are the
  /// category-scoped context D-028 requires; sanitized the same way any
  /// user-derived text reaches a prompt (D-006).
  Future<BoardMessage?> runAdvisorTurn({
    required BoardSession session,
    required String advisorKey,
    required String categoryName,
    int? categoryTier,
    String? priorEssence,
  }) async {
    await AiGuard.instance.acquire();

    final sliderValue = session.sliderSettings[advisorKey] ?? 0.5;
    final result = await _client.boardAdvisorTurn(
      advisorKey: advisorKey,
      sliderValue: sliderValue,
      categoryContext: {
        'categoryName': AiGuard.sanitizeField(categoryName, maxChars: 60),
        if (categoryTier != null) 'categoryTier': categoryTier,
        if (priorEssence != null)
          'priorEssence': AiGuard.sanitizeField(priorEssence, maxChars: 400),
      },
      conversationHistory: session.messages
          .map((m) => {'advisor': m.advisorKey, 'text': m.text})
          .toList(),
    );

    final msg = BoardMessage(
      advisorKey: advisorKey,
      text: result.reply,
      timestamp: DateTime.now(),
    );

    await _appendMessage(session.sessionId, msg,
        inputTokens: result.inputTokens, outputTokens: result.outputTokens);
    return msg;
  }

  /// Appends a user-typed message to the session — no API call, no token cost.
  Future<BoardMessage> appendUserMessage(String sessionId, String text) async {
    final msg = BoardMessage(
      advisorKey: 'user',
      text: AiGuard.clampMessage(text),
      timestamp: DateTime.now(),
    );
    await _appendMessage(sessionId, msg, inputTokens: 0, outputTokens: 0);
    return msg;
  }

  Future<void> _appendMessage(
    String sessionId,
    BoardMessage msg, {
    required int inputTokens,
    required int outputTokens,
  }) async {
    final ref = _sessionsCol.doc(sessionId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final raw = (snap.data()?['messages'] as List<dynamic>?) ?? [];
      tx.update(ref, {
        'messages': [...raw, msg.toMap()],
        'lastUpdatedAt': Timestamp.fromDate(DateTime.now()),
        if (inputTokens > 0) 'totalInputTokens': FieldValue.increment(inputTokens),
        if (outputTokens > 0) 'totalOutputTokens': FieldValue.increment(outputTokens),
      });
    });
  }

  Future<void> endSession(String sessionId) async {
    await _sessionsCol.doc(sessionId).update({'isComplete': true});
  }
}

/// The fixed rotation pool — Green Pyramid does not port the per-advisor
/// intensity slider UI (D-073), so this is the only place advisor keys are
/// enumerated for session setup.
class AdvisorRotation {
  static const keys = ['mira', 'kenji', 'noa', 'eli'];
}
