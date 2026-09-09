import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D-116: a completed account with no real server entitlement gets its
/// trial grant retried on every launch, using pullFromServer's own return
/// value rather than the local cache — structural, matching this repo's
/// convention for main.dart's bootstrap (not directly unit-testable: it
/// drives live Firebase singletons with no injection point).
void main() {
  test(
      'D-116: the bootstrap retries a trial grant keyed off '
      'pullFromServer\'s return value, not the local entitlement cache — '
      'regression test for a defect found live: a device whose original '
      'requestTrialAfterSetup() call failed kept a stale local '
      '"trialing" cache that permanently masked any check against it',
      () {
    final source = File('lib/main.dart').readAsStringSync();
    final pullIdx = source.indexOf('hasServerEntitlement');
    expect(pullIdx, greaterThan(-1));
    expect(source, contains('await EntitlementService.instance.pullFromServer(uid)'));
    expect(source, contains('!hasServerEntitlement'));
    expect(source, isNot(contains("account[DatabaseHelper.columnEntitlement] == 'pre_trial'")),
        reason: 'must no longer decide the retry from the local cache');
  });

  test(
      'D-116: which grant is retried depends on hasEverCreatedSetupSession '
      '— a real Council setup gets D-058\'s normal grant retried, an '
      'account with no Council setup (the D-034 migration cohort) still '
      'gets D-071\'s one-time 30-day grant', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(source, contains('CouncilService.instance.hasEverCreatedSetupSession()'));
    final wentThroughIdx = source.indexOf('wentThroughCouncilSetup');
    expect(wentThroughIdx, greaterThan(-1));
    final requestTrialIdx = source.indexOf('requestTrialAfterSetup()', wentThroughIdx);
    final requestMigrationIdx = source.indexOf('requestMigrationTrial()', wentThroughIdx);
    expect(requestTrialIdx, greaterThan(wentThroughIdx));
    expect(requestMigrationIdx, greaterThan(requestTrialIdx));
  });
}
