import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/services/auth_service.dart';
import 'package:life_ops/services/db.dart';
import 'package:life_ops/services/setup_rebuild_intent.dart';
import 'package:life_ops/services/setup_rebuild_service.dart';
import 'package:life_ops/services/sync_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _TempPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _TempPathProvider(this.dir);
  final String dir;
  @override
  Future<String?> getApplicationDocumentsPath() async => dir;
}

/// A sync service whose cloud erase always fails, standing in for being
/// offline at the moment the user confirms.
class _FailingSync extends SyncService {
  _FailingSync({required super.firestore, required super.db});
  @override
  Future<void> eraseCloudPyramid(String uid) async =>
      throw StateError('network unavailable');
}

/// D-177: a confirmed rebuild erases the cloud pyramid as well as the local
/// one, so nothing can restore it afterwards — and if the cloud erase fails,
/// nothing is erased at all.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late DatabaseHelper db;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('rebuild-erase');
    PathProviderPlatform.instance = _TempPathProvider(tempDir.path);
    SharedPreferences.setMockInitialValues({});
    db = DatabaseHelper.instance;
    await db.database;
  });

  tearDown(() async {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<FakeFirebaseFirestore> cloudWithPyramid(String uid) async {
    final firestore = FakeFirebaseFirestore();
    final user = firestore.collection('users').doc(uid);
    await user.collection('profile').doc('main').set({
      'categories': [
        {'id': 1, 'cat': 'Health', 'description': 'Body', 'position': 1},
      ],
      'visionStatement': 'I show up for the people I love.',
      'setupComplete': true,
      // Server-owned account state that must survive a pyramid rebuild.
      'entitlement': 'subscribed',
      'lifetimeAccess': true,
      'totalSpendUsd': 12.5,
    });
    await user.collection('tasks').doc('t1').set({'taskdescription': 'Walk'});
    await user.collection('recentActivity').doc('a1').set({'checked': 'true'});
    await user.collection('essenceVersions').doc('e1').set({'essence': 'old'});
    return firestore;
  }

  test('D-177-AC-04: the rebuild erases everything a restore would read',
      () async {
    const uid = 'u-erase';
    final firestore = await cloudWithPyramid(uid);
    final sync = SyncService(firestore: firestore, db: db);

    await sync.eraseCloudPyramid(uid);

    // Exactly the inputs restoreFromCloud consumes.
    final user = firestore.collection('users').doc(uid);
    final profile = (await user.collection('profile').doc('main').get()).data()!;
    expect(profile['categories'], isEmpty);
    expect(profile['visionStatement'], isNull);
    expect(profile['setupComplete'], isFalse);
    expect((await user.collection('tasks').get()).docs, isEmpty);
    expect((await user.collection('recentActivity').get()).docs, isEmpty);
    expect((await user.collection('essenceVersions').get()).docs, isEmpty);

    // And therefore nothing is restorable afterwards.
    expect(await sync.restoreFromCloud(uid), isFalse);
  });

  test('D-177-AC-05: erasing the pyramid leaves entitlement and spending '
      'untouched — a rebuild must not cost the user their subscription',
      () async {
    const uid = 'u-entitled';
    final firestore = await cloudWithPyramid(uid);
    await SyncService(firestore: firestore, db: db).eraseCloudPyramid(uid);

    final profile = (await firestore
            .collection('users')
            .doc(uid)
            .collection('profile')
            .doc('main')
            .get())
        .data()!;
    expect(profile['entitlement'], 'subscribed');
    expect(profile['lifetimeAccess'], isTrue);
    expect(profile['totalSpendUsd'], 12.5);
  });

  test('D-177-AC-06: a failed cloud erase leaves the local pyramid intact',
      () async {
    const uid = 'u-offline';
    final auth = MockFirebaseAuth(
        signedIn: true, mockUser: MockUser(uid: uid, isAnonymous: false));
    final firestore = await cloudWithPyramid(uid);
    await db.insertCategory({
      DatabaseHelper.columnCategoryId: 1,
      DatabaseHelper.columnCat: 'Health',
      DatabaseHelper.columnCategoryDescription: 'Body',
      DatabaseHelper.columnPosition: 1,
    });

    final service = SetupRebuildService(
      sync: _FailingSync(firestore: firestore, db: db),
      auth: AuthService(auth: auth),
      intent: SetupRebuildIntent.instance,
    );

    // The caller's local wipe sits after this call, so throwing here is what
    // keeps the device's pyramid intact.
    await expectLater(
        service.prepareRebuild(), throwsA(isA<SetupRebuildFailed>()));

    final rows = await db.queryCategories();
    final real = rows.where(
        (r) => !(r[DatabaseHelper.columnCat] as String).startsWith('Empty'));
    expect(real, isNotEmpty,
        reason: 'an offline user must not lose their pyramid');
    expect(await SetupRebuildIntent.instance.consume(), isFalse,
        reason: 'an aborted rebuild must not leave a marker behind');
  });

  test('D-177-AC-06: a successful preparation erases the cloud pyramid and '
      'records the marker, so the caller may then wipe locally', () async {
    const uid = 'u-ok';
    final auth = MockFirebaseAuth(
        signedIn: true, mockUser: MockUser(uid: uid, isAnonymous: false));
    final firestore = await cloudWithPyramid(uid);
    final sync = SyncService(firestore: firestore, db: db);
    await db.insertCategory({
      DatabaseHelper.columnCategoryId: 1,
      DatabaseHelper.columnCat: 'Health',
      DatabaseHelper.columnCategoryDescription: 'Body',
      DatabaseHelper.columnPosition: 1,
    });

    await SetupRebuildService(
      sync: sync,
      auth: AuthService(auth: auth),
      intent: SetupRebuildIntent.instance,
    ).prepareRebuild();

    expect(await sync.restoreFromCloud(uid), isFalse,
        reason: 'the erased pyramid must not come back on a later launch');
    expect(await SetupRebuildIntent.instance.consume(), isTrue,
        reason: 'setup must be told this is a rebuild, not a reinstall');
  });
}
