import 'package:device_calendar_plus/device_calendar_plus.dart' as dc;
import 'package:flutter/foundation.dart';

import 'ai_guard.dart';

/// D-025 step 7: a minimal, read-only wrapper around the device calendar,
/// feeding P-8's context-sensitivity (D-037). Unlike Kansei's
/// `calendar_service.dart` — which schedules coaching sessions into the
/// calendar, a feature Green Pyramid has no equivalent of — this never
/// creates, edits, or deletes an event. Opt-in only, requested from
/// Settings, never on launch (matching D-065's push-permission discipline).
class CalendarService {
  CalendarService({dc.DeviceCalendar? calendar})
      : _calendar = calendar ?? dc.DeviceCalendar.instance;

  static final CalendarService instance = CalendarService();

  final dc.DeviceCalendar _calendar;

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

  /// Requesting `.full` is the only way to read — the plugin's gentler tier
  /// is add-only, the opposite of what this needs — but nothing in this
  /// class ever calls a write method. Called only from an explicit user
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

  static String _two(int n) => n.toString().padLeft(2, '0');
}
