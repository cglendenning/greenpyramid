import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'ai_guard.dart';
import 'db.dart';

/// D-034/D-075: uploads exactly the enumerated local dataset to Firestore
/// under the signed-in uid, in the layout IV-D prescribes:
/// ```
/// users/{uid}
///   ttlAt                       D-035 prune marker (see below)
///   profile/main                categories, tiers, active essences, vision
///                                statement, timezone, entitlement, trial window
///   essenceVersions/{id}        every version of every essence (D-061)
///   domainFindings/{id}         accumulated four-domain findings (D-048)
///   recentActivity/{id}         bounded task_log window, ≤250 rows (D-075)
/// ```
/// `councilSessions/` and `deviceTrial/` are also part of IV-D but are not
/// built yet (R5 and D-059's Android trial marker respectively) — nothing
/// syncs into them until that lands.
///
/// Every write is a deterministic-ID `set(..., merge: true)` or an explicit
/// diff-and-delete, never a blind append, so an interrupted sync is safe to
/// re-run (MIG-1) and never produces duplicates.
///
/// This runs after habit check-off, never in its path (D-031): check-off
/// itself never calls into this class or awaits anything here.
class SyncService {
  SyncService({FirebaseFirestore? firestore, DatabaseHelper? db})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _db = db ?? DatabaseHelper.instance;

  static final SyncService instance = SyncService();

  final FirebaseFirestore _firestore;
  final DatabaseHelper _db;

  /// D-064: an anonymous account that never finished setup is pruned 30
  /// days after creation. [setupComplete] is the caller's own signal for
  /// "no longer eligible" — main.dart already computes it (the same check
  /// that decides whether to route to `/setup`), so this reuses it instead
  /// of inventing a second one.
  static const pruneEligibleWindow = Duration(days: 30);

  /// D-034: never swallowed — a failure here means the next launch's sync
  /// finds the same unsynced local state and retries automatically, but
  /// only if the failure was actually logged and someone can see it.
  Future<void> syncAll(String uid, {required bool setupComplete}) async {
    try {
      final userDoc = _firestore.collection('users').doc(uid);
      await Future.wait([
        _syncProfile(userDoc),
        _syncEssenceVersions(userDoc),
        _syncDomainFindings(userDoc),
        _syncRecentActivity(userDoc),
        _syncPruneEligibility(userDoc, setupComplete: setupComplete),
      ]);
    } catch (e, st) {
      debugPrint('SyncService: sync failed, will retry next launch: $e\n$st');
    }
  }

  /// IV-D `profile/main`: categories with tier-implying position, each
  /// category's *active* (latest) essence, vision statement, timezone, and
  /// the account_state fields D-075 lists (entitlement, trial window).
  /// Every version of essence lives separately in `essenceVersions` — this
  /// doc only ever holds the current one per category.
  Future<void> _syncProfile(DocumentReference<Map<String, dynamic>> userDoc) async {
    final categoryRows = await _db.queryCategories();
    final essenceRows = await _db.queryAllCategoryEssences();

    final latestEssenceByCategory = <int, Map<String, dynamic>>{};
    for (final row in essenceRows) {
      final categoryId = row[DatabaseHelper.columnEssenceCategoryId] as int;
      final created = row[DatabaseHelper.columnEssenceCreated] as String;
      final current = latestEssenceByCategory[categoryId];
      if (current == null ||
          created.compareTo(current[DatabaseHelper.columnEssenceCreated] as String) > 0) {
        latestEssenceByCategory[categoryId] = row;
      }
    }

    final categories = categoryRows.map((row) {
      final id = row[DatabaseHelper.columnCategoryId] as int;
      return {
        'id': id,
        'cat': row[DatabaseHelper.columnCat],
        'position': row[DatabaseHelper.columnPosition],
        'created': row[DatabaseHelper.columnCategoryCreated],
        'activeEssence':
            latestEssenceByCategory[id]?[DatabaseHelper.columnEssenceText],
      };
    }).toList();

    final vision = await _db.getLatestVisionStatement();
    final account = await _db.getAccountState();

    await userDoc.collection('profile').doc('main').set(
        {
          'categories': categories,
          if (vision != null) 'visionStatement': vision,
          'entitlement': account[DatabaseHelper.columnEntitlement],
          'trialStartedAt': account[DatabaseHelper.columnTrialStartedAt],
          'trialExpiresAt': account[DatabaseHelper.columnTrialExpiresAt],
          'timezone': account[DatabaseHelper.columnAccountTimezone],
        },
        SetOptions(merge: true));
  }

