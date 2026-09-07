import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/services/model_output_guard.dart';

/// Regression test for a defect that reached a real device: the Council's
/// category-derivation response included a literal `<UNKNOWN>` placeholder
/// as a category name, and nothing caught it before it rendered on screen.
void main() {
  group('looksLikePlaceholder', () {
    test('flags empty and whitespace-only strings', () {
      expect(looksLikePlaceholder(''), isTrue);
      expect(looksLikePlaceholder('   '), isTrue);
    });

    test('flags the exact defect: a bracketed placeholder token', () {
      expect(looksLikePlaceholder('<UNKNOWN>'), isTrue);
      expect(looksLikePlaceholder('<unknown>'), isTrue);
      expect(looksLikePlaceholder('<category name>'), isTrue);
    });

    test('flags bare junk words, case-insensitively', () {
      for (final w in ['unknown', 'UNKNOWN', 'undefined', 'null', 'n/a', 'none', 'todo']) {
        expect(looksLikePlaceholder(w), isTrue, reason: '"$w" should be flagged');
      }
    });

    test('does not flag a real category or habit name', () {
      for (final name in ['Health', 'Deep Work', "Kids' Time", 'Morning walk']) {
        expect(looksLikePlaceholder(name), isFalse, reason: '"$name" should NOT be flagged');
      }
    });

    test('does not flag real text that merely contains a junk substring', () {
      // "None of my business" contains "none" but is a real sentence, not
      // the bare token — guard against an over-eager substring match.
      expect(looksLikePlaceholder('None of my business is anyone else\'s'), isFalse);
    });
  });
}
