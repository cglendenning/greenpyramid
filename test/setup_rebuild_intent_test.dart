import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/models/board_session.dart';
import 'package:life_ops/services/account_reset_service.dart';
import 'package:life_ops/services/auth_service.dart';
import 'package:life_ops/services/council_client.dart';
import 'package:life_ops/services/council_service.dart';
import 'package:life_ops/services/db.dart';
import 'package:life_ops/services/local_pyramid_reset_service.dart';
import 'package:life_ops/services/setup_rebuild_intent.dart';
import 'package:life_ops/services/setup_service.dart';
import 'package:life_ops/services/setup_draft_store.dart';
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

class _FakeCouncilClient extends CouncilClient {
  @override
  Future<List<CategoryProposal>> deriveCategories({
    required String sessionId,
    required List<Map<String, String>> transcript,
    List<CategoryProposal>? existingCategories,
  }) async =>
      const [];
}

/// D-177: "Set up again" wipes only the local pyramid, because D-105's wipe
/// deliberately leaves Firestore recoverable for the sign-out case it was
/// written for. A signed-in rebuild therefore looked exactly like a
/// reinstall, so setup restored the cloud copy and reported the pyramid
/// already built — dropping the user back into the pyramid they had just
/// confirmed erasing.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late DatabaseHelper db;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('rebuild-intent');
    PathProviderPlatform.instance = _TempPathProvider(tempDir.path);
    SharedPreferences.setMockInitialValues({});
    db = DatabaseHelper.instance;
    await db.database;
  });

  tearDown(() async {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  SetupService buildService(FakeFirebaseFirestore firestore, MockFirebaseAuth auth) {
    final client = _FakeCouncilClient();
    final council =
        CouncilService(firestore: firestore, auth: auth, client: client);
    return SetupService(
      council: council,
      drafts: SetupDraftStore(db: db, cloud: firestore),
      db: db,
      client: client,
      sync: SyncService(firestore: firestore, db: db),
      auth: AuthService(auth: auth),
      accountReset: AccountResetService(firestore: firestore, auth: auth),
    );
  }

  /// A signed-in, non-anonymous account whose cloud profile holds a real
  /// pyramid — the state both a reinstall and a rebuild start from.
  Future<FakeFirebaseFirestore> cloudWithPyramid(String uid) async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc(uid).collection('profile').doc('main').set({
      'categories': [
        {'id': 1, 'cat': 'Health', 'description': 'Body', 'position': 1},
        {'id': 2, 'cat': 'Craft', 'description': 'Work', 'position': 2},
      ],
      'setupComplete': true,
    });
    return firestore;
  }

  test('D-177-AC-01: the rebuild marker is single use', () async {
    expect(await SetupRebuildIntent.instance.consume(), isFalse);
    await SetupRebuildIntent.instance.record();
    expect(await SetupRebuildIntent.instance.consume(), isTrue);
    expect(await SetupRebuildIntent.instance.consume(), isFalse,
        reason: 'one confirmation must grant exactly one rebuild');
  });

  test('D-177-AC-02: a confirmed rebuild starts a fresh setup session '
      'instead of restoring the cloud pyramid', () async {
    const uid = 'u-rebuild';
    final auth = MockFirebaseAuth(
        signedIn: true, mockUser: MockUser(uid: uid, isAnonymous: false));
    final firestore = await cloudWithPyramid(uid);
    final svc = buildService(firestore, auth);

    // Exactly what "Set up again" does: record intent, then wipe locally.
    await SetupRebuildIntent.instance.record();
    await LocalPyramidResetService(dbHelper: db).wipeLocalPyramid();

    final session = await svc.startOrResumeSetup();
    expect(session.type, BoardSessionType.setup);

    final rows = await db.queryCategories();
    final real = rows.where(
        (r) => !(r[DatabaseHelper.columnCat] as String).startsWith('Empty'));
    expect(real, isEmpty,
        reason: 'the cloud pyramid must not have been restored over the wipe');
  });

  test('D-177-AC-03: without the marker a signed-in account with no local '
      'pyramid still restores from the cloud and reports it already built',
      () async {
    const uid = 'u-reinstall';
    final auth = MockFirebaseAuth(
        signedIn: true, mockUser: MockUser(uid: uid, isAnonymous: false));
    final firestore = await cloudWithPyramid(uid);
    final svc = buildService(firestore, auth);

    // Same starting state, no rebuild confirmation: this is a reinstall and
    // the existing behaviour must be untouched.
    await LocalPyramidResetService(dbHelper: db).wipeLocalPyramid();

    await expectLater(svc.startOrResumeSetup(),
        throwsA(isA<SetupAlreadyCompleteException>()));
  });

  test('D-177-AC-04: an abandoned rebuild resumes the in-progress setup '
      'rather than restoring the cloud pyramid over it', () async {
    const uid = 'u-abandoned';
    final auth = MockFirebaseAuth(
        signedIn: true, mockUser: MockUser(uid: uid, isAnonymous: false));
    final firestore = await cloudWithPyramid(uid);
    final svc = buildService(firestore, auth);

    await SetupRebuildIntent.instance.record();
    await LocalPyramidResetService(dbHelper: db).wipeLocalPyramid();
    final started = await svc.startOrResumeSetup();

    // The user walks away and comes back. The marker is spent, but D-148's
    // active-session resume runs first, so the half-finished rebuild is
    // picked up where it stopped instead of the wiped pyramid reappearing.
    final second = buildService(firestore, auth);
    final resumed = await second.startOrResumeSetup();
    expect(resumed.sessionId, started.sessionId);

    final rows = await db.queryCategories();
    final real = rows.where(
        (r) => !(r[DatabaseHelper.columnCat] as String).startsWith('Empty'));
    expect(real, isEmpty,
        reason: 'an abandoned rebuild must not silently revert itself');
  });
}
