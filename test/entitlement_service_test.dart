import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/services/db.dart';
import 'package:life_ops/services/entitlement_service.dart';
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

/// D-057: only the locally-testable half of EntitlementService — pulling
/// the server's answer into the local cache, and reading that cache back —
/// is covered here. requestTrialAfterSetup/requestMigrationTrial are pure
/// network transport (App Check + Firebase Auth + the live backend) and are
/// verified live instead, the same convention CouncilClient's own transport
/// method follows.
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
    tempDir = await Directory.systemTemp.createTemp('gp_entitlement_test');
    PathProviderPlatform.instance = _TempPathProvider(tempDir.path);
  });
  tearDown(() async {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> seedProfile(FirebaseFirestore firestore, Map<String, dynamic> data) {
    return firestore.collection('users').doc(uid).collection('profile').doc('main').set(data);
  }

  test('D-057: pullFromServer mirrors a trialing entitlement, with its '
      'trial window, into the local cache', () async {
    final firestore = FakeFirebaseFirestore();
    await seedProfile(firestore, {
      'entitlement': 'trialing',
      'trialStartedAt': Timestamp.fromDate(DateTime.utc(2026, 6, 1)),
      'trialExpiresAt': Timestamp.fromDate(DateTime.utc(2026, 6, 4)),
    });
    final service = EntitlementService(db: db, firestore: firestore);

    await service.pullFromServer(uid);

    final account = await db.getAccountState();
    expect(account[DatabaseHelper.columnEntitlement], 'trialing');
    final storedExpiry = DateTime.parse(account[DatabaseHelper.columnTrialExpiresAt] as String);
    expect(storedExpiry.toUtc(), DateTime.utc(2026, 6, 4));
  });

  test('D-057: pullFromServer is a no-op when profile/main has no '
      'entitlement field yet (a brand-new, not-yet-synced account) — the '
      'local default is left alone rather than cleared', () async {
    final firestore = FakeFirebaseFirestore();
    await seedProfile(firestore, {'categories': []});
    final service = EntitlementService(db: db, firestore: firestore);

    await service.pullFromServer(uid);

    final account = await db.getAccountState();
    expect(account[DatabaseHelper.columnEntitlement], 'pre_trial');
  });

  test('D-057: pullFromServer reflects a subscribed account (as written by '
      'the RevenueCat webhook) into the local cache', () async {
    final firestore = FakeFirebaseFirestore();
    await seedProfile(firestore, {'entitlement': 'subscribed'});
    final service = EntitlementService(db: db, firestore: firestore);

    await service.pullFromServer(uid);

    expect(await service.isEntitled(), isTrue);
  });

  test('markSubscribedLocally sets the local cache to subscribed '
      'immediately, without touching Firestore', () async {
    final service = EntitlementService(db: db, firestore: FakeFirebaseFirestore());
    await service.markSubscribedLocally();
    expect(await service.isEntitled(), isTrue);
    final account = await db.getAccountState();
    expect(account[DatabaseHelper.columnEntitlement], 'subscribed');
  });

  test('D-016: isEntitled is true for trialing and subscribed, false for '
      'pre_trial and lapsed', () async {
    final service = EntitlementService(db: db, firestore: FakeFirebaseFirestore());

    await db.setAccountEntitlement(entitlement: 'pre_trial');
    expect(await service.isEntitled(), isFalse);

    await db.setAccountEntitlement(entitlement: 'lapsed');
    expect(await service.isEntitled(), isFalse);

    await db.setAccountEntitlement(entitlement: 'trialing');
    expect(await service.isEntitled(), isTrue);

    await db.setAccountEntitlement(entitlement: 'subscribed');
    expect(await service.isEntitled(), isTrue);
  });
}
