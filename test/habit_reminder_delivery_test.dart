import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/services/notification.dart';

/// D-179: the "starting soon" reminder was scheduled correctly and never
/// delivered. Reproduced on an iOS simulator: iOS moves a notification
/// attachment's file into its private attachment data store when it
/// validates the request, so the second request reusing that path fails
/// with `UNErrorDomain 100 "Invalid attachment file URL"` — which the
/// plugin raises as a PlatformException that nothing caught.
void main() {
  group('D-179 reminder slot economy', () {
    test(
        'D-179-AC-01: a habit active every day collapses to one '
        'daily-repeating reminder instead of seven weekly ones', () {
      final slots = buildHabitReminderSlots(
        habitId: 7,
        hour: 9,
        minute: 0,
        activeWeekdays: const [
          DateTime.monday,
          DateTime.tuesday,
          DateTime.wednesday,
          DateTime.thursday,
          DateTime.friday,
          DateTime.saturday,
          DateTime.sunday,
        ],
        now: DateTime(2026, 9, 19, 6, 0),
      );

      expect(slots, hasLength(1));
      expect(slots.single.weekday, habitReminderDailySlot);
      expect(slots.single.notificationId,
          habitReminderId(7, habitReminderDailySlot));
      expect(slots.single.fireTime, DateTime(2026, 9, 19, 8, 50));
    });

    test(
        'D-179-AC-01: the collapsed daily reminder rolls to tomorrow when '
        "today's lead time has already passed", () {
      final slots = buildHabitReminderSlots(
        habitId: 7,
        hour: 9,
        minute: 0,
        activeWeekdays: const [
          DateTime.monday,
          DateTime.tuesday,
          DateTime.wednesday,
          DateTime.thursday,
          DateTime.friday,
          DateTime.saturday,
          DateTime.sunday,
        ],
        now: DateTime(2026, 9, 19, 12, 0),
      );

      expect(slots, hasLength(1));
      expect(slots.single.fireTime, DateTime(2026, 9, 20, 8, 50));
    });

    test(
        'D-179-AC-01: a habit active on fewer than seven days still gets '
        'one weekly slot per active day', () {
      final slots = buildHabitReminderSlots(
        habitId: 7,
        hour: 9,
        minute: 0,
        activeWeekdays: const [
          DateTime.monday,
          DateTime.tuesday,
          DateTime.wednesday,
          DateTime.thursday,
          DateTime.friday,
          DateTime.saturday,
        ],
        now: DateTime(2026, 9, 19, 6, 0),
      );

      expect(slots, hasLength(6));
      expect(slots.map((slot) => slot.weekday),
          isNot(contains(habitReminderDailySlot)));
    });

    test(
        'D-179-AC-01: the daily slot never collides with a weekday slot of '
        'the same or an adjacent habit', () {
      final daily = habitReminderId(7, habitReminderDailySlot);
      final sameHabitWeekdays = [
        for (var day = DateTime.monday; day <= DateTime.sunday; day++)
          habitReminderId(7, day),
      ];
      final neighbourHabitIds = [
        habitReminderId(6, habitReminderDailySlot),
        for (var day = DateTime.monday; day <= DateTime.sunday; day++)
          habitReminderId(6, day),
        habitReminderId(8, habitReminderDailySlot),
      ];

      expect(sameHabitWeekdays, isNot(contains(daily)));
      expect(neighbourHabitIds, isNot(contains(daily)));
    });
  });

  group('D-179 orphan identification', () {
    test(
        'D-179-AC-04: a reminder id resolves back to the habit that owns '
        'it, so a reminder outliving its habit can be recognised', () {
      for (final habitId in [0, 1, 42, 999]) {
        for (var slot = habitReminderDailySlot;
            slot <= DateTime.sunday;
            slot++) {
          final id = habitReminderId(habitId, slot);
          expect(isHabitReminderId(id), isTrue);
          expect(habitIdFromReminderId(id), habitId);
        }
      }
    });

    test(
        'D-179-AC-04: the ids used by the daily fallbacks and the test '
        'notification are not mistaken for habit reminders', () {
      for (final id in [100, 101, 102, 999999]) {
        expect(isHabitReminderId(id), isFalse);
      }
    });
  });

  group('D-179 delivery contract', () {
    final source = File('lib/services/notification.dart').readAsStringSync();

    test(
        'D-179-AC-02: every iOS attachment is a disposable copy, never the '
        'shared artwork file iOS would consume', () {
      expect(source, contains('Future<String?> _disposableIosArtworkPath()'));
      // The shared file backs Android's big-picture style, which reads it at
      // display time; it must never be handed to an iOS attachment.
      expect(source,
          isNot(contains('DarwinNotificationAttachment(artworkPath)')));
      expect(source, contains('DarwinNotificationAttachment(iosArtworkPath)'));
    });

    test(
        'D-179-AC-02: a fresh copy is taken per reminder request, inside '
        'the slot loop rather than once for all seven', () {
      final loopStart = source.indexOf('for (final slot in slots) {');
      final loopEnd = source.indexOf('final pending =', loopStart);
      expect(loopStart, greaterThan(-1));
      expect(loopEnd, greaterThan(loopStart));
      expect(source.substring(loopStart, loopEnd),
          contains('await _disposableIosArtworkPath()'));
    });

    test(
        'D-179-AC-03: a rejected slot is caught and reported instead of '
        'escaping past the scheduling screen as an unhandled exception', () {
      final loopStart = source.indexOf('for (final slot in slots) {');
      final loopEnd = source.indexOf('final pending =', loopStart);
      final loop = source.substring(loopStart, loopEnd);
      expect(loop, contains('try {'));
      expect(loop, contains('} catch (e) {'));
      expect(loop, contains('was rejected'));
    });

    test(
        'D-179-AC-04: wiping the pyramid cancels the habit reminders its '
        'deleted habits left pending', () {
      final reset =
          File('lib/services/local_pyramid_reset_service.dart').readAsStringSync();
      expect(reset, contains('pruneOrphanHabitReminders(const <int>{})'));
      expect(source, contains('Future<List<int>> pruneOrphanHabitReminders'));
    });

    test(
        'D-179-AC-05: cancelling a habit covers the collapsed daily slot as '
        'well as the seven weekday slots', () {
      expect(source, contains('for (var slot = habitReminderDailySlot;'));
    });
  });
}
