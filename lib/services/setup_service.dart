import '../models/board_session.dart';
import 'account_reset_service.dart';
import 'ai_guard.dart';
import 'auth_service.dart';
import 'council_client.dart';
import 'council_service.dart';
import 'db.dart';
import 'sync_service.dart';
import 'setup_draft_store.dart';
import 'entitlement_service.dart';
import 'model_output_guard.dart';
import 'package:sqflite/sqflite.dart';

/// D-043: orchestrates the single continuous setup conversation — one
/// `setup`-typed [BoardSession] (D-188) that produces six tiered
/// categories (D-051), habits per category (D-052), three foundational
/// essences (D-009/D-185), and the closing vision statement (D-055). The
/// screen calls these methods and renders state; no SQL or prompt
/// construction lives in the screen (D-024).
class SetupService {
  SetupService(
      {CouncilService? council,
      DatabaseHelper? db,
      CouncilClient? client,
      SyncService? sync,
      AuthService? auth,
      AccountResetService? accountReset,
      SetupDraftStore? drafts})
      : _council = council ?? CouncilService.instance,
        _db = db ?? DatabaseHelper.instance,
        _client = client ?? CouncilClient.instance,
        _sync = sync ?? SyncService.instance,
        _auth = auth ?? AuthService.instance,
        drafts = drafts ?? SetupDraftStore(db: db);

  static final SetupService instance = SetupService();

  final CouncilService _council;
  final DatabaseHelper _db;
  final CouncilClient _client;
  final SyncService _sync;
  final AuthService _auth;

  final SetupDraftStore drafts;
  CouncilService get council => _council;
  DatabaseHelper get localDb => _db;
  AuthService get auth => _auth;
  EntitlementService get entitlement => EntitlementService.instance;
  Future<Map<String, dynamic>?> loadDraft() async {
    final uid = _auth.currentUid;
    return uid == null ? null : drafts.load(uid);
  }

