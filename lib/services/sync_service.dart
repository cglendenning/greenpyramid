import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'calendar_service.dart';
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
///   recentActivity/{id}         every task_log row, full history (D-171)
///   tasks/{id}                  every habit/task currently defined (D-096)
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
///
/// D-096: [restoreFromCloud] is the pull direction — the rest of this
/// class only ever pushes. A device with no real local pyramid (a fresh
/// install, or one that lost its data) calls it once, before setup would
/// otherwise start, to bring back what the account already has.
class SyncService {
  SyncService({FirebaseFirestore? firestore, DatabaseHelper? db, CalendarService? calendar})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _db = db ?? DatabaseHelper.instance,
        _calendar = calendar ?? CalendarService.instance;

  static final SyncService instance = SyncService();

  final FirebaseFirestore _firestore;
  final DatabaseHelper _db;
  final CalendarService _calendar;

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
        _syncTasks(userDoc),
        _syncRetentionEligibility(userDoc, setupComplete: setupComplete),
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

    // D-025 step 7: only ever synced when permission is already granted —
    // this never prompts. Explicitly deleted (not just omitted) when null,
    // so a user who revokes calendar access in system settings doesn't
    // leave a stale summary sitting in Firestore forever — merge:true never
    // removes a field that's simply left out of the payload.
    final calendarContext = await _calendar.summarizeToday();

