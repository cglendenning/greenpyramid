import 'package:shared_preferences/shared_preferences.dart';

import '../models/board_session.dart';
import 'account_reset_service.dart';
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
  SetupService(
      {CouncilService? council,
      DatabaseHelper? db,
      CouncilClient? client,
      SyncService? sync,
      AuthService? auth,
      AccountResetService? accountReset})
      : _council = council ?? CouncilService.instance,
        _db = db ?? DatabaseHelper.instance,
        _client = client ?? CouncilClient.instance,
        _sync = sync ?? SyncService.instance,
        _auth = auth ?? AuthService.instance,
        _accountReset = accountReset ?? AccountResetService.instance;

  static final SetupService instance = SetupService();

  final CouncilService _council;
  final DatabaseHelper _db;
  final CouncilClient _client;
  final SyncService _sync;
  final AuthService _auth;
  final AccountResetService _accountReset;

  static const _reinstallCheckedKey = 'setup_reinstall_check_done';

  /// D-082: exactly one setup session may exist per account, ever — but
  /// only enforced once this device actually has a real local pyramid to
  /// protect. Found live: this was never actually checked (only an
  /// *active* session was), so completing setup and later relaunching
  /// with no active session in progress just created another one —
  /// harmless-looking, but the guarantee this directive documents as
  /// `done` didn't really hold.
  ///
  /// D-098: a device with no real local pyramid gets exactly one chance,
  /// per local install, to be wiped — an anonymous account whose
  /// (Keychain-persisted) credential already has prior server-side data
  /// can only be in this state because the app was deleted and
  /// reinstalled, and the owner's explicit decision is that a deletion
  /// means the whole account is gone, not that it comes back. Gated by
  /// [_reinstallCheckedKey] in SharedPreferences — itself app-sandboxed
  /// local storage, wiped by the same uninstall that wipes the local
  /// database, so it naturally resets to unchecked on every genuine
  /// reinstall and nowhere else. **Found live, the hard way**: without
  /// this gate, the very first version of this method re-ran the check
  /// on *every* call while local still had no real pyramid — which is
  /// also true for the entire rest of setup before categories are
  /// committed — so a second call in the same conversation (an ordinary
  /// app relaunch mid-setup, not a reinstall at all) found the
  /// in-progress session itself as "prior data" and wiped the
  /// conversation the user was still actively having.
  ///
  /// D-096: a device with no real local pyramid whose account is *not*
  /// anonymous (a future linked/paid account) restores instead of being
  /// wiped — [AccountResetService.wipeIfReinstalled] is a safe no-op for
  /// those, by its own internal check, not by trusting this caller.
  Future<BoardSession> startOrResumeSetup() async {
    // Checked directly against the category rows themselves — "at least
    // one category isn't a placeholder" — rather than reusing
    // queryLaunchSetup()'s "exactly 6 Empty% rows" count, which assumes
    // populateCategory() has already seeded the defaults. A database that
    // hasn't been seeded at all (rows.isEmpty) must read the same as one
    // that's still all placeholders: no real pyramid either way.
    final rows = await _db.queryCategories();
    final hasRealLocalPyramid =
        rows.any((r) => !(r[DatabaseHelper.columnCat] as String).startsWith('Empty'));

    if (!hasRealLocalPyramid) {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool(_reinstallCheckedKey) ?? false)) {
        // This must run — and resolve, one way or another — *before* the
        // active-session check below, and exactly once: a stale session
        // from before a genuine reinstall must be wiped away before it's
        // ever considered for resume, but only on this one occasion, not
        // on every call for the rest of this local install's lifetime.
        if (await _accountReset.wipeIfReinstalled()) {
          // The old identity no longer exists — establish the new one
          // before anything below touches auth.currentUser.
          await _auth.signInSilently();
        } else {
          final uid = _auth.currentUid;
          if (uid != null && await _sync.restoreFromCloud(uid)) {
            await prefs.setBool(_reinstallCheckedKey, true);
            throw SetupAlreadyCompleteException();
          }
        }
        await prefs.setBool(_reinstallCheckedKey, true);
      }
    }

    final active = await _council.getActiveSession(type: BoardSessionType.setup);
    if (active != null) return active;

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
  /// throws past this point — advisory, never required (D-074). D-100:
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

  /// Pushes everything setup just wrote to Firestore (D-075) in one pass,
  /// same as any other profile change — the account bootstrap in
  /// main.dart already guarantees a signed-in uid by the time setup runs.
  Future<void> syncAfterSetup() async {
    final uid = AuthService.instance.currentUid;
    if (uid == null) return;
    await SyncService.instance.syncAll(uid, setupComplete: true);
  }
}

/// D-082/D-096: thrown by [SetupService.startOrResumeSetup] whenever setup
/// has nothing left to do for this account — either this device already
/// had a real local pyramid and the account already completed a setup
/// session (re-entering setup, e.g. the home screen's menu item, must not
/// redo it), or it didn't, but one was just restored from Firestore. The
/// screen's response is the same either way: leave setup entirely, not
/// show an error inside a chat UI that has nothing to resume.
class SetupAlreadyCompleteException implements Exception {
  @override
  String toString() =>
      'Setup has already been completed for this account.';
}
