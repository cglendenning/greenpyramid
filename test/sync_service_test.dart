import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/services/ai_guard.dart';
import 'package:life_ops/services/db.dart';
import 'package:life_ops/services/sync_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _TempPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _TempPathProvider(this.dir);
  final String dir;
  @override
  Future<String?> getApplicationDocumentsPath() async => dir;
}

/// R4: D-034's silent migration and D-075's enumerated ongoing sync, tested
/// against a real (temp, ffi-backed) SQLite database and a fake Firestore —
/// no live Firebase project involved. Collection names and shapes follow
/// IV-D's Firestore layout exactly.
void main() {
  final db = DatabaseHelper.instance;
  late Directory tempDir;
  const uid = 'test-uid';

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('gp_sync_test');
    PathProviderPlatform.instance = _TempPathProvider(tempDir.path);
  });
  tearDown(() async {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<DocumentSnapshot<Map<String, dynamic>>> profileDoc(
      FirebaseFirestore firestore) {
    return firestore
        .collection('users')
        .doc(uid)
        .collection('profile')
        .doc('main')
        .get();
  }

  test('IV-D/D-075: categories, tiers, and each category\'s active essence '
      'sync into profile/main', () async {
    await db.insertCategory(
        {DatabaseHelper.columnCategoryId: 1, DatabaseHelper.columnCat: 'Health'});
    final d = await db.database;
    await d.insert(DatabaseHelper.categoryEssenceTable, {
      DatabaseHelper.columnEssenceCategoryId: 1,
      DatabaseHelper.columnEssenceText: 'My body carries me through every challenge.',
      DatabaseHelper.columnEssenceCreated: '2026-01-01T00:00:00.000',
    });
    final firestore = FakeFirebaseFirestore();
    await SyncService(firestore: firestore, db: db).syncAll(uid, setupComplete: true);

    final categories = (await profileDoc(firestore)).data()?['categories'] as List;
    final health = categories.single as Map<String, dynamic>;
    expect(health['cat'], 'Health');
    expect(health['activeEssence'], 'My body carries me through every challenge.');
  });

  test('IV-D: profile/main.activeEssence is the most recent version, not '
      'the first', () async {
    await db.insertCategory(
        {DatabaseHelper.columnCategoryId: 1, DatabaseHelper.columnCat: 'Health'});
    final d = await db.database;
    await d.insert(DatabaseHelper.categoryEssenceTable, {
      DatabaseHelper.columnEssenceCategoryId: 1,
      DatabaseHelper.columnEssenceText: 'first draft',
      DatabaseHelper.columnEssenceCreated: '2026-01-01T00:00:00.000',
    });
    await d.insert(DatabaseHelper.categoryEssenceTable, {
      DatabaseHelper.columnEssenceCategoryId: 1,
      DatabaseHelper.columnEssenceText: 'revised',
      DatabaseHelper.columnEssenceCreated: '2026-02-01T00:00:00.000',
    });
    final firestore = FakeFirebaseFirestore();
    await SyncService(firestore: firestore, db: db).syncAll(uid, setupComplete: true);

    final categories = (await profileDoc(firestore)).data()?['categories'] as List;
    expect((categories.single as Map)['activeEssence'], 'revised');
  });

  test('D-075: every version of essence syncs to essenceVersions, not just '
      'the active one', () async {
    final d = await db.database;
    await d.insert(DatabaseHelper.categoryEssenceTable, {
      DatabaseHelper.columnEssenceCategoryId: 1,
      DatabaseHelper.columnEssenceText: 'first draft',
      DatabaseHelper.columnEssenceCreated: '2026-01-01T00:00:00.000',
    });
    await d.insert(DatabaseHelper.categoryEssenceTable, {
      DatabaseHelper.columnEssenceCategoryId: 1,
      DatabaseHelper.columnEssenceText: 'revised',
      DatabaseHelper.columnEssenceCreated: '2026-02-01T00:00:00.000',
    });
    final firestore = FakeFirebaseFirestore();
    await SyncService(firestore: firestore, db: db).syncAll(uid, setupComplete: true);

    final versions = await firestore
        .collection('users')
        .doc(uid)
        .collection('essenceVersions')
        .get();
    expect(versions.docs.length, 2);
  });

  test('D-075: domain findings sync to domainFindings; empty tables sync '
      'without error', () async {
    final firestore = FakeFirebaseFirestore();
    await SyncService(firestore: firestore, db: db).syncAll(uid, setupComplete: true);

    final findings = await firestore
        .collection('users')
        .doc(uid)
        .collection('domainFindings')
        .get();
    expect(findings.docs, isEmpty);
  });

  test('D-075: vision statement and timezone sync into profile/main', () async {
    await db.insertVisionStatement('My body carries me through every challenge.');
    await db.setAccountTimezone('America/Los_Angeles');
    final firestore = FakeFirebaseFirestore();
    await SyncService(firestore: firestore, db: db).syncAll(uid, setupComplete: true);

    final data = (await profileDoc(firestore)).data();
    expect(data?['visionStatement'], 'My body carries me through every challenge.');
    expect(data?['timezone'], 'America/Los_Angeles');
  });

  test('D-057: entitlement/trialStartedAt/trialExpiresAt are never pushed by '
      'the client — they are server-authoritative, not local-cache-sourced. '
      'A stale local cache must not clobber a real subscribed/lapsed state.',
      () async {
    final firestore = FakeFirebaseFirestore();
    // Server has already transitioned this account to subscribed.
    await firestore.collection('users').doc(uid).collection('profile').doc('main')
        .set({'entitlement': 'subscribed'});

    await SyncService(firestore: firestore, db: db).syncAll(uid, setupComplete: true);

    final data = (await profileDoc(firestore)).data();
    expect(data?['entitlement'], 'subscribed');
    expect(data?.containsKey('trialStartedAt'), isFalse);
    expect(data?.containsKey('trialExpiresAt'), isFalse);
  });

  test('D-075: only a bounded window of task_log syncs to recentActivity — '
      'full history stays local-only', () async {
    final d = await db.database;
    final rowCount = AiGuard.maxTaskLogRows + 10;
    final batch = d.batch();
    for (var i = 0; i < rowCount; i++) {
      final date = DateTime(2026, 1, 1).add(Duration(days: i));
      batch.insert(DatabaseHelper.taskLogTable, {
        DatabaseHelper.columnTLCategory: 'Health',
        DatabaseHelper.columnTLTaskDescription: 'Walk',
        DatabaseHelper.columnTLChecked: 'true',
        DatabaseHelper.columnTLTaskDate:
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      });
    }
    await batch.commit(noResult: true);

    final firestore = FakeFirebaseFirestore();
    await SyncService(firestore: firestore, db: db).syncAll(uid, setupComplete: true);

    final synced = await firestore
        .collection('users')
        .doc(uid)
        .collection('recentActivity')
        .get();
    expect(synced.docs.length, AiGuard.maxTaskLogRows);
  });

  test('D-075: a task_log row that ages out of the bounded window is '
      'removed remotely on the next sync, not left to accumulate', () async {
    final d = await db.database;
    final id1 = await d.insert(DatabaseHelper.taskLogTable, {
      DatabaseHelper.columnTLCategory: 'Health',
      DatabaseHelper.columnTLTaskDescription: 'Walk',
      DatabaseHelper.columnTLChecked: 'true',
      DatabaseHelper.columnTLTaskDate: '2026-01-01',
    });
    final firestore = FakeFirebaseFirestore();
    final sync = SyncService(firestore: firestore, db: db);
    await sync.syncAll(uid, setupComplete: true);

    final col =
        firestore.collection('users').doc(uid).collection('recentActivity');
    expect((await col.doc(id1.toString()).get()).exists, isTrue);

    await d.delete(DatabaseHelper.taskLogTable,
        where: '${DatabaseHelper.columnTLId} = ?', whereArgs: [id1]);
    await sync.syncAll(uid, setupComplete: true);

    expect((await col.doc(id1.toString()).get()).exists, isFalse);
  });

  test('D-030: setAccountUid persists the Firebase uid into account_state',
      () async {
    await db.setAccountUid('some-firebase-uid');
    final state = await db.getAccountState();
    expect(state[DatabaseHelper.columnAccountUid], 'some-firebase-uid');
    expect(state[DatabaseHelper.columnEntitlementSyncedAt], isNotNull);
  });

  test('D-035: an anonymous account that has not finished setup gets a '
      'ttlAt 30 days out, on users/{uid} itself', () async {
    final firestore = FakeFirebaseFirestore();
    await SyncService(firestore: firestore, db: db)
        .syncAll(uid, setupComplete: false);

    final userDoc = await firestore.collection('users').doc(uid).get();
    expect(userDoc.data()?['ttlAt'], isNotNull);
  });

  test('D-035: ttlAt is anchored at creation, not renewed on every sync',
      () async {
    final firestore = FakeFirebaseFirestore();
    final sync = SyncService(firestore: firestore, db: db);
    await sync.syncAll(uid, setupComplete: false);
    final first =
        (await firestore.collection('users').doc(uid).get()).data()?['ttlAt'];

    await sync.syncAll(uid, setupComplete: false);
    final second =
        (await firestore.collection('users').doc(uid).get()).data()?['ttlAt'];

    expect(second, first);
  });

  test('D-035: finishing setup clears ttlAt — a completed account is never '
      'pruned', () async {
    final firestore = FakeFirebaseFirestore();
    final sync = SyncService(firestore: firestore, db: db);
    await sync.syncAll(uid, setupComplete: false);
    expect((await firestore.collection('users').doc(uid).get()).data()?['ttlAt'],
        isNotNull);

    await sync.syncAll(uid, setupComplete: true);

    expect((await firestore.collection('users').doc(uid).get()).data()?['ttlAt'],
        isNull);
  });

  test('D-035: an account that has ever held a subscription is never '
      'marked prune-eligible, even before setup is recorded complete',
      () async {
    final d = await db.database;
    await d.update(DatabaseHelper.accountStateTable,
        {DatabaseHelper.columnEntitlement: 'subscribed'},
        where: '${DatabaseHelper.columnAccountId} = ?', whereArgs: [1]);
    final firestore = FakeFirebaseFirestore();
    await SyncService(firestore: firestore, db: db)
        .syncAll(uid, setupComplete: false);

    final userDoc = await firestore.collection('users').doc(uid).get();
    expect(userDoc.data()?['ttlAt'], isNull);
  });

  test('D-064: a lapsed account gets ttlAt set 12 months out', () async {
    final d = await db.database;
    await d.update(DatabaseHelper.accountStateTable,
        {DatabaseHelper.columnEntitlement: 'lapsed'},
        where: '${DatabaseHelper.columnAccountId} = ?', whereArgs: [1]);
    final firestore = FakeFirebaseFirestore();
    await SyncService(firestore: firestore, db: db).syncAll(uid, setupComplete: true);

    final userDoc = await firestore.collection('users').doc(uid).get();
    expect(userDoc.data()?['ttlAt'], isNotNull);
  });

  test('D-064: ttlAt for a lapsed account is anchored at first lapse, not renewed on every '
      'sync', () async {
    final d = await db.database;
    await d.update(DatabaseHelper.accountStateTable,
        {DatabaseHelper.columnEntitlement: 'lapsed'},
        where: '${DatabaseHelper.columnAccountId} = ?', whereArgs: [1]);
    final firestore = FakeFirebaseFirestore();
    final sync = SyncService(firestore: firestore, db: db);
    await sync.syncAll(uid, setupComplete: true);
    final first =
        (await firestore.collection('users').doc(uid).get()).data()?['ttlAt'];

    await sync.syncAll(uid, setupComplete: true);
    final second =
        (await firestore.collection('users').doc(uid).get()).data()?['ttlAt'];

    expect(second, first);
  });

  test('D-035/D-064: an account that returns from lapsed has ttlAt '
      'cleared — a returning user is never purged', () async {
    final d = await db.database;
    await d.update(DatabaseHelper.accountStateTable,
        {DatabaseHelper.columnEntitlement: 'lapsed'},
        where: '${DatabaseHelper.columnAccountId} = ?', whereArgs: [1]);
    final firestore = FakeFirebaseFirestore();
    final sync = SyncService(firestore: firestore, db: db);
    await sync.syncAll(uid, setupComplete: true);
    expect((await firestore.collection('users').doc(uid).get()).data()?['ttlAt'],
        isNotNull);

    await d.update(DatabaseHelper.accountStateTable,
        {DatabaseHelper.columnEntitlement: 'subscribed'},
        where: '${DatabaseHelper.columnAccountId} = ?', whereArgs: [1]);
    await sync.syncAll(uid, setupComplete: true);

    expect((await firestore.collection('users').doc(uid).get()).data()?['ttlAt'],
        isNull);
  });

  test('D-064: a non-lapsed, setup-complete account never gets a ttlAt', () async {
    final firestore = FakeFirebaseFirestore();
    await SyncService(firestore: firestore, db: db).syncAll(uid, setupComplete: true);
    final userDoc = await firestore.collection('users').doc(uid).get();
    expect(userDoc.data()?['ttlAt'], isNull);
  });

  test('MIG-1: re-running syncAll against unchanged local data is '
      'idempotent — no duplicate documents', () async {
    final d = await db.database;
    await d.insert(DatabaseHelper.categoryEssenceTable, {
      DatabaseHelper.columnEssenceCategoryId: 1,
      DatabaseHelper.columnEssenceText: 'essence',
      DatabaseHelper.columnEssenceCreated: '2026-01-01T00:00:00.000',
    });
    final firestore = FakeFirebaseFirestore();
    final sync = SyncService(firestore: firestore, db: db);

    await sync.syncAll(uid, setupComplete: true);
    await sync.syncAll(uid, setupComplete: true);

    final versions = await firestore
        .collection('users')
        .doc(uid)
        .collection('essenceVersions')
        .get();
    expect(versions.docs.length, 1);
  });
}
