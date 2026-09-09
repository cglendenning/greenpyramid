import 'package:device_calendar_plus/device_calendar_plus.dart' as dc;
import 'package:flutter/foundation.dart';

import 'ai_guard.dart';

/// D-025 step 7 / D-123: a wrapper around the device calendar, feeding
/// P-8's context-sensitivity (D-037) and, since D-123, writing real
/// events for scheduled habits — reversing this class's original
/// read-only design, ported from Kansei's own `calendar_service.dart`
/// (`goal-executor/lib/services/calendar_service.dart`) and adapted to
/// Green Pyramid's *recurring* habit model rather than Kansei's one-time
/// dated "session": one native event per habit, with a weekly recurrence
/// rule matching the habit's own Sunday-Saturday flags, not a fresh event
/// per occurrence. Opt-in only, requested from Settings, never on launch
/// (matching D-065's push-permission discipline) — every write method
/// below checks [hasPermission] itself rather than relying on the
/// plugin's own internal check, which is a no-op unless `autoPermissions`
/// has been configured (it never is here).
class CalendarService {
  CalendarService({dc.DeviceCalendar? calendar})
      : _calendar = calendar ?? dc.DeviceCalendar.instance;

  static final CalendarService instance = CalendarService();

  final dc.DeviceCalendar _calendar;

  /// D-123: the fixed prefix every native event this class writes
  /// carries, so it can be found and identified later — the same
  /// identification convention Kansei's own `[GOAL]` prefix establishes.
  static const String eventTitlePrefix = '[Green Pyramid]';

  static String eventTitleFor(String habitDescription) =>
      '$eventTitlePrefix $habitDescription';

  /// D-123: pure mapping from the task table's own Sunday-Saturday
  /// string flags to the plugin's day-of-week enum — factored out so
  /// it's testable without touching the (unmockable) calendar plugin at
  /// all, the same pattern this codebase already uses for other
  /// plugin-adjacent decision logic (e.g. `subscription_panel_logic.dart`).
  static List<dc.DayOfWeek> daysOfWeekFrom({
    required bool sunday,
    required bool monday,
    required bool tuesday,
    required bool wednesday,
    required bool thursday,
    required bool friday,
    required bool saturday,
  }) {
    final days = <dc.DayOfWeek>[];
    if (monday) days.add(dc.DayOfWeek.monday);
    if (tuesday) days.add(dc.DayOfWeek.tuesday);
    if (wednesday) days.add(dc.DayOfWeek.wednesday);
    if (thursday) days.add(dc.DayOfWeek.thursday);
    if (friday) days.add(dc.DayOfWeek.friday);
    if (saturday) days.add(dc.DayOfWeek.saturday);
    if (sunday) days.add(dc.DayOfWeek.sunday);
    return days;
  }

  static const Map<int, dc.DayOfWeek> _pluginDayByWeekday = {
    DateTime.monday: dc.DayOfWeek.monday,
    DateTime.tuesday: dc.DayOfWeek.tuesday,
    DateTime.wednesday: dc.DayOfWeek.wednesday,
    DateTime.thursday: dc.DayOfWeek.thursday,
    DateTime.friday: dc.DayOfWeek.friday,
    DateTime.saturday: dc.DayOfWeek.saturday,
    DateTime.sunday: dc.DayOfWeek.sunday,
  };

  /// D-123: the first valid anchor date/time for a new (or moved)
  /// recurring series — today at [hour]:[minute] if today's weekday is
  /// one of [daysOfWeek] and that time is still in the future, otherwise
  /// the next matching day within the coming week. A recurring series'
  /// anchor must itself fall on one of its own recurrence days; picking
  /// any other day here would create the exact ambiguity
  /// `updateRecurring`'s own documentation warns against. Pure — takes
  /// [now] explicitly so it's deterministic to test.
  static DateTime anchorFor({
    required int hour,
    required int minute,
    required List<dc.DayOfWeek> daysOfWeek,
    required DateTime now,
  }) {
    if (daysOfWeek.isEmpty) {
      throw ArgumentError.value(daysOfWeek, 'daysOfWeek', 'must not be empty');
    }
    for (var i = 0; i < 7; i++) {
      final day = DateTime(now.year, now.month, now.day).add(Duration(days: i));
      final candidate = DateTime(day.year, day.month, day.day, hour, minute);
      if (daysOfWeek.contains(_pluginDayByWeekday[candidate.weekday]) &&
          candidate.isAfter(now)) {
        return candidate;
      }
    }
    // Unreachable: daysOfWeek is non-empty and every weekday value appears
    // at least once within any 7-day window, so one of the 7 candidates
    // above always both matches a day and is in the future once i reaches
    // a full week out. Kept as a defensive total function, not a promise
    // this branch is live.
    throw StateError('No matching day found within the next 7 days');
  }

  /// Never throws — a platform-channel failure here must not take down
  /// SyncService's whole batched write (this is checked on every sync, for
  /// every account, including the vast majority that never touch calendar
  /// features at all).
  Future<bool> hasPermission() async {
    try {
      final status = await _calendar.hasPermissions();
      return status == dc.CalendarPermissionStatus.granted;
    } catch (e, st) {
      debugPrint('CalendarService.hasPermission failed: $e\n$st');
      return false;
    }
  }

  /// Requesting `.full` covers both reading (D-037's context) and writing
  /// (D-123's scheduled events) — the plugin's gentler `.writeOnly` tier
  /// would leave reading unavailable. Called only from an explicit user
  /// action (a Settings toggle), never automatically.
  Future<bool> requestPermission() async {
    try {
      final status = await _calendar.requestPermissions(level: dc.CalendarAccessLevel.full);
      return status == dc.CalendarPermissionStatus.granted;
    } catch (e, st) {
      debugPrint('CalendarService.requestPermission failed: $e\n$st');
      return false;
    }
  }