    // D-057: entitlement/trialStartedAt/trialExpiresAt are server-authoritative
    // (granted by /requestTrial, transitioned by the RevenueCat webhook) —
    // never uploaded here. The local account_state copy is a downstream cache
    // (EntitlementService pulls it down), not a source pushed back up; pushing
    // it would let a stale client cache clobber a real subscribed/lapsed
    // transition on the next launch.
    // D-178: first name/email/phone are single account-level fields, the
    // same kind of value timezone already is — synced the same way. The
    // profile photo is deliberately excluded: it stays local-only
    // (owner's own choice — cloud photo storage would mean adding
    // Firebase Storage, a new integration not approved yet).
    await userDoc.collection('profile').doc('main').set(
        {
          'categories': categories,
          if (vision != null) 'visionStatement': vision,
          'timezone': account[DatabaseHelper.columnAccountTimezone],
          'calendarContext': calendarContext ?? FieldValue.delete(),
          'firstName': account[DatabaseHelper.columnFirstName] ?? FieldValue.delete(),
          'email': account[DatabaseHelper.columnEmail] ?? FieldValue.delete(),
          'phone': account[DatabaseHelper.columnPhone] ?? FieldValue.delete(),
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

  /// IV-D `recentActivity/{id}`: D-171 — every task_log row now syncs, not
  /// just a bounded recent window (D-075's original 250-row cap reversed
  /// outright, per the owner: "when I delete the app completely, all my
  /// checked off items need to come back"). Collection name kept as-is
  /// rather than renamed, to avoid stranding already-synced data under a
  /// new path — it now holds full history, not just "recent" activity.
  /// Diffs against what's already remote rather than only ever adding, so
  /// a row deleted locally (e.g. a category rename cascade) is also
  /// removed remotely.
  Future<void> _syncRecentActivity(DocumentReference<Map<String, dynamic>> userDoc) async {
    final rows = await _db.queryAllTaskLogs();
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

  /// IV-D `tasks/{id}`: every habit/task currently defined, keyed by its
  /// local row id. D-096: without this, restoring a pyramid from Firestore
  /// could bring back categories and essences but never the habits under
  /// them — the part of the app people actually check off daily. Diffs
  /// against what's already remote, the same reconcile pattern
  /// [_syncRecentActivity] already uses, since a habit can be deleted or
  /// edited locally and a pure-append sync would leave stale rows forever.
  Future<void> _syncTasks(DocumentReference<Map<String, dynamic>> userDoc) async {
    final rows = await _db.queryAllTasks();
    final col = userDoc.collection('tasks');
    final localIds = rows.map((r) => r[DatabaseHelper.columnId].toString()).toSet();

    final existing = await col.get();
    final batch = _firestore.batch();
    for (final doc in existing.docs) {
      if (!localIds.contains(doc.id)) {
        batch.delete(doc.reference);
      }
    }
    for (final row in rows) {
      final id = row[DatabaseHelper.columnId].toString();
      batch.set(
          col.doc(id),
          {
            'category': row[DatabaseHelper.columnCategory],
            'taskdescription': row[DatabaseHelper.columnTaskDescription],
            'sunday': row[DatabaseHelper.columnSunday],
            'monday': row[DatabaseHelper.columnMonday],
            'tuesday': row[DatabaseHelper.columnTuesday],
            'wednesday': row[DatabaseHelper.columnWednesday],
            'thursday': row[DatabaseHelper.columnThursday],
            'friday': row[DatabaseHelper.columnFriday],
            'saturday': row[DatabaseHelper.columnSaturday],
            'createdate': row[DatabaseHelper.columnCreateDate],
            // D-123: only the intended time syncs — the native calendar
            // event id is this device's own, meaningless on another one
            // (see restoreFromCloud's matching comment below).
            'scheduledtime': row[DatabaseHelper.columnScheduledTime],
          },
          SetOptions(merge: true));
    }
    await batch.commit();
  }

  /// D-096: the pull direction — brings a device with no real local
  /// pyramid back up to date from what the account already has in
  /// Firestore, rather than starting setup over. Returns whether real
  /// data was actually found and restored (false means this is a
  /// genuinely new account, and the caller should proceed to setup as
  /// normal).
  ///
  /// Deliberately partial, and disclosed as such: restores categories,
  /// each category's *current* essence (not the full version history —
  /// `essenceVersions` is provenance, not something the app's own
  /// behavior depends on), the vision statement, every habit/task, and
  /// (D-169/D-171) every check-off ever pushed by [_syncRecentActivity] —
  /// which, as of D-171, is all of it, not a bounded recent window.
  /// Domain findings (D-048, advisory-only per D-074) still do not
  /// restore — genuinely low-stakes to lose.
  ///
  /// D-169 amendment: check-off activity restore was originally left out
  /// entirely, reasoning "losing them costs nothing the app depends on
  /// to function." Found live, the hard way — a real reinstall-and-
  /// sign-back-in left every completed checkbox gone, discovered by the
  /// owner mid-session: "I uninstall the app and all of my check marks
  /// boxes are now gone when I signed back in." That reasoning was
  /// simply wrong: streaks, essence-redefinition timing, and every chart
  /// on the Visualizations screen all depend on this exact data.
  ///
  /// D-171 amendment: D-169's fix restored only whatever the push side's
  /// 250-row bound (D-075) had actually uploaded, so a device with more
  /// than 250 check-offs ever recorded still lost the older ones on a
  /// full reinstall. Owner: "the one defect that has to be fixed though
  /// is that when I delete the app completely, all my checked off items
  /// need to come back." Fixed by removing the bound on the push side
  /// ([_syncRecentActivity] now syncs every row) — this method's own read
  /// path needed no change, since it already read every document present
  /// in the collection, not a capped number.
  ///
  /// The "genuinely different, harder problem" this still doesn't attempt
  /// is reconciling two *independent* devices' overlapping history — this
  /// fix only covers restoring onto a device with no local history at
  /// all (a fresh install or a genuine reinstall), which has nothing to
  /// reconcile against.
  Future<bool> restoreFromCloud(String uid) async {
    final userDoc = _firestore.collection('users').doc(uid);
    final profileSnap = await userDoc.collection('profile').doc('main').get();
    final profile = profileSnap.data();
    final categories = (profile?['categories'] as List<dynamic>?) ?? const [];

    // A placeholder-only or empty remote profile means there is nothing to
    // restore — the same check used locally (D-082) for "no real pyramid",
    // applied to what's in the cloud instead.
    final realCategories = categories
        .cast<Map<String, dynamic>>()
        .where((c) => !(c['cat'] as String? ?? 'Empty').startsWith('Empty'))
        .toList();
    if (realCategories.isEmpty) return false;

    for (final c in realCategories) {
      final id = (c['id'] as num).toInt();
      await _db.insertCategory({
        DatabaseHelper.columnCategoryId: id,
        DatabaseHelper.columnCat: c['cat'] as String,
        DatabaseHelper.columnPosition: c['position'] as int? ?? 0,
        if (c['created'] != null) DatabaseHelper.columnCategoryCreated: c['created'],
      });
      final essence = c['activeEssence'] as String?;
      if (essence != null && essence.isNotEmpty) {
        // D-166: insertCategoryEssence is itself a no-op when [essence]
        // matches the category's current latest version — this call used
        // to run unconditionally on every restore, manufacturing a
        // brand-new "version" identical to the existing one purely as a
        // side effect of syncing. Guarded downstream, not here, so every
        // caller benefits uniformly.
        await _db.insertCategoryEssence(
            categoryId: id, essence: essence, sourceSessionId: 'restored');
      }
    }

    final vision = profile?['visionStatement'] as String?;
    if (vision != null && vision.isNotEmpty) {
      await _db.insertVisionStatement(vision);
    }

    // D-178: first name/email/phone restore the same way timezone already
    // did — the profile photo is deliberately not restored here, since it
    // was never uploaded in the first place (local-only by design).
    final firstName = profile?['firstName'] as String?;
    if (firstName != null && firstName.isNotEmpty) {
      await _db.setFirstName(firstName);
    }
    final email = profile?['email'] as String?;
    if (email != null && email.isNotEmpty) {
      await _db.setEmail(email);
    }
    final phone = profile?['phone'] as String?;
    if (phone != null && phone.isNotEmpty) {
      await _db.setPhone(phone);
    }

    final tasksSnap = await userDoc.collection('tasks').get();
    for (final doc in tasksSnap.docs) {
      final t = doc.data();
      await _db.insertTask({
        DatabaseHelper.columnCategory: t['category'],
        DatabaseHelper.columnTaskDescription: t['taskdescription'],
        DatabaseHelper.columnSunday: t['sunday'] ?? 'true',
        DatabaseHelper.columnMonday: t['monday'] ?? 'true',
        DatabaseHelper.columnTuesday: t['tuesday'] ?? 'true',
        DatabaseHelper.columnWednesday: t['wednesday'] ?? 'true',
        DatabaseHelper.columnThursday: t['thursday'] ?? 'true',
        DatabaseHelper.columnFriday: t['friday'] ?? 'true',
        DatabaseHelper.columnSaturday: t['saturday'] ?? 'true',
        DatabaseHelper.columnCreateDate:
            t['createdate'] ?? DateTime.now().toIso8601String(),
        // D-123: the scheduled time itself restores — it's the user's
        // own stated intent. The native calendar event id deliberately
        // does not: it names an event on the *old* device's calendar,
        // which means nothing here and would make deleteHabitEvent/
        // rescheduleHabitEvent fail against a foreign, nonexistent id.
        // A restored device with a scheduledtime but no event id is the
        // signal a future screen needs to (re)create the native event
        // fresh, on this device.
        DatabaseHelper.columnScheduledTime: t['scheduledtime'],
      });
    }

    // D-169/D-171: restores every check-off _syncRecentActivity has
    // pushed — as of D-171, that's full history, not a bounded window.
    // No explicit id: insertTaskLog lets SQLite assign a fresh local
    // one, the same choice the tasks restore just above already makes.
    final activitySnap = await userDoc.collection('recentActivity').get();
    for (final doc in activitySnap.docs) {
      final a = doc.data();
      await _db.insertTaskLog({
        DatabaseHelper.columnTLCategory: a['category'],
        DatabaseHelper.columnTLTaskDescription: a['taskdescription'],
        DatabaseHelper.columnTLChecked: a['checked'],
        DatabaseHelper.columnTLTaskDate: a['taskdate'],
      });
    }

    return true;
  }

  /// D-064: cloud data for a `lapsed` account is purged 12 months after
  /// lapse — never the local SQLite copy (D-035), so a returning user still
  /// has their pyramid on-device.
  static const lapsedRetentionWindow = Duration(days: 365);

  /// D-035/D-064: writes the single `ttlAt` field a Firestore TTL policy
  /// prunes on. Both retention rules share this one field — discovered
  /// live, not assumed: Firestore allows only one TTL-enabled field per
  /// collection group, so D-064 cannot have its own `lapsedTtlAt` field
  /// alongside D-035's `ttlAt`. The two windows are mutually exclusive in
  /// practice (an account is never simultaneously "still in setup" and
  /// "lapsed"), so one field with two possible windows is correct, not a
  /// compromise. `ttlAt` is anchored at first write, not renewed on every
  /// sync, so it always reads the full window from *whichever moment made
  /// it eligible* — account creation for D-035, first observed lapse for
  /// D-064 — never from last launch. It is removed the moment neither
  /// condition holds: a prune must never touch an account that went on to
  /// link a credential or subscribe (D-035), or that returned from lapsed
  /// (D-064's same promise). Lives on `users/{uid}` itself, not inside
  /// `profile/`, since it is pruning metadata rather than user data.
  Future<void> _syncRetentionEligibility(
      DocumentReference<Map<String, dynamic>> userDoc,
      {required bool setupComplete}) async {
    final account = await _db.getAccountState();
    final entitlement = account[DatabaseHelper.columnEntitlement];
    final everSubscribed = entitlement != 'pre_trial';
    final incompleteSetupEligible = !setupComplete && !everSubscribed;
    final lapsedEligible = entitlement == 'lapsed';

    if (!incompleteSetupEligible && !lapsedEligible) {
      await userDoc.set({'ttlAt': FieldValue.delete()}, SetOptions(merge: true));
      return;
    }

    final existing = await userDoc.get();
    if (existing.data()?['ttlAt'] != null) return;
    final window = lapsedEligible ? lapsedRetentionWindow : pruneEligibleWindow;
    await userDoc.set(
        {'ttlAt': Timestamp.fromDate(DateTime.now().add(window))},
        SetOptions(merge: true));
  }
}
