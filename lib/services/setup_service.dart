import 'package:flutter/foundation.dart' show debugPrint;

import '../models/board_session.dart';
import 'ai_guard.dart';
import 'auth_service.dart';
import 'council_client.dart';
import 'council_service.dart';
import 'db.dart';
import 'sync_service.dart';

/// D-043: orchestrates the single continuous setup conversation — one
/// `setup`-typed [BoardSession] (D-082) that produces six tiered
/// categories (D-051), habits per category (D-052), three foundational
/// essences (D-009/D-028), and the closing vision statement (D-055). The
/// screen calls these methods and renders state; no SQL or prompt
/// construction lives in the screen (D-024).
class SetupService {
  SetupService({CouncilService? council, DatabaseHelper? db, CouncilClient? client})
      : _council = council ?? CouncilService.instance,
        _db = db ?? DatabaseHelper.instance,
        _client = client ?? CouncilClient.instance;

  static final SetupService instance = SetupService();

  final CouncilService _council;
  final DatabaseHelper _db;
  final CouncilClient _client;

  /// D-082: exactly one setup session may exist per account, ever — but
  /// only enforced once this device actually has a real local pyramid to
  /// protect. Found live: this was never actually checked (only an
  /// *active* session was), so completing setup and later relaunching
  /// with no active session in progress just created another one —
  /// harmless-looking, but the guarantee this directive documents as
  /// `done` didn't really hold.
  ///
  /// A device with no real category yet — still the default `Empty%` seed,
  /// or no rows at all — is allowed through regardless of Firestore
  /// history: D-075's sync is push-only
  /// (local to Firestore, never back down), so there is currently no way
  /// to restore an existing pyramid onto a device that doesn't have one —
  /// refusing here would strand a genuinely reinstalling user with no
  /// pyramid and no path to ever get one. The case this actually guards
  /// against is the real bug: a device that already has a working local
  /// pyramid re-entering setup (e.g. the home screen's "Setup" menu item)
  /// and redoing it.
  Future<BoardSession> startOrResumeSetup() async {
    final active = await _council.getActiveSession(type: BoardSessionType.setup);
    if (active != null) return active;

    // Checked directly against the category rows themselves — "at least
    // one category isn't a placeholder" — rather than reusing
    // queryLaunchSetup()'s "exactly 6 Empty% rows" count, which assumes
    // populateCategory() has already seeded the defaults. A database that
    // hasn't been seeded at all (rows.isEmpty) must read the same as one
    // that's still all placeholders: no real pyramid either way.
    final rows = await _db.queryCategories();
    final hasRealLocalPyramid =
        rows.any((r) => !(r[DatabaseHelper.columnCat] as String).startsWith('Empty'));
    if (hasRealLocalPyramid && await _council.hasEverCreatedSetupSession()) {
      throw SetupAlreadyCompleteException();
    }

    return _council.createSession(type: BoardSessionType.setup);
  }

  /// D-051: derives the six tiered categories from the transcript so far.
  /// D-093: [existingCategories], non-null, requests a refinement of that
  /// proposal ("not quite right") rather than a fresh derivation.
  Future<List<CategoryProposal>> proposeCategories(BoardSession session,
      {List<CategoryProposal>? existingCategories}) {
    return _client.deriveCategories(
      sessionId: session.sessionId,
      transcript: session.messages
          .map((m) => {'advisor': m.advisorKey, 'text': m.text})
          .toList(),
      existingCategories: existingCategories,
    );
  }

  /// D-052: proposes 3-5 habits for one category. [essence] is null for a
  /// category with none yet (D-010) — the prompt degrades to name-only
  /// without inventing a reason.
  Future<List<String>> proposeHabits({
    required BoardSession session,
    required String categoryName,
    String? essence,
    List<String> existingHabits = const [],
  }) {
    return _client.deriveHabits(
      sessionId: session.sessionId,
      categoryName: categoryName,
      essence: essence,
      existingHabits: existingHabits,
    );
  }

