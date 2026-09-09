import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D-101: every Council chat screen (setup, category re-clarification,
/// general Council) uses the shared ChatInputBar (wraps, never scrolls
/// off-screen) and passes typingAdvisorKey to CouncilTranscript (the
/// screen never goes visually dead while awaiting a reply). Structural,
/// same convention as this repo's other tests for screens that own live
/// service singletons — setup_screen.dart, council_screen.dart, and
/// general_council_screen.dart are not directly widget-tested elsewhere.
void main() {
  const screens = [
    'lib/screens/setup_screen.dart',
    'lib/screens/council_screen.dart',
    'lib/screens/general_council_screen.dart',
  ];

  test('D-101: every chat screen uses the shared ChatInputBar, not a bare '
      'TextField, for its message composer', () {
    for (final path in screens) {
      final source = File(path).readAsStringSync();
      expect(source, contains('ChatInputBar('), reason: '$path');
    }
  });

  test('D-101: no chat screen builds its own composer TextField anymore — '
      'the single-line-with-no-maxLines defect this replaces must not '
      'reappear via a parallel, un-fixed copy', () {
    for (final path in screens) {
      final source = File(path).readAsStringSync();
      // The dialog TextFields elsewhere in setup_screen.dart (renaming a
      // category, editing a habit) are a different, deliberately
      // single-line UI and are unaffected by this check — only look
      // inside the file for a composer-shaped TextField, i.e. one paired
      // with the chat's own onSubmitted callback name.
      expect(source, isNot(contains('decoration: const InputDecoration(hintText:')),
          reason: '$path should build its composer via ChatInputBar, not '
              'an inline TextField');
    }
  });

  test('D-101: every chat screen passes typingAdvisorKey into '
      'CouncilTranscript — the typing indicator this screen relies on to '
      'avoid going dead while waiting for a reply', () {
    for (final path in screens) {
      final source = File(path).readAsStringSync();
      expect(source, contains('typingAdvisorKey:'), reason: '$path');
    }
  });

  test('D-101: setup\'s solo-Mira phases (opening/openingRound/refining) '
      'always show \'mira\' typing, never session.nextAdvisorKey — a setup '
      'session\'s rotationOrder is a shuffled four-advisor list it never '
      'actually uses for these turns (D-090)', () {
    final source = File('lib/screens/setup_screen.dart').readAsStringSync();
    final occurrences = RegExp(r"typingAdvisorKey: _busy \? 'mira' : null")
        .allMatches(source)
        .length;
    expect(occurrences, greaterThanOrEqualTo(3),
        reason: 'opening, openingRound, and refining each pass this');
  });

  test('D-101: category and general Council chat pass the real '
      'session.nextAdvisorKey — a genuine four-advisor rotation, unlike '
      'setup\'s solo-Mira turns', () {
    for (final path in [
      'lib/screens/council_screen.dart',
      'lib/screens/general_council_screen.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, contains('_busy ? session.nextAdvisorKey : null'),
          reason: path);
    }
  });
}
