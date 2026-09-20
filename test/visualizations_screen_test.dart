import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('D-170: Analysis is the six-page horizontal journey', () {
    final source = File('lib/screens/visualizations.dart').readAsStringSync();
    expect(source, contains('static const _pageCount = 6'));
    expect(source, contains('PageView.builder'));
    expect(source, contains('Swipe to keep going'));
    expect(source, isNot(contains('ListView')));
    for (final label in [
      'START HERE',
      'YOUR STRENGTH',
      'THE RHYTHM',
      'THE RETURN',
      'A GENTLE CLUE',
      'TAKE THIS WITH YOU',
    ]) {
      expect(source, contains(label));
    }
  });

  test('D-170: pages expose story semantics and honest empty-state copy', () {
    final source = File('lib/screens/visualizations.dart').readAsStringSync();
    expect(source, contains('Semantics('));
    expect(source, contains(r'Page ${index + 1} of ${pages.length}'));
    expect(source, contains('not enough history'));
    expect(source, contains('first check-in'));
    expect(source, contains('There is always a next day'));
  });
}
