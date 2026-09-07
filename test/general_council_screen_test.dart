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
}