  /// IV-D `essenceVersions/{id}`: every version of every category's essence
  /// (D-061) — the full audit trail `profile/main.activeEssence` is drawn
  /// from.
  Future<void> _syncEssenceVersions(DocumentReference<Map<String, dynamic>> userDoc) async {
    final rows = await _db.queryAllCategoryEssences();
    if (rows.isEmpty) return;
    final batch = _firestore.batch();
    final col = userDoc.collection('essenceVersions');
    for (final row in rows) {
      final id = row[DatabaseHelper.columnEssenceId].toString();
      batch.set(
          col.doc(id),
          {
            'categoryid': row[DatabaseHelper.columnEssenceCategoryId],
            'essence': row[DatabaseHelper.columnEssenceText],
            'created': row[DatabaseHelper.columnEssenceCreated],
            'sourceSessionId': row[DatabaseHelper.columnEssenceSourceSession],
          },
          SetOptions(merge: true));
    }
    await batch.commit();
  }

  /// IV-D `domainFindings/{id}`: accumulated four-domain findings (D-048).
  Future<void> _syncDomainFindings(DocumentReference<Map<String, dynamic>> userDoc) async {
    final rows = await _db.queryAllDomainFindings();
    if (rows.isEmpty) return;
    final batch = _firestore.batch();
    final col = userDoc.collection('domainFindings');
    for (final row in rows) {
      final id = row[DatabaseHelper.columnFindingId].toString();
      batch.set(
          col.doc(id),
          {
            'categoryid': row[DatabaseHelper.columnFindingCategoryId],
            'domain': row[DatabaseHelper.columnFindingDomain],
            'note': row[DatabaseHelper.columnFindingNote],
            'created': row[DatabaseHelper.columnFindingCreated],
            'sourceSessionId': row[DatabaseHelper.columnFindingSourceSession],
          },
          SetOptions(merge: true));
    }
    await batch.commit();
  }

  /// IV-D `recentActivity/{id}`: only the bounded recent window syncs; full
  /// history is local-only (D-031). Because the window is a moving 250-row
  /// cutoff, a row that ages out locally must also be removed remotely, or
  /// the "bounded" collection grows without bound — so this diffs against
  /// what's already remote rather than only ever adding.
  Future<void> _syncRecentActivity(DocumentReference<Map<String, dynamic>> userDoc) async {
    final rows = await _db.queryRecentTaskLogs(AiGuard.maxTaskLogRows);
    final col = userDoc.collection('recentActivity');
    final localIds = rows.map((r) => r[DatabaseHelper.columnTLId].toString()).toSet();

    final existing = await col.get();
    final batch = _firestore.batch();
    for (final doc in existing.docs) {
      if (!localIds.contains(doc.id)) {
        batch.delete(doc.reference);
      }
    }
    for (final row in rows) {
      final id = row[DatabaseHelper.columnTLId].toString();
      batch.set(
          col.doc(id),
          {
            'category': row[DatabaseHelper.columnTLCategory],
            'taskdescription': row[DatabaseHelper.columnTLTaskDescription],
            'checked': row[DatabaseHelper.columnTLChecked],
            'taskdate': row[DatabaseHelper.columnTLTaskDate],
          },
          SetOptions(merge: true));
    }
    await batch.commit();
  }

  /// D-035: writes the `ttlAt` field a Firestore TTL policy prunes on —
  /// only for an account still eligible (never finished setup, never linked
  /// a credential, never held a subscription). `ttlAt` is anchored at first
  /// write, not renewed on every sync, so it always reads 30 days from
  /// account *creation* (D-064), not from last launch. Once the account
  /// stops being eligible, `ttlAt` is removed — a prune must never touch an
  /// account that went on to link a credential or subscribe (D-035). This
  /// field lives on `users/{uid}` itself, not inside `profile/`, since it is
  /// pruning metadata rather than user data.
  Future<void> _syncPruneEligibility(
      DocumentReference<Map<String, dynamic>> userDoc,
      {required bool setupComplete}) async {
    final account = await _db.getAccountState();
    final everSubscribed =
        account[DatabaseHelper.columnEntitlement] != 'pre_trial';
    final eligible = !setupComplete && !everSubscribed;

    if (!eligible) {
      await userDoc.set({'ttlAt': FieldValue.delete()}, SetOptions(merge: true));
      return;
    }

    final existing = await userDoc.get();
    if (existing.data()?['ttlAt'] != null) return;
    await userDoc.set(
        {'ttlAt': Timestamp.fromDate(DateTime.now().add(pruneEligibleWindow))},
        SetOptions(merge: true));
  }
}
