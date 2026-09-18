import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/services/lapsed_notification_pool.dart';

void main() {
  group('D-049: the lapsed static notification pool', () {
    test('D-049: exactly one pool of six entries', () {
      expect(LapsedNotificationPool.pool.length, 6);
    });

    test(
        'D-049: no entry contains user-specific data (a smoke check — the '
        'pool is a fixed literal, so this really just guards against a '
        'future edit accidentally interpolating something)', () {
      for (final entry in LapsedNotificationPool.pool) {
        expect(entry, isNot(contains('\$')));
      }
    });

    test(
        'D-049: every static preview is an inspiring quip of five words or fewer',
        () {
      for (final entry in LapsedNotificationPool.pool) {
        expect(entry.trim().split(RegExp(r'\s+')).length, lessThanOrEqualTo(5));
      }
    });

    test(
        'rotation cycles deterministically through all six entries across '
        'two days', () {
      final seen = <String>{};
      for (var day = 0; day < 2; day++) {
        for (var slot = 0; slot < 3; slot++) {
          seen.add(
              LapsedNotificationPool.forSlot(slotIndex: slot, dayIndex: day));
        }
      }
      expect(seen.length, 6,
          reason: 'two days of three slots should cover the whole pool once');
    });

    test(
        'the same slot/day pair always returns the same entry '
        '(deterministic, not random)', () {
      final a = LapsedNotificationPool.forSlot(slotIndex: 1, dayIndex: 3);
      final b = LapsedNotificationPool.forSlot(slotIndex: 1, dayIndex: 3);
      expect(a, b);
    });
  });
}
