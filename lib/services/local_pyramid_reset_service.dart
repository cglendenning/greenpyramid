import 'package:sqflite/sqflite.dart';

import 'db.dart';

/// D-132: the one genuinely destructive piece of "sign out, then start
/// fresh" — wipes this device's local pyramid so `SetupScreen` runs
/// against a genuinely empty database, the state it's actually built for.
///
/// Deliberately **not** the same code path as
/// `AccountResetService.wipeIfReinstalled()` — that method's own safety
/// check restricts it to anonymous accounts and a specific reinstall
/// heuristic. This is a distinct, explicit, user-confirmed action on the
/// *local* database only, gated entirely by the confirmation dialog the
/// caller shows before invoking it, never by any account-state check
/// here. It touches only SQLite — Firestore data under the account being
/// signed out of is untouched, since it may still belong to a real,
/// recoverable account the user signs back into later.
///
/// Uses the real table name constants directly, not `DatabaseHelper`'s
/// `getXTable()` demo-aware getters — this must always wipe the real
/// pyramid regardless of whether Demo Mode happens to be toggled on.
class LocalPyramidResetService {
  LocalPyramidResetService({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  static final LocalPyramidResetService instance = LocalPyramidResetService();

  final DatabaseHelper _dbHelper;

  /// Every table setup produces, deleted, then re-seeded to the exact
  /// state a fresh install starts in (`populateCategory()`'s six
  /// "EmptyN" placeholder rows) — `queryLaunchSetup()`'s `defaultCats ==
  /// 6` check is what routes a fresh install to `/setup` in the first
  /// place, so this must reproduce that state exactly, not just delete
  /// rows.
  Future<void> wipeLocalPyramid() async {
    final Database db = await _dbHelper.database;
    await db.delete(DatabaseHelper.taskTable);
    await db.delete(DatabaseHelper.taskLogTable);
    await db.delete(DatabaseHelper.categoryEssenceTable);
    await db.delete(DatabaseHelper.domainFindingTable);
    await db.delete(DatabaseHelper.chatTable);
    await db.delete(DatabaseHelper.visionStatementTable);
    await db.delete(DatabaseHelper.commentaryCountdownTable);
    await db.delete(DatabaseHelper.accountStateTable);
    // D-179: found live — deleting this row without ever re-inserting it
    // left account_state permanently empty, so the very next
    // getAccountState() call anywhere in the app (first reached, in
    // practice, by requestTrialAfterSetup's own entitlement read at the
    // end of setup) threw "Bad state: No element" on rows.first,
    // surfacing as "Something went wrong finishing setup" on the habits
    // screen — reproduced live: sign out, tap "Begin" (not "Sign in"),
    // run through the whole setup conversation, tap "Build my pyramid."
    // applyV7Schema's own INSERT OR IGNORE establishes this same
    // single-row invariant for a fresh install; this restores it after a
    // wipe the identical way.
    await db.insert(DatabaseHelper.accountStateTable,
        {DatabaseHelper.columnAccountId: 1},
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.delete(DatabaseHelper.categoryTable);
    await _dbHelper.populateCategory();
  }
}
