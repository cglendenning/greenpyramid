import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/services/resonance_service.dart';

/// D-026: resonance scoring is ported as-is, AI-free.
void main() {
  group('D-026: resonance scoring is pure and AI-free', () {
    test('D-026: text under the minimum length scores zero', () {
      expect(ResonanceService.score('too short'), 0.0);
    });

    test('D-026: a bare, unconvicted long statement scores above zero from '
        'length alone', () {
      final text = 'x' * 200;
      expect(ResonanceService.score(text), greaterThan(0.0));
    });

    test('D-026: conviction markers raise the score above length alone', () {
      final plain = 'x' * 60;
      final withMarkers =
          'This matters to me because I promise myself I refuse to give up, '
          'and honestly I am scared and proud at the same time, truly.';
      expect(ResonanceService.score(withMarkers),
          greaterThan(ResonanceService.score(plain)));
    });

    test('D-026: score never exceeds 1.0 regardless of length or marker '
        'density', () {
      final saturated = (('because i want i need matters to me proud scared '
                  'afraid promise refuse ') *
              10)
          .trim();
      expect(ResonanceService.score(saturated), lessThanOrEqualTo(1.0));
    });

    test('D-026: qualifies is true iff score is above zero', () {
      expect(ResonanceService.qualifies('too short'), isFalse);
      expect(
          ResonanceService.qualifies(
              'This is a long enough statement to pass the floor on length alone.'),
          isTrue);
    });

    test('D-026: minStatementLength is the documented floor of 40', () {
      expect(ResonanceService.minStatementLength, 40);
      expect(ResonanceService.score('x' * 39), 0.0);
      expect(ResonanceService.score('x' * 40), greaterThan(0.0));
    });
  });
}
