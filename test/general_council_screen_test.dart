import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D-091: a general Council conversation, not scoped to any category, is
/// reachable any time from the home screen — mirroring Kansei's own
/// "talk to the Council" entry point rather than confining Council access
/// to setup and per-category re-clarification. GeneralCouncilScreen owns
/// live service singletons (CouncilService.instance) the same way
/// SetupScreen and CouncilScreen do, so — same as those — this is a
/// source-structure test, not a widget test.
void main() {
  test('D-091: the home screen menu has a "Talk to the Council" entry that '
      'routes to GeneralCouncilScreen', () {
    final source = File('lib/screens/homescreen.dart').readAsStringSync();

    expect(source, contains("value: 'council'"));
    expect(source, contains('Talk to the Council'));

    final navStart = source.indexOf('void navigateToCouncil(');
    expect(navStart, greaterThan(-1));
    final navEnd = source.indexOf('\n  }', navStart);
    expect(source.substring(navStart, navEnd), contains('GeneralCouncilScreen'));
  });

  test('D-091: GeneralCouncilScreen opens a general-typed session, not a '
      'category-scoped one', () {
    final source =
        File('lib/screens/general_council_screen.dart').readAsStringSync();
    expect(source, contains('BoardSessionType.general'));
    expect(source, isNot(contains('categoryId')));
  });

  test(
      'D-032: _load() awaits sign-in before touching the Council session — '
      'regression test for a defect found live: "Could not open this '
      'conversation" on a fresh launch (a reinstall, or D-098\'s wipe). '
      'main.dart fires anonymous sign-in unawaited so it never gates the '
      'first frame — SetupScreen was already fixed for this exact race; '
      'GeneralCouncilScreen was added afterward and never got it.', () {
    final source =
        File('lib/screens/general_council_screen.dart').readAsStringSync();
    final loadStart = source.indexOf('Future<void> _load()');
    expect(loadStart, greaterThan(-1), reason: '_load() must exist');
    final loadEnd = source.indexOf('\n  Future<void> _runAdvisorTurn', loadStart);
    expect(loadEnd, greaterThan(loadStart));
    final loadBody = source.substring(loadStart, loadEnd);

    final signInIndex = loadBody.indexOf('AuthService.instance.signInSilently()');
    final sessionIndex = loadBody.indexOf('_council.getActiveSession(');
    expect(signInIndex, greaterThan(-1),
        reason: '_load() must await AuthService.instance.signInSilently() '
            'before creating/resuming a Council session');
    expect(sessionIndex, greaterThan(-1));
    expect(signInIndex, lessThan(sessionIndex),
        reason: 'sign-in must be awaited strictly before the Council '
            'session call, not after or in parallel');
  });

  test(
      'D-091: _load()\'s catch clause logs the actual failure — '
      'regression test for a defect found live: it was a silent catch, no '
      'log at all, so a real failure was undiagnosable without guessing',
      () {
    final source =
        File('lib/screens/general_council_screen.dart').readAsStringSync();
    final loadStart = source.indexOf('Future<void> _load()');
    final loadEnd = source.indexOf('\n  Future<void> _runAdvisorTurn', loadStart);
    final loadBody = source.substring(loadStart, loadEnd);
    expect(loadBody, contains('debugPrint('));
  });
}
