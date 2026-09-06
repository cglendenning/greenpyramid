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

  /// D-082: exactly one setup session may exist per account, ever. Resumes
  /// the existing one (active or not yet started) rather than creating a
  /// second.
  Future<BoardSession> startOrResumeSetup() async {
    final active = await _council.getActiveSession(type: BoardSessionType.setup);
    if (active != null) return active;
    return _council.createSession(type: BoardSessionType.setup);
  }

  /// D-051: derives the six tiered categories from the transcript so far.
  Future<List<CategoryProposal>> proposeCategories(BoardSession session) {
    return _client.deriveCategories(
      sessionId: session.sessionId,
      transcript: session.messages
          .map((m) => {'advisor': m.advisorKey, 'text': m.text})
          .toList(),
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

  /// Pushes everything setup just wrote to Firestore (D-075) in one pass,
  /// same as any other profile change — the account bootstrap in
  /// main.dart already guarantees a signed-in uid by the time setup runs.
  Future<void> syncAfterSetup() async {
    final uid = AuthService.instance.currentUid;
    if (uid == null) return;
    await SyncService.instance.syncAll(uid, setupComplete: true);
  }
}