  /// A short, sanitized, single-line summary of today's remaining events —
  /// exactly what D-037 lists as permitted notification context. Returns
  /// null when permission isn't granted or there's nothing to summarize
  /// (an absent field, never a placeholder, per D-037's own acceptance
  /// criterion).
  Future<String?> summarizeToday({DateTime? now}) async {
    if (!await hasPermission()) return null;
    final today = now ?? DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(const Duration(days: 1));
    try {
      final events = await _calendar.listEvents(start, end);
      if (events.isEmpty) return null;
      final lines = events.take(8).map((e) {
        final title = AiGuard.sanitizeField(e.title, maxChars: 60);
        final time = '${_two(e.startDate.hour)}:${_two(e.startDate.minute)}';
        return '$time $title';
      });
      return lines.join('; ');
    } catch (e, st) {
      debugPrint('CalendarService.summarizeToday failed: $e\n$st');
      return null;
    }
  }

  /// D-123 Phase 2: the day's calendar events, for the scheduling screen's
  /// grid — both as visual context (busy blocks from the user's other
  /// calendars) and as collision-detection input. Excludes this class's
  /// own scheduled-habit events (identified by [eventTitlePrefix]), since
  /// those render separately, straight from each habit's own row, not
  /// re-derived from the calendar. Never throws — an empty list on any
  /// failure, matching every other method here.
  Future<List<dc.Event>> eventsForDay(DateTime day) async {
    if (!await hasPermission()) return [];
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    try {
      final events = await _calendar.listEvents(start, end);
      return events
          .where((e) => !e.title.startsWith(eventTitlePrefix))
          .toList();
    } catch (e, st) {
      debugPrint('CalendarService.eventsForDay failed: $e\n$st');
      return [];
    }
  }

  /// D-123: writes a new recurring event for a just-scheduled habit —
  /// recurs indefinitely (no end date) on exactly [daysOfWeek], the same
  /// days the habit is already active on. Returns the created event's id
  /// (to store on the task row via `columnScheduledCalendarEventId`), or
  /// null if permission isn't granted, no calendar is writable, or the
  /// write fails — never throws.
  Future<String?> createHabitEvent({
    required String habitDescription,
    required int hour,
    required int minute,
    required List<dc.DayOfWeek> daysOfWeek,
    Duration duration = const Duration(minutes: 15),
    DateTime? now,
  }) async {
    if (daysOfWeek.isEmpty) return null;
    if (!await hasPermission()) return null;
    try {
      final calendarId = await _writableCalendarId();
      if (calendarId == null) return null;
      final start = anchorFor(
        hour: hour,
        minute: minute,
        daysOfWeek: daysOfWeek,
        now: now ?? DateTime.now(),
      );
      return await _calendar.createEvent(
        calendarId: calendarId,
        title: eventTitleFor(habitDescription),
        startDate: start,
        endDate: start.add(duration),
        recurrenceRule: dc.WeeklyRecurrence(daysOfWeek: daysOfWeek),
      );
    } catch (e, st) {
      debugPrint('CalendarService.createHabitEvent failed: $e\n$st');
      return null;
    }
  }

  /// D-123: moves an already-scheduled habit's whole recurring series to
  /// a new time and/or set of days — [EventSpan.allEvents] plus an
  /// explicit [recurrenceRule] together (never just a moved `start`),
  /// since `updateRecurring`'s own contract treats moving an explicitly-
  /// dayed rule's anchor without also restating the rule as ambiguous.
  /// Never throws.
  Future<bool> rescheduleHabitEvent({
    required String eventId,
    required int hour,
    required int minute,
    required List<dc.DayOfWeek> daysOfWeek,
    Duration duration = const Duration(minutes: 15),
    DateTime? now,
  }) async {
    if (daysOfWeek.isEmpty) return false;
    if (!await hasPermission()) return false;
    try {
      final start = anchorFor(
        hour: hour,
        minute: minute,
        daysOfWeek: daysOfWeek,
        now: now ?? DateTime.now(),
      );
      await _calendar.updateRecurring(
        eventId,
        dc.EventSpan.allEvents,
        start: start,
        duration: duration,
        recurrenceRule: dc.Patch.set(dc.WeeklyRecurrence(daysOfWeek: daysOfWeek)),
      );
      return true;
    } catch (e, st) {
      debugPrint('CalendarService.rescheduleHabitEvent failed: $e\n$st');
      return false;
    }
  }

  /// D-123: removes a scheduled habit's native event entirely — called
  /// when the user unschedules it. Never throws.
  Future<bool> deleteHabitEvent(String eventId) async {
    if (!await hasPermission()) return false;
    try {
      await _calendar.deleteEvent(eventId: eventId);
      return true;
    } catch (e, st) {
      debugPrint('CalendarService.deleteHabitEvent failed: $e\n$st');
      return false;
    }
  }

  /// D-123: the first non-read-only calendar, preferring the device's
  /// primary — matching Kansei's own selection order (excluding calendars
  /// like iOS Holidays or a subscribed feed, which the plugin reports as
  /// read-only). Null if nothing is writable.
  Future<String?> _writableCalendarId() async {
    final calendars = await _calendar.listCalendars();
    final writable = calendars.where((c) => !c.readOnly).toList();
    if (writable.isEmpty) return null;
    final primary = writable.where((c) => c.isPrimary).toList();
    return (primary.isNotEmpty ? primary.first : writable.first).id;
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}
