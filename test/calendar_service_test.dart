import 'package:device_calendar_plus/device_calendar_plus.dart' as dc;
import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/services/calendar_service.dart';

/// D-025 step 7: no live calendar plugin is registered in this test
/// environment (no platform channel), so hasPermission/requestPermission
/// hit the plugin's MissingPluginException path — this is exactly the
/// defensive contract under test: a platform failure must never throw past
/// this class, since SyncService's whole batched write depends on it never
/// throwing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('hasPermission never throws — a platform-channel failure resolves '
      'to false', () async {
    final result = await CalendarService.instance.hasPermission();
    expect(result, isFalse);
  });

  test('requestPermission never throws — a platform-channel failure '
      'resolves to false', () async {
    final result = await CalendarService.instance.requestPermission();
    expect(result, isFalse);
  });

  test('summarizeToday returns null rather than throwing when permission '
      'cannot be determined', () async {
    final result = await CalendarService.instance.summarizeToday();
    expect(result, isNull);
  });

  group('D-123: createHabitEvent/rescheduleHabitEvent/deleteHabitEvent '
      'never throw — same defensive contract as the read-side methods, '
      'since no live plugin is registered in this test environment', () {
    test('createHabitEvent resolves to null rather than throwing', () async {
      final result = await CalendarService.instance.createHabitEvent(
        habitDescription: 'Walk 20 minutes',
        hour: 7,
        minute: 0,
        daysOfWeek: const [dc.DayOfWeek.monday, dc.DayOfWeek.wednesday],
      );
      expect(result, isNull);
    });

    test('createHabitEvent with no days resolves to null without ever '
        'reaching the plugin (no permission check needed to know this '
        'can\'t succeed)', () async {
      final result = await CalendarService.instance.createHabitEvent(
        habitDescription: 'Walk 20 minutes',
        hour: 7,
        minute: 0,
        daysOfWeek: const [],
      );
      expect(result, isNull);
    });

    test('rescheduleHabitEvent resolves to false rather than throwing',
        () async {
      final result = await CalendarService.instance.rescheduleHabitEvent(
        eventId: 'some-event-id',
        hour: 8,
        minute: 30,
        daysOfWeek: const [dc.DayOfWeek.friday],
      );
      expect(result, isFalse);
    });

    test('deleteHabitEvent resolves to false rather than throwing', () async {
      final result =
          await CalendarService.instance.deleteHabitEvent('some-event-id');
      expect(result, isFalse);
    });
  });

  group('D-123: daysOfWeekFrom — pure mapping from the task table\'s own '
      'Sunday-Saturday flags to the plugin\'s day-of-week enum', () {
    test('maps every day true to all seven, in Monday-first order '
        'matching the plugin\'s own enum declaration order', () {
      final days = CalendarService.daysOfWeekFrom(
        sunday: true,
        monday: true,
        tuesday: true,
        wednesday: true,
        thursday: true,
        friday: true,
        saturday: true,
      );
      expect(days, [
        dc.DayOfWeek.monday,
        dc.DayOfWeek.tuesday,
        dc.DayOfWeek.wednesday,
        dc.DayOfWeek.thursday,
        dc.DayOfWeek.friday,
        dc.DayOfWeek.saturday,
        dc.DayOfWeek.sunday,
      ]);
    });

    test('maps only the flagged days, dropping the rest', () {
      final days = CalendarService.daysOfWeekFrom(
        sunday: false,
        monday: true,
        tuesday: false,
        wednesday: true,
        thursday: false,
        friday: true,
        saturday: false,
      );
      expect(days,
          [dc.DayOfWeek.monday, dc.DayOfWeek.wednesday, dc.DayOfWeek.friday]);
    });

    test('every day false maps to an empty list', () {
      final days = CalendarService.daysOfWeekFrom(
        sunday: false,
        monday: false,
        tuesday: false,
        wednesday: false,
        thursday: false,
        friday: false,
        saturday: false,
      );
      expect(days, isEmpty);
    });
  });

  group('D-123: anchorFor — the first valid recurring-series anchor', () {
    test('today, at the given time, when today is one of the recurring '
        'days and that time hasn\'t passed yet', () {
      final now = DateTime(2026, 9, 9, 6, 0); // a Wednesday
      final anchor = CalendarService.anchorFor(
        hour: 7,
        minute: 0,
        daysOfWeek: const [dc.DayOfWeek.wednesday, dc.DayOfWeek.friday],
        now: now,
      );
      expect(anchor, DateTime(2026, 9, 9, 7, 0));
    });

    test('skips to the next matching day when today\'s time has already '
        'passed', () {
      final now = DateTime(2026, 9, 9, 8, 0); // Wednesday, 8am — past 7am
      final anchor = CalendarService.anchorFor(
        hour: 7,
        minute: 0,
        daysOfWeek: const [dc.DayOfWeek.wednesday, dc.DayOfWeek.friday],
        now: now,
      );
      expect(anchor, DateTime(2026, 9, 11, 7, 0)); // the following Friday
    });

    test('skips to the next matching day when today isn\'t one of the '
        'recurring days at all', () {
      final now = DateTime(2026, 9, 9, 6, 0); // Wednesday
      final anchor = CalendarService.anchorFor(
        hour: 7,
        minute: 0,
        daysOfWeek: const [dc.DayOfWeek.monday],
        now: now,
      );
      expect(anchor, DateTime(2026, 9, 14, 7, 0)); // the following Monday
    });

    test('throws for an empty daysOfWeek — never silently picks an '
        'arbitrary day', () {
      expect(
        () => CalendarService.anchorFor(
          hour: 7,
          minute: 0,
          daysOfWeek: const [],
          now: DateTime(2026, 9, 9),
        ),
        throwsArgumentError,
      );
    });
  });

  test('D-123: eventTitleFor prefixes every scheduled-habit event so it '
      'can be identified and later replaced or removed — matching '
      'Kansei\'s own "[GOAL]" identification convention', () {
    expect(CalendarService.eventTitleFor('Walk 20 minutes'),
        '[Green Pyramid] Walk 20 minutes');
  });
}
