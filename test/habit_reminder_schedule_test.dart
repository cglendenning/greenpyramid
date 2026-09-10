import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/services/notification.dart';

/// D-124 Phase 3: the "starting soon" reminder scheduling math — pure,
/// so it's testable without a live notification plugin, the same
/// pattern this codebase already uses for `CalendarService.anchorFor`.
void main() {
  group('D-124: habitReminderId — stable, collision-free per habit+day', () {
    test('distinct ids for distinct weekdays of the same habit', () {
      final ids = {
        for (var d = DateTime.monday; d <= DateTime.sunday; d++)
          habitReminderId(5, d)
      };
      expect(ids.length, 7);
    });

    test('distinct ids for distinct habits on the same weekday', () {
      expect(habitReminderId(5, DateTime.monday),
          isNot(habitReminderId(6, DateTime.monday)));
    });

    test('deterministic — same inputs, same id', () {
      expect(habitReminderId(5, DateTime.monday),
          habitReminderId(5, DateTime.monday));
    });
  });

  group('D-124: buildHabitReminderSlots', () {
    test('empty activeWeekdays produces no slots', () {
      final slots = buildHabitReminderSlots(
        habitId: 1,
        hour: 7,
        minute: 0,
        activeWeekdays: const [],
        now: DateTime(2026, 9, 9, 6, 0),
      );
      expect(slots, isEmpty);
    });

    test('one slot per active weekday, fired leadMinutes before the '
        "habit's own time, on the correct future occurrence", () {
      // 2026-09-09 is a Wednesday.
      final now = DateTime(2026, 9, 9, 6, 0);
      final slots = buildHabitReminderSlots(
        habitId: 1,
        hour: 7,
        minute: 0,
        activeWeekdays: [DateTime.wednesday, DateTime.friday],
        leadMinutes: 10,
        now: now,
      );
      expect(slots, hasLength(2));

      final wed = slots.firstWhere((s) => s.weekday == DateTime.wednesday);
      expect(wed.fireTime, DateTime(2026, 9, 9, 6, 50),
          reason: 'today, since 6:50am is still ahead of the 6:00am clock');

      final fri = slots.firstWhere((s) => s.weekday == DateTime.friday);
      expect(fri.fireTime, DateTime(2026, 9, 11, 6, 50));
    });

    test("bumps to next week when today's slot time has already passed",
        () {
      // 2026-09-09 is a Wednesday, 8am — 6:50am reminder already passed.
      final now = DateTime(2026, 9, 9, 8, 0);
      final slots = buildHabitReminderSlots(
        habitId: 1,
        hour: 7,
        minute: 0,
        activeWeekdays: [DateTime.wednesday],
        leadMinutes: 10,
        now: now,
      );
      expect(slots.single.fireTime, DateTime(2026, 9, 16, 6, 50));
    });

    test('a lead time crossing midnight rolls the fire time onto the '
        "previous calendar day, but the slot's own weekday identity "
        "stays the habit's day, not the day it actually fires on", () {
      // 2026-09-09 is a Wednesday. A 00:05 habit with a 10-minute lead
      // reminds at 23:55 on Tuesday 2026-09-08.
      final now = DateTime(2026, 9, 8, 6, 0);
      final slots = buildHabitReminderSlots(
        habitId: 1,
        hour: 0,
        minute: 5,
        activeWeekdays: [DateTime.wednesday],
        leadMinutes: 10,
        now: now,
      );
      final slot = slots.single;
      expect(slot.weekday, DateTime.wednesday);
      expect(slot.fireTime, DateTime(2026, 9, 8, 23, 55));
    });

    test('each active weekday gets its own notificationId, matching '
        'habitReminderId', () {
      final slots = buildHabitReminderSlots(
        habitId: 42,
        hour: 7,
        minute: 0,
        activeWeekdays: [DateTime.monday, DateTime.thursday],
        now: DateTime(2026, 9, 1),
      );
      final ids = slots.map((s) => s.notificationId).toSet();
      expect(ids, {
        habitReminderId(42, DateTime.monday),
        habitReminderId(42, DateTime.thursday),
      });
    });
  });
}