  /// D-055: the closing synthesis, written once at the end of setup, and
  /// persisted locally (MIG-1's latest-wins vision_statement semantics).
  Future<String> closeSynthesis({
    required BoardSession session,
    required List<({String categoryName, String essence})> essences,
  }) async {
    await AiGuard.instance.acquire();
    final vision = await _client.deriveVisionStatement(
      sessionId: session.sessionId,
      essences: essences
          .map((e) => {'categoryName': e.categoryName, 'essence': e.essence})
          .toList(),
      transcript: session.messages
          .map((m) => {'advisor': m.advisorKey, 'text': m.text})
          .toList(),
    );
    await _db.insertVisionStatement(vision);
    await _council.endSession(session.sessionId);
    return vision;
  }

  /// D-051: commits the derived pyramid — category id and position both
  /// equal the proposal's position (1-6), matching the app's existing
  /// convention on a fresh install; D-084's rename-safety uses the id, not
  /// the position, once the user later renames one.
  Future<void> commitCategories(List<CategoryProposal> categories) async {
    final now = DateTime.now().toIso8601String();
    for (final c in categories) {
      await _db.insertCategory({
        DatabaseHelper.columnCategoryId: c.position,
        DatabaseHelper.columnCat: c.name,
        DatabaseHelper.columnPosition: c.position,
        DatabaseHelper.columnCategoryCreated: now,
      });
    }
  }

  /// D-052/D-054: commits a category's habits, scheduled every day (D-054
  /// — day-of-week selection does not happen in setup).
  Future<void> commitHabits(String categoryName, List<String> habits) async {
    final now = DateTime.now().toIso8601String();
    for (final habit in habits) {
      await _db.insertTask({
        DatabaseHelper.columnCategory: categoryName,
        DatabaseHelper.columnTaskDescription: AiGuard.sanitizeField(habit, maxChars: 120),
        DatabaseHelper.columnSunday: 'true',
        DatabaseHelper.columnMonday: 'true',
        DatabaseHelper.columnTuesday: 'true',
        DatabaseHelper.columnWednesday: 'true',
        DatabaseHelper.columnThursday: 'true',
        DatabaseHelper.columnFriday: 'true',
        DatabaseHelper.columnSaturday: 'true',
        DatabaseHelper.columnCreateDate: now,
      });
    }
  }

  /// D-009/D-028: commits a foundational category's captured essence.
  Future<void> commitEssence({
    required int categoryId,
    required String essence,
    required String sessionId,
  }) {
    return _db.insertCategoryEssence(
      categoryId: categoryId,
      essence: AiGuard.sanitizeField(essence, maxChars: 400),
      sourceSessionId: sessionId,
    );
  }

  /// D-048: derives and commits domain findings for one foundational
  /// category's conversation, at the moment its essence is accepted. Never
  /// throws past this point — advisory, never required (D-074).
  Future<void> recordDomainFindings({
    required BoardSession session,
    required int categoryId,
    required String categoryName,
    required String essence,
    required bool isSetup,
  }) async {
    try {
      final findings = await _client.deriveDomainFindings(
        sessionId: session.sessionId,
        categoryName: categoryName,
        essence: essence,
        transcript: session.messages
            .map((m) => {'advisor': m.advisorKey, 'text': m.text})
            .toList(),
        isSetup: isSetup,
      );
      for (final f in findings) {
        await _db.insertDomainFinding(
          categoryId: categoryId,
          domain: f.domain,
          note: AiGuard.sanitizeField(f.note, maxChars: 200),
          sourceSessionId: session.sessionId,
        );
      }
    } catch (e, st) {
      debugPrint('SetupService.recordDomainFindings failed: $e\n$st');
    }
  }

  /// Pushes everything setup just wrote to Firestore (D-075) in one pass,
  /// same as any other profile change — the account bootstrap in
  /// main.dart already guarantees a signed-in uid by the time setup runs.
  Future<void> syncAfterSetup() async {
    final uid = AuthService.instance.currentUid;
    if (uid == null) return;
    await SyncService.instance.syncAll(uid, setupComplete: true);
  }
}

/// D-082: thrown by [SetupService.startOrResumeSetup] when this device
/// already has a real local pyramid and the account already completed a
/// setup session — re-entering setup (e.g. the home screen's menu item)
/// must not redo it. The screen's response is to leave setup entirely,
/// not show an error inside a chat UI that has nothing to resume.
class SetupAlreadyCompleteException implements Exception {
  @override
  String toString() =>
      'Setup has already been completed for this account.';
}
