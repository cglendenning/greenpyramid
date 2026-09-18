import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // D-168-AC-01 / D-168-AC-06: consumer lifetime-card visibility and revoke wiring.
  // D-167-AC-04: the consumer Settings surface uses the authenticated
  // entitlement service and persists the server-owned lifetime result.
  test('D-167-AC-04: Settings exposes lifetime redemption and cache support', () {
    final settings = File('lib/screens/settings.dart').readAsStringSync();
    final entitlement = File('lib/services/entitlement_service.dart').readAsStringSync();
    final db = File('lib/services/db.dart').readAsStringSync();
    expect(settings, contains('_LifetimeCodePanel'));
    expect(settings, contains('Redeem code'));
    expect(settings, contains('Lifetime subscription code'));
    expect(entitlement, contains('redeemLifetimeCode'));
    expect(entitlement, contains('currentLocalLifetimeAccess'));
    expect(db, contains('columnLifetimeAccess'));
    expect(db, contains('_databaseVersion = 25'));
  });

  // D-167-AC-06: both app surfaces and the local migration are part of the
  // release verification scope.
  test('D-167-AC-06: consumer and admin source contain the lifetime feature', () {
    expect(File('admin/lib/main.dart').readAsStringSync(), contains('/adminLifetimeCode'));
    expect(File('lib/screens/settings.dart').readAsStringSync(), contains('D-167'));
  });
}
