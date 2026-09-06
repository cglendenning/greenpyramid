import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D-069/D-083: the coach persona and the three time-of-day AI commentary
/// screens are retired now that their real replacement (D-036's
/// server-generated notifications) exists. Structural — confirms both the
/// files and every reference to them are gone.
void main() {
  test('D-083: coach.dart, morning.dart, afternoon.dart, evening.dart no '
      'longer exist', () {
    for (final path in [
      'lib/screens/coach.dart',
      'lib/screens/morning.dart',
      'lib/screens/afternoon.dart',
      'lib/screens/evening.dart',
    ]) {
      expect(File(path).existsSync(), isFalse, reason: '$path should be deleted');
    }
  });

  test('D-069: no navigable surface reaches Coach — the Council is the '
      'app\'s only conversational surface', () {
    final offenders = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => f.readAsStringSync().contains('Coach('))
        .toList();
    expect(offenders, isEmpty);
  });

  test('D-083: no navigation route reaches a time-of-day screen', () {
    final source = File('lib/screens/homescreen.dart').readAsStringSync();
    expect(source, isNot(contains('Morning()')));
    expect(source, isNot(contains('Afternoon()')));
    expect(source, isNot(contains('Evening()')));
  });

  test('D-083: a stale /morning, /afternoon, or /evening notification tap '
      'lands on the pyramid, not an error route', () {
    final source = File('lib/screens/homescreen.dart').readAsStringSync();
    final morningIdx = source.indexOf("case '/morning':");
    expect(morningIdx, greaterThan(-1));
    // The three cases fall through together to one HomeScreenWidget builder.
    final nextBuilderIdx = source.indexOf('HomeScreenWidget()', morningIdx);
    expect(nextBuilderIdx, greaterThan(morningIdx));
  });
}
