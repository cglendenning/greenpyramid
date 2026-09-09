import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:uuid/uuid.dart';

import '../models/board_session.dart';
import 'ai_guard.dart';
import 'council_client.dart';
import 'db.dart';

/// D-028/D-082: orchestrates Council sessions, ported from Kansei's
/// `BoardService`. Sessions live flat under `users/{uid}/councilSessions`
/// (IV-D) rather than nested per-goal — this is what resolves II-K
/// mismatches 1 and 3 (persistence and scope) for Green Pyramid.
class CouncilService {
  CouncilService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    CouncilClient? client,
    DatabaseHelper? localDb,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _client = client ?? CouncilClient.instance,
        _localDb = localDb ?? DatabaseHelper.instance;

  static final CouncilService instance = CouncilService();

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final CouncilClient _client;
  // D-100: local SQLite, not Firestore — named distinctly from _db (which
  // is Firestore here, unlike most other services where _db means
  // DatabaseHelper) to keep the two unambiguous in this file.
  final DatabaseHelper _localDb;
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
  ///
  /// D-095: [pyramidContext], non-null, is the general Council chat's
  /// (D-091) whole-pyramid grounding — when present, the backend ignores
  /// the category-scoped fields above entirely and uses the pyramid-aware
  /// prompt instead.
  Future<BoardMessage?> runAdvisorTurn({
    required BoardSession session,
    required String advisorKey,
    required String categoryName,
    int? categoryTier,
    String? priorEssence,
    List<Map<String, dynamic>>? pyramidContext,
    // D-108: overrides the default "the whole session so far" history.
    // Needed because essence-deepening (D-009 step 3) shares one session
    // across all three foundational categories (D-043) — session.messages
    // for category 2's kickoff call already contains category 1's entire
    // exchange, so "respond to what was just said" reacted to category
    // 1's closing reply instead of asking a fresh question about category
    // 2. Every other caller (CouncilScreen, GeneralCouncilScreen) leaves
    // this null and keeps the existing full-history behavior, which is
    // already correct for them.
    List<Map<String, String>>? conversationHistoryOverride,
  }) async {
    await AiGuard.instance.acquire();

    final sliderValue = session.sliderSettings[advisorKey] ?? 0.5;
    // D-017/D-072: a setup-typed session is free, bounded by call count —
    // never charged against D-087's dollar cap. Derived from the session
    // itself so callers can't get this wrong.
    final isSetup = session.type == BoardSessionType.setup;
    final result = await _client.boardAdvisorTurn(
      advisorKey: advisorKey,
      sliderValue: sliderValue,
      categoryContext: {
        'categoryName': AiGuard.sanitizeField(categoryName, maxChars: 60),
        if (categoryTier != null) 'categoryTier': categoryTier,
        if (priorEssence != null)
          'priorEssence': AiGuard.sanitizeField(priorEssence, maxChars: 400),
      },
      conversationHistory: conversationHistoryOverride ??
          session.messages
              .map((m) => {'advisor': m.advisorKey, 'text': m.text})
              .toList(),
      isSetup: isSetup,
      sessionId: session.sessionId,
      pyramidContext: pyramidContext
          ?.map((c) => {
                'name': AiGuard.sanitizeField(c['name'] as String, maxChars: 24),
                'tier': c['tier'] as String?,
                'essence': (c['essence'] as String?) == null
                    ? null
                    : AiGuard.sanitizeField(c['essence'] as String, maxChars: 300),
              })
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

  /// D-048/D-100: derives and commits domain findings for a Council
  /// conversation. Advisory, never required (D-074) — never throws past
  /// this point. Extracted here after this exact derive-then-insert
  /// sequence had been copy-pasted twice already (`SetupService` and
  /// `CouncilScreen`, both now delegate here) — a third copy for the
  /// general Council conversation would have made it three.
  ///
  /// Two shapes, exactly one required: [categoryId]/[categoryName]/
  /// [essence] for a single-category conversation (setup's foundational
  /// capture, D-061's re-clarification); [pyramidContext] for the general
  /// Council conversation (D-091), which spans the whole pyramid — each
  /// returned finding is attributed to whichever category the model named,
  /// resolved back to a real `categoryId` by matching against
  /// [pyramidContext]'s own `name` field (from `queryPyramidSummary`). A
  /// finding naming a category that doesn't match is dropped rather than
  /// guessed at.
  Future<void> recordDomainFindings({
    required BoardSession session,
    required bool isSetup,
    int? categoryId,
    String? categoryName,
    String? essence,
    List<Map<String, dynamic>>? pyramidContext,
  }) async {
    assert((categoryId != null && categoryName != null) != (pyramidContext != null),
        'pass either categoryId+categoryName, or pyramidContext, never both or neither');
    try {
      final findings = await _client.deriveDomainFindings(
        sessionId: session.sessionId,
        categoryName: pyramidContext == null ? categoryName : null,
        essence: pyramidContext == null ? essence : null,
        pyramidContext: pyramidContext
            ?.map((c) => {
                  'name': c['name'] as String,
                  'tier': c['tier'] as String?,
                  'essence': c['essence'] as String?,
                })
            .toList(),
        transcript: session.messages
            .map((m) => {'advisor': m.advisorKey, 'text': m.text})
            .toList(),
        isSetup: isSetup,
      );
      for (final f in findings) {
        final resolvedCategoryId = pyramidContext == null
            ? categoryId!
            : pyramidContext.firstWhere(
                (c) => c['name'] == f.categoryName,
                orElse: () => const {},
              )['id'] as int?;
        if (resolvedCategoryId == null) continue;
        await _localDb.insertDomainFinding(
          categoryId: resolvedCategoryId,
          domain: f.domain,
          note: AiGuard.sanitizeField(f.note, maxChars: 200),
          sourceSessionId: session.sessionId,
        );
      }
    } catch (e, st) {
      debugPrint('CouncilService.recordDomainFindings failed: $e\n$st');
    }
  }

  /// D-090: one turn of the solo setup conversation — Mira only, forced
  /// through a tool call so her readiness to build the pyramid comes back
  /// as [readyToBuild] rather than something parsed out of free text.
  /// Returns the session with her reply already appended, since the caller
  /// needs both the updated transcript and the readiness flag together.
  ///
  /// D-093: [existingCategories], non-null, means this is a refinement
  /// round ("not quite right") rather than an original build — passed
  /// straight through so the backend frames the conversation accordingly.
  Future<({BoardSession session, bool readyToBuild})> runMiraSetupTurn(
      BoardSession session,
      {List<CategoryProposal>? existingCategories}) async {
    await AiGuard.instance.acquire();

    final result = await _client.boardAdvisorTurn(
      advisorKey: 'mira',
      categoryContext: const {},
      conversationHistory: session.messages
          .map((m) => {'advisor': m.advisorKey, 'text': m.text})
          .toList(),
      isSetup: true,
      soloSetup: true,
      sessionId: session.sessionId,
      existingCategories: existingCategories
          ?.map((c) => {'name': c.name, 'description': c.description ?? ''})
          .toList(),
    );

    final msg = BoardMessage(
      advisorKey: 'mira',
      text: result.reply,
      timestamp: DateTime.now(),
    );
    await _appendMessage(session.sessionId, msg,
        inputTokens: result.inputTokens, outputTokens: result.outputTokens);
    return (session: session.withMessage(msg), readyToBuild: result.readyToBuild);
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

  /// D-093: appends a fixed, client-authored advisor line (e.g. the
  /// "what didn't feel right" refinement prompt) — no API call, no token
  /// cost, the same as [appendUserMessage] but attributed to an advisor.
  /// Unlike D-067's opening line, this is persisted: the turn after it
  /// needs the real conversation history to show why the user's next
  /// reply is about what to refine, not a continuation of the original
  /// opening questions.
  Future<BoardMessage> appendAdvisorMessage(
      String sessionId, String advisorKey, String text) async {
    final msg = BoardMessage(
      advisorKey: advisorKey,
      text: text,
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