  /// D-001: resume the account's local draft before requiring cloud access.
  /// Missing local data never revokes credentials or deletes an anonymous user.
  Future<BoardSession> startOrResumeSetup() async {
    // Checked directly against the category rows themselves — "at least
    // one category isn't a placeholder" — rather than reusing
    // queryLaunchSetup()'s "exactly 6 Empty% rows" count, which assumes
    // populateCategory() has already seeded the defaults. A database that
    // hasn't been seeded at all (rows.isEmpty) must read the same as one
    // that's still all placeholders: no real pyramid either way.
    final rows = await _db.queryCategories();
    final hasRealLocalPyramid = rows.any(
        (r) => !(r[DatabaseHelper.columnCat] as String).startsWith('Empty'));

    final uid = _auth.currentUid;
    if (uid != null) {
      final local = await drafts.load(uid);
      if (local != null && local['state']['phase'] != 'finished') {
        return SetupDraftStore.decodeSession(
            Map<String, dynamic>.from(local['session']));
      }
    }

    final active =
        await _council.getActiveSession(type: BoardSessionType.setup);
    if (active != null) {
      if (uid != null) await drafts.recover(uid, active.sessionId);
      return active;
    }

    if (!hasRealLocalPyramid && uid != null && !_auth.isAnonymous) {
      final completed = await drafts.recoverCompletion(uid);
      if (completed != null && completed['state']['phase'] != 'finished')
        return SetupDraftStore.decodeSession(
            Map<String, dynamic>.from(completed['session']));
      if (await _sync.restoreFromCloud(uid))
        throw SetupAlreadyCompleteException();
    }

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

  /// D-052/D-103: proposes 1 to [maxAllowed] habits for one category
  /// (never more than 3). [essence] is null for a category with none yet
  /// (D-010) — the prompt degrades to name-only without inventing a
  /// reason. [maxAllowed] is the caller's cross-category budget, keeping
  /// the pyramid's total habit count at or under 10 across all six
  /// categories.
  Future<List<String>> proposeHabits({
    required BoardSession session,
    required String categoryName,
    String? essence,
    List<String> existingHabits = const [],
    int maxAllowed = 2,
  }) {
    return _client.deriveHabits(
      sessionId: session.sessionId,
      categoryName: categoryName,
      essence: essence,
      existingHabits: existingHabits,
      maxAllowed: maxAllowed,
    );
  }

  /// D-118: the vision statement, written once, right after the opening
  /// conversation concludes — before categories, essences, or habits
  /// exist. Reverses D-055's original "generated at the close of setup,
  /// from essences and the full transcript" timing: the owner's explicit
  /// instruction this round moved it to immediately after Mira's final
  /// "anything else" exchange, so there are no essences yet to draw on —
  /// only the opening conversation itself. Persisted locally (MIG-1's
  /// latest-wins vision_statement semantics) but does NOT end the
  /// session — setup continues through categories, essences, and habits
  /// on the same session afterward.
  Future<String> deriveOpeningVisionStatement(BoardSession session) async {
    await AiGuard.instance.acquire();
    final vision = await _client.deriveVisionStatement(
      sessionId: session.sessionId,
      isSetup: true,
      essences: const [],
      transcript: session.messages
          .map((m) => {'advisor': m.advisorKey, 'text': m.text})
          .toList(),
    );
    await _db.insertVisionStatement(vision);
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
        DatabaseHelper.columnCategoryDescription: c.description ?? '',
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
        DatabaseHelper.columnTaskDescription:
            AiGuard.sanitizeField(habit, maxChars: 120),
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

  /// D-009/D-185: commits a foundational category's captured essence.
  Future<void> commitEssence({
    required int categoryId,
    required String essence,
    required String sessionId,
  }) {
    return _db.insertCategoryEssence(
      categoryId: categoryId,
      essence: AiGuard.sanitizeField(essence, maxChars: 1000),
      sourceSessionId: sessionId,
    );
  }

  /// D-048: derives and commits domain findings for one foundational
  /// category's conversation, at the moment its essence is accepted. Never
  /// throws past this point — advisory, never required (D-188). D-100:
  /// delegates to `CouncilService.recordDomainFindings`, the single shared
  /// implementation (also used by `CouncilScreen` and the general Council
  /// conversation) — this stays only as the setup-specific entry point
  /// callers already use.
  Future<void> recordDomainFindings({
    required BoardSession session,
    required int categoryId,
    required String categoryName,
    required String essence,
    required bool isSetup,
  }) =>
      _council.recordDomainFindings(
        session: session,
        isSetup: isSetup,
        categoryId: categoryId,
        categoryName: categoryName,
        essence: essence,
      );

  static String? validateCategories(List<CategoryProposal> categories) {
    if (categories.length != 6 ||
        categories.map((c) => c.position).toSet().length != 6 ||
        categories.any((c) => c.position < 1 || c.position > 6))
      return 'Provide six categories in the six pyramid positions.';
    if (categories.any((c) =>
        c.name.trim().isEmpty ||
        c.name.length > 24 ||
        c.name.trim().split(RegExp(r'\s+')).length > 2 ||
        looksLikePlaceholder(c.name) ||
        (c.description ?? '').trim().isEmpty ||
        (c.description ?? '').length > 140))
      return 'Use distinct category names of one or two words, up to 24 characters; include a short description up to 140 characters.';
    if (categories.map((c) => c.name.trim().toLowerCase()).toSet().length != 6)
      return 'Category names must be distinct.';
    return null;
  }

  static String? validateHabits(
      List<CategoryProposal> categories, Map<String, List<String>> habits) {
    if (validateCategories(categories) != null)
      return validateCategories(categories);
    var count = 0;
    for (final category in categories) {
      final rows = habits[category.name] ?? [];
      if (rows.isEmpty || rows.length > 2)
        return 'Choose one or two habits for each category.';
      if (rows.any((h) =>
              h.trim().isEmpty || h.length > 40 || looksLikePlaceholder(h)) ||
          rows.map((h) => h.trim().toLowerCase()).toSet().length != rows.length)
        return 'Habits must be distinct, nonempty and at most 40 characters.';
      count += rows.length;
    }
    return count > 10 ? 'Choose at most ten initial habits.' : null;
  }

  Future<String?> firstName() async =>
      (await _db.getAccountState())[DatabaseHelper.columnFirstName] as String?;
  Future<String?> entitlementState() async =>
      (await _db.getAccountState())[DatabaseHelper.columnEntitlement]
          as String?;
  Future<void> saveManualVision(String vision) =>
      _db.insertVisionStatement(vision).then((_) {});

  Future<void> materializeDraft(
      BoardSession session,
      List<CategoryProposal> categories,
      List<Map<String, dynamic>> explanations,
      Map<String, List<String>> habits) async {
    final invalid = validateHabits(categories, habits);
    if (invalid != null) throw StateError(invalid);
    final database = await _db.database;
    final created = session.createdAt.toIso8601String();
    await database.transaction((tx) async {
      for (final c in categories) {
        await tx.insert(
            DatabaseHelper.categoryTable,
            {
              DatabaseHelper.columnCategoryId: c.position,
              DatabaseHelper.columnCat: c.name,
              DatabaseHelper.columnPosition: c.position,
              DatabaseHelper.columnCategoryCreated: created,
              DatabaseHelper.columnCategoryDescription: c.description ?? '',
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final step in explanations) {
        final text = (step['essence'] ?? '') as String;
        if (text.length > 1000) throw StateError('Explanation is too long.');
        final existing = await tx.query(DatabaseHelper.categoryEssenceTable,
            where: 'categoryid = ?',
            whereArgs: [step['categoryId']],
            orderBy: 'id DESC',
            limit: 1);
        if (existing.isEmpty || existing.first['essence'] != text)
          await tx.insert(DatabaseHelper.categoryEssenceTable, {
            DatabaseHelper.columnEssenceCategoryId: step['categoryId'],
            DatabaseHelper.columnEssenceText: text,
            DatabaseHelper.columnEssenceCreated: created,
            DatabaseHelper.columnEssenceSourceSession: session.sessionId,
          });
      }
      for (final category in categories) {
        for (final habit in habits[category.name]!) {
          await tx.insert(
              DatabaseHelper.taskTable,
              {
                DatabaseHelper.columnCategory: category.name,
                DatabaseHelper.columnTaskDescription: habit,
                DatabaseHelper.columnSunday: 'true',
                DatabaseHelper.columnMonday: 'true',
                DatabaseHelper.columnTuesday: 'true',
                DatabaseHelper.columnWednesday: 'true',
                DatabaseHelper.columnThursday: 'true',
                DatabaseHelper.columnFriday: 'true',
                DatabaseHelper.columnSaturday: 'true',
                DatabaseHelper.columnCreateDate: created,
              },
              conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }
    });
    await syncAfterSetup();
    await entitlement.requestTrialAfterSetup();
  }

  Future<void> acknowledgeCompletion(BoardSession session) =>
      _client.completeSetup(session.sessionId);

  /// Pushes everything setup just wrote to Firestore (D-187) in one pass,
  /// same as any other profile change — the account bootstrap in
  /// main.dart already guarantees a signed-in uid by the time setup runs.
  Future<void> syncAfterSetup() async {
    final uid = _auth.currentUid;
    if (uid == null) return;
    await _sync.syncAll(uid, setupComplete: true);
  }
}

/// D-188/D-187: thrown by [SetupService.startOrResumeSetup] whenever setup
/// has nothing left to do for this account — either this device already
/// had a real local pyramid and the account already completed a setup
/// session (re-entering setup, e.g. the home screen's menu item, must not
/// redo it), or it didn't, but one was just restored from Firestore. The
/// screen's response is the same either way: leave setup entirely, not
/// show an error inside a chat UI that has nothing to resume.
class SetupAlreadyCompleteException implements Exception {
  @override
  String toString() => 'Setup has already been completed for this account.';
}
