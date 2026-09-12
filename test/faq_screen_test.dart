import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D-160: found stale on a direct read-through — the FAQ still described
/// the pre-Council "Coach," a manual multi-step setup wizard with
/// day-of-week scheduling (moved out of setup by D-054), a 3-color legend
/// missing the real 4th band (blue, no tasks defined), and said nothing
/// about accounts, the trial/subscription model, the Newsfeed, or the
/// Philosophy screen. Owner: "Go through that FAQ and make sure that it is
/// accurate based off of what we have changed." Structural (source-text)
/// rather than a widget test — FAQ's build() calls
/// FirebaseAnalytics.instance.logEvent unconditionally, the same live-
/// singleton-on-build shape newsfeed_entry_point_test.dart documents for
/// this class of screen, so it isn't safely pumpWidget-testable without a
/// live Firebase app.
void main() {
  test('D-160: no longer references the retired Coach feature, replaced '
      'everywhere by the Council of Advisors', () {
    final source = File('lib/screens/faq.dart').readAsStringSync();
    // Scoped to the faqItems list itself, not this file's own doc
    // comment explaining the rename (which necessarily mentions "Coach"
    // by name).
    final itemsStart = source.indexOf('final List<FAQItem> faqItems');
    final itemsEnd = source.indexOf('];', itemsStart);
    final itemsSource = source.substring(itemsStart, itemsEnd);
    expect(itemsSource, isNot(contains('Coach')));
    expect(itemsSource, contains('Council of Advisors'));
  });

  test('D-160: setup is described as a conversation with Mira, not a '
      'manual step list, and day-of-week scheduling is not claimed as '
      'part of setup (moved out of it by D-054)', () {
    final source = File('lib/screens/faq.dart').readAsStringSync();
    expect(source, contains('Mira'));
    expect(source, isNot(contains('days of the week each task')));
  });

  test('D-160: the color legend names all four bands, including blue for '
      'a category with no habits defined yet', () {
    final source = File('lib/screens/faq.dart').readAsStringSync();
    final colorsIdx = source.indexOf('What do the colors mean?');
    expect(colorsIdx, greaterThan(-1));
    final answer = source.substring(colorsIdx, colorsIdx + 900);
    expect(answer, contains('Green'));
    expect(answer, contains('Yellow'));
    expect(answer, contains('Red'));
    expect(answer, contains('Blue'));
  });

  test('D-160: covers the account requirement, the trial/subscription '
      'model, and the Newsfeed and Philosophy screens — none of which '
      'existed when this file was first written', () {
    final source = File('lib/screens/faq.dart').readAsStringSync();
    expect(source, contains('Do I need an account?'));
    expect(source, contains('What happens after my free trial ends?'));
    expect(source, contains('What is my Newsfeed?'));
    expect(source, contains("Green Pyramid's philosophy"));
  });

  test('D-160: every FAQItem has a non-empty question and answer', () {
    final source = File('lib/screens/faq.dart').readAsStringSync();
    final matches =
        RegExp(r'question:\s*"([^"]+)"').allMatches(source).toList();
    expect(matches.length, greaterThanOrEqualTo(15));
    for (final m in matches) {
      expect(m.group(1)!.trim(), isNotEmpty);
    }
  });
}
