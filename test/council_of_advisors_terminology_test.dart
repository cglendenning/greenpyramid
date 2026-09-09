import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D-121: the essence-intro screen introduces the Council of Advisors —
/// who they are, with portraits and personalities — before the term is
/// used anywhere else in setup, and every user-facing "Council" mention
/// throughout the app says "Council of Advisors." Structural, matching
/// this repo's convention for setup_screen.dart and the other
/// live-singleton screens this change touches.
void main() {
  group('D-121: the essence-intro screen introduces the Council of '
      'Advisors before using the term', () {
    final source = File('lib/screens/setup_screen.dart').readAsStringSync();
    final start = source.indexOf('Widget _buildEssenceIntro()');
    late final String body;
    setUpAll(() {
      final end = source.indexOf('\n  Widget _buildTierIntro()', start);
      body = source.substring(start, end);
    });

    test('renders all four advisors from the shared AdvisorConfig, not a '
        'bespoke or partial list', () {
      expect(start, greaterThan(-1));
      expect(body, contains('AdvisorConfig.orderedKeys'));
      expect(body, contains('AdvisorConfig.forKey('));
    });

    test('shows each advisor\'s real portrait, not just a name', () {
      expect(body, contains('backgroundImage: AssetImage(advisor.assetPath)'));
    });

    test(
        'no longer misattributes the essence-deepening questions to "the '
        'Council" — D-106 already established essence-deepening always '
        'speaks as Mira alone, so the intro screen must say so too',
        () {
      expect(body, isNot(contains('The Council will ask')));
      expect(body, contains("you're talking with"));
    });

    test('explicitly names the concept before the term is used again', () {
      expect(body, contains('Council of Advisors'));
    });
  });

  test(
      'D-121: every user-facing "the/The Council" mention in setup_screen '
      'says "Council of Advisors" — regression test for the owner\'s '
      'report that "Council" appeared unexplained before this screen '
      'introduced it', () {
    final source = File('lib/screens/setup_screen.dart').readAsStringSync();
    // Every real (non-comment) occurrence of "Council" is followed by
    // " of Advisors" somewhere in the same string (possibly across an
    // adjacent-string-literal line break, hence the loose window).
    final lines = source.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('//')) continue;
      if (!line.contains('Council')) continue;
      if (line.contains('CouncilService') ||
          line.contains('CouncilClient') ||
          line.contains('CouncilTranscript') ||
          line.contains('_council')) {
        continue;
      }
      // Adjacent Dart string literals can split "Council of Advisors"
      // across a quote-and-whitespace join (e.g. 'of ' \n 'Advisors') —
      // strip quotes and collapse whitespace before checking so the
      // *rendered* string is what's actually being asserted on.
      final window = lines.skip(i).take(2).join(' ');
      final normalized =
          window.replaceAll(RegExp('[\'"]'), '').replaceAll(RegExp(r'\s+'), ' ');
      expect(normalized, contains('Council of Advisors'),
          reason: 'line ${i + 1}: "$line" — expected "Council of Advisors"');
    }
  });

  test(
      'D-121: the general Council screen\'s own title says "Council of '
      'Advisors"', () {
    final source =
        File('lib/screens/general_council_screen.dart').readAsStringSync();
    expect(source, contains("Text('The Council of Advisors')"));
  });

  test(
      'D-121: the home screen\'s menu item and paywall reason both say '
      '"Council of Advisors"', () {
    final source = File('lib/screens/homescreen.dart').readAsStringSync();
    expect(source, contains('Talk to the Council of Advisors'));
  });

  test(
      'D-121: settings.dart\'s two Council mentions (category '
      're-clarification, calendar access) both say "Council of Advisors"',
      () {
    final source = File('lib/screens/settings.dart').readAsStringSync();
    expect(source, contains('Revisit a category with the Council of Advisors'));
    expect(source, contains('Let the Council of Advisors see your calendar'));
  });

  test(
      'D-121: the lapsed-notification pool\'s Council mentions say '
      '"Council of Advisors" — this copy is quoted verbatim in the spec '
      '(D-063) and must match', () {
    final source =
        File('lib/services/lapsed_notification_pool.dart').readAsStringSync();
    expect(source, isNot(contains('The Council has been quiet')));
    expect(source, contains('The Council of Advisors has been quiet'));
  });
}
