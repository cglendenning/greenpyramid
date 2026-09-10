import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/screens/schedule_habits_screen.dart';
import 'package:life_ops/services/db.dart';
import 'package:life_ops/services/utils.dart';

/// D-123 Phase 2: the scheduling screen's pure logic — snap-to-time,
/// collision detection, and the habit-row model — factored out so it's
/// testable without a live drag gesture or a registered calendar plugin,
/// matching this repo's established pattern for plugin-adjacent decision
/// logic (`CalendarService.daysOfWeekFrom`/`anchorFor`).
void main() {
  group('D-123: snapDropToTime — pixel offset to snapped hour/minute', () {
    test('snaps down to the nearest 15 minutes', () {
      // 62 px at 60 px/hour = 62 minutes, snaps down to 60.
      expect(snapDropToTime(62.0), (1, 0));
    });

    test('an exact 15-minute boundary stays put', () {
      // 90 px = 90 minutes = 1:30.
      expect(snapDropToTime(90.0), (1, 30));
    });

    test('a negative offset clamps to the start of the day', () {
      expect(snapDropToTime(-40.0), (0, 0));
    });

    test('an offset past the end of the day clamps so the full duration '
        'still fits before the day ends', () {
      // 24 hours * 60 px = 1440 px is midnight-next-day; a 15-minute habit
      // must end by then, so it clamps to 23:45, not 24:00.
      expect(snapDropToTime(2000.0, durationMinutes: 15), (23, 45));
    });

    test('a longer duration clamps its start earlier to still fit', () {
      expect(snapDropToTime(2000.0, durationMinutes: 60), (23, 0));
    });
  });

  group('D-123: intervalsOverlap — half-open interval overlap', () {
    test('two disjoint intervals do not overlap', () {
      final a0 = DateTime(2026, 1, 1, 7, 0);
      final a1 = DateTime(2026, 1, 1, 7, 15);
      final b0 = DateTime(2026, 1, 1, 7, 15);
      final b1 = DateTime(2026, 1, 1, 7, 30);
      expect(intervalsOverlap(a0, a1, b0, b1), isFalse,
          reason: 'back-to-back intervals share only a boundary instant');
    });

    test('overlapping intervals do overlap', () {
      final a0 = DateTime(2026, 1, 1, 7, 0);
      final a1 = DateTime(2026, 1, 1, 7, 20);
      final b0 = DateTime(2026, 1, 1, 7, 10);
      final b1 = DateTime(2026, 1, 1, 7, 30);
      expect(intervalsOverlap(a0, a1, b0, b1), isTrue);
    });

    test('one interval fully containing the other overlaps', () {
      final a0 = DateTime(2026, 1, 1, 6, 0);
      final a1 = DateTime(2026, 1, 1, 9, 0);
      final b0 = DateTime(2026, 1, 1, 7, 0);
      final b1 = DateTime(2026, 1, 1, 7, 15);
      expect(intervalsOverlap(a0, a1, b0, b1), isTrue);
    });
  });

  group('D-123: HabitScheduleRow.activeOn — the habit\'s own day flags, '
      'unchanged by scheduling', () {
    HabitScheduleRow habit({
      bool sunday = false,
      bool monday = false,
      bool tuesday = false,
      bool wednesday = false,
      bool thursday = false,
      bool friday = false,
      bool saturday = false,
    }) =>
        HabitScheduleRow(
          id: 1,
          category: 'Health',
          description: 'Walk',
          sunday: sunday,
          monday: monday,
          tuesday: tuesday,
          wednesday: wednesday,
          thursday: thursday,
          friday: friday,
          saturday: saturday,
          scheduledTime: null,
          scheduledEventId: null,
        );

    test('active only on its flagged days', () {
      final h = habit(monday: true, wednesday: true);
      expect(h.activeOn(DateTime(2026, 9, 7)), isTrue); // Monday
      expect(h.activeOn(DateTime(2026, 9, 9)), isTrue); // Wednesday
      expect(h.activeOn(DateTime(2026, 9, 8)), isFalse); // Tuesday
      expect(h.activeOn(DateTime(2026, 9, 6)), isFalse); // Sunday
    });

    test('every day flagged is active every day', () {
      final h = habit(
          sunday: true,
          monday: true,
          tuesday: true,
          wednesday: true,
          thursday: true,
          friday: true,
          saturday: true);
      for (var i = 6; i <= 12; i++) {
        expect(h.activeOn(DateTime(2026, 9, i)), isTrue);
      }
    });
  });

  group('D-123: HabitScheduleRow.parsedTime', () {
    HabitScheduleRow habitWithTime(String? time) => HabitScheduleRow(
          id: 1,
          category: 'Health',
          description: 'Walk',
          sunday: true,
          monday: true,
          tuesday: true,
          wednesday: true,
          thursday: true,
          friday: true,
          saturday: true,
          scheduledTime: time,
          scheduledEventId: null,
        );

    test('null when unscheduled', () {
      expect(habitWithTime(null).parsedTime, isNull);
    });

    test('parses HH:mm into (hour, minute)', () {
      expect(habitWithTime('07:05').parsedTime, (7, 5));
    });

    test('malformed time parses to null rather than throwing', () {
      expect(habitWithTime('not-a-time').parsedTime, isNull);
    });
  });

  group('D-123: HabitScheduleRow.fromMap — day flags come from the '
      "task table's text columns ('true'/'false'/''), via the shared "
      'Utils.toBoolean the rest of the day-of-week UI already uses', () {
    test('parses a fully-populated, scheduled row', () {
      final utils = Utils();
      final row = HabitScheduleRow.fromMap({
        DatabaseHelper.columnId: 5,
        DatabaseHelper.columnCategory: 'Health',
        DatabaseHelper.columnTaskDescription: 'Walk 20 minutes',
        DatabaseHelper.columnSunday: 'false',
        DatabaseHelper.columnMonday: 'true',
        DatabaseHelper.columnTuesday: 'false',
        DatabaseHelper.columnWednesday: 'true',
        DatabaseHelper.columnThursday: 'false',
        DatabaseHelper.columnFriday: 'true',
        DatabaseHelper.columnSaturday: 'false',
        DatabaseHelper.columnScheduledTime: '07:00',
        DatabaseHelper.columnScheduledCalendarEventId: 'native-event-1',
      }, utils);

      expect(row.id, 5);
      expect(row.description, 'Walk 20 minutes');
      expect(row.monday, isTrue);
      expect(row.tuesday, isFalse);
      expect(row.scheduledTime, '07:00');
      expect(row.scheduledEventId, 'native-event-1');
    });

    test('a row with no scheduled time yet parses both scheduling fields '
        'as null', () {
      final utils = Utils();
      final row = HabitScheduleRow.fromMap({
        DatabaseHelper.columnId: 6,
        DatabaseHelper.columnCategory: 'Health',
        DatabaseHelper.columnTaskDescription: 'Stretch',
        DatabaseHelper.columnSunday: 'true',
        DatabaseHelper.columnMonday: 'true',
        DatabaseHelper.columnTuesday: 'true',
        DatabaseHelper.columnWednesday: 'true',
        DatabaseHelper.columnThursday: 'true',
        DatabaseHelper.columnFriday: 'true',
        DatabaseHelper.columnSaturday: 'true',
        DatabaseHelper.columnScheduledTime: null,
        DatabaseHelper.columnScheduledCalendarEventId: null,
      }, utils);

      expect(row.scheduledTime, isNull);
      expect(row.scheduledEventId, isNull);
      expect(row.parsedTime, isNull);
      expect(row.durationMinutes, HabitScheduleRow.defaultDurationMinutes);
    });

    test('a row with an explicit duration parses and uses it, not the '
        'default', () {
      final utils = Utils();
      final row = HabitScheduleRow.fromMap({
        DatabaseHelper.columnId: 7,
        DatabaseHelper.columnCategory: 'Health',
        DatabaseHelper.columnTaskDescription: 'Deep clean',
        DatabaseHelper.columnSunday: 'true',
        DatabaseHelper.columnMonday: 'true',
        DatabaseHelper.columnTuesday: 'true',
        DatabaseHelper.columnWednesday: 'true',
        DatabaseHelper.columnThursday: 'true',
        DatabaseHelper.columnFriday: 'true',
        DatabaseHelper.columnSaturday: 'true',
        DatabaseHelper.columnScheduledTime: null,
        DatabaseHelper.columnScheduledCalendarEventId: null,
        DatabaseHelper.columnScheduledDurationMinutes: 60,
      }, utils);

      expect(row.scheduledDurationMinutes, 60);
      expect(row.durationMinutes, 60);
    });
  });

  group('D-123: HabitScheduleRow.durationMinutes — falls back to the '
      "default when the habit hasn't chosen one", () {
    HabitScheduleRow habit({int? durationMinutes}) => HabitScheduleRow(
          id: 1,
          category: 'Health',
          description: 'Walk',
          sunday: true,
          monday: true,
          tuesday: true,
          wednesday: true,
          thursday: true,
          friday: true,
          saturday: true,
          scheduledTime: null,
          scheduledEventId: null,
          scheduledDurationMinutes: durationMinutes,
        );

    test('no chosen duration falls back to the default (15 minutes)', () {
      expect(habit().durationMinutes, 15);
      expect(HabitScheduleRow.defaultDurationMinutes, 15);
    });

    test('an explicitly chosen duration is used verbatim, including a '
        'value shorter than the default', () {
      expect(habit(durationMinutes: 45).durationMinutes, 45);
      expect(habit(durationMinutes: 10).durationMinutes, 10);
    });
  });

  group('D-128: the iOS/Android edge-swipe-back gesture is disabled on this '
      'always-landscape screen', () {
    test('build() wraps its content in PopScope(canPop: false) — found '
        'live: swiping right near the left edge to scroll the bottom '
        'habit tray was frequently misread as an edge-swipe-back gesture '
        'and popped the whole screen instead of scrolling the tray', () {
      final source =
          File('lib/screens/schedule_habits_screen.dart').readAsStringSync();
      expect(source, contains('PopScope(canPop: false, child: _content(context))'));
    });

    test('the AppBar back arrow still calls Navigator.pop directly, which '
        'canPop: false does not gate — only the gesture is disabled, not '
        'the explicit back button', () {
      final source =
          File('lib/screens/schedule_habits_screen.dart').readAsStringSync();
      final leadingIdx = source.indexOf('leading: IconButton(');
      final popIdx = source.indexOf('onPressed: () => Navigator.pop(context)', leadingIdx);
      expect(leadingIdx, greaterThan(-1));
      expect(popIdx, greaterThan(leadingIdx));
    });
  });
}
