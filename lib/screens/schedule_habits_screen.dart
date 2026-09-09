import 'dart:async';

import 'package:device_calendar_plus/device_calendar_plus.dart' as dc;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

import 'package:life_ops/services/calendar_service.dart';
import 'package:life_ops/services/db.dart';
import 'package:life_ops/services/utils.dart';

/// D-123 Phase 2: drag a habit onto a time to give it a recurring
/// scheduled time, backed by a real native-calendar event. A direct port
/// of Kansei's `calendar_proposal_screen.dart` — the landscape, 7-day
/// week grid, the aqua draggable event box, the same long-press-to-pick-
/// up / 15-minute-snap / collision-detection / edge-auto-scroll / drag-
/// to-a-red-zone-to-remove interaction — with only the data-model
/// difference the two apps actually have: Kansei's `Session` is a
/// one-time block whose calendar DAY is chosen by which column you drop
/// it in. A Green Pyramid habit's active days are already fixed
/// elsewhere (its own Sunday–Saturday flags, set in `EditTaskDetail`),
/// so a habit already appears in every column matching those flags, all
/// at the same time — dragging changes that one shared time, never which
/// days the habit is active on; a drop on a day the habit isn't active
/// on is rejected rather than silently reinterpreted as a day-flag edit
/// (confirmed with the owner directly, 2026-09-09). Every write goes
/// straight to [CalendarService] and the database — Green Pyramid has no
/// equivalent of Kansei's per-session budget/draft state, so there is no
/// separate "confirm" step the way Kansei's screen has.
class ScheduleHabitsScreen extends StatefulWidget {
  const ScheduleHabitsScreen({super.key});

  @override
  State<ScheduleHabitsScreen> createState() => _ScheduleHabitsScreenState();
}

// Kansei's own palette (goal-executor/lib/theme/colors.dart) — carried over
// unchanged rather than reinterpreted in Green Pyramid's own dark palette,
// since the owner's own ask was to reuse Kansei's actual look.
const Color _sumiBlack = Color(0xFF1a1714);
const Color _aqua = Color(0xFF4FC3C8);
const Color _washiCream = Color(0xFFf4ede0);
const Color _bengaraRed = Color(0xFFa8453a);
const Color _existingGrey = Color(0xFF3A3A3A);
const Color _existingGreyBorder = Color(0xFF555555);

const double _hourH = 60.0; // pixels per hour
const double _timeW = 48.0; // width of the time-label column
const int _startHour = 0;
const int _endHour = 24;
const int _dayCount = 7;
const Duration _habitDuration = Duration(minutes: 15);

double _timeToY(int hour, int minute) =>
    ((hour - _startHour) + minute / 60.0) * _hourH;

/// D-123 Phase 2: converts a raw vertical drop offset (grid-local pixels)
/// into an hour/minute snapped to the nearest 15 minutes and clamped so
/// the habit's whole duration fits within the visible day — pure so the
/// snap math is testable without simulating a live drag gesture.
(int hour, int minute) snapDropToTime(
  double localY, {
  double hourH = _hourH,
  int startHour = _startHour,
  int endHour = _endHour,
  int durationMinutes = 15,
}) {
  final totalMins = ((localY / hourH) * 60).round();
  final snapped = (totalMins ~/ 15) * 15;
  final maxMins = (endHour - startHour) * 60 - durationMinutes;
  final clamped = snapped.clamp(0, maxMins);
  return (startHour + clamped ~/ 60, clamped % 60);
}

/// D-123 Phase 2: half-open interval overlap — the collision test behind
/// both the calendar-write guard and the drop-rejection haptic. Pure.
bool intervalsOverlap(
        DateTime aStart, DateTime aEnd, DateTime bStart, DateTime bEnd) =>
    aStart.isBefore(bEnd) && aEnd.isAfter(bStart);

class _ScheduleHabitsScreenState extends State<ScheduleHabitsScreen> {
  final _calendarService = CalendarService.instance;
  final _dbHelper = DatabaseHelper.instance;
  final _utils = Utils();
  final _scrollCtrl = ScrollController();
  final _dayKeys = List<GlobalKey>.generate(_dayCount, (_) => GlobalKey());
  FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  bool _loading = true;
  bool _permissionDenied = false;
  late DateTime _weekStart;
  List<HabitScheduleRow> _habits = [];
  // One events list per day column, index-aligned with _dayKeys.
  List<List<dc.Event>> _existingEventsByDay =
      List.generate(_dayCount, (_) => []);
  HabitScheduleRow? _dragging;
  Timer? _autoScrollTimer;
  Timer? _nowTimer;

  void _lockLandscape() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void initState() {
    super.initState();
    analytics.logEvent(name: 'schedule_habits');
    _lockLandscape();
    final now = DateTime.now();
    _weekStart = DateTime(now.year, now.month, now.day);
    _nowTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _lockLandscape();
      await _init();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _lockLandscape();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _nowTimer?.cancel();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final alreadyGranted = await _calendarService.hasPermission();
    if (!mounted) return;
    if (alreadyGranted) {
      await _loadAll();
      return;
    }
    final proceed = await _showPermissionPrompt();
    if (!mounted) return;
    if (!proceed) {
      setState(() {
        _loading = false;
        _permissionDenied = true;
      });
      return;
    }
    final granted = await _calendarService.requestPermission();
    if (!mounted) return;
    if (!granted) {
      setState(() {
        _loading = false;
        _permissionDenied = true;
      });
      return;
    }
    await _loadAll();
  }

  Future<bool> _showPermissionPrompt() async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: _sumiBlack,
            title:
                const Text('Calendar access', style: TextStyle(color: _washiCream)),
            content: const Text(
                'Scheduling a habit writes a real event to your device '
                'calendar, so you can see it alongside everything else. '
                'This is optional — you can keep using habits without a '
                'time attached.',
                style: TextStyle(color: _washiCream)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Not now'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Continue', style: TextStyle(color: _aqua)),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final rows = await _dbHelper.queryAllTasks();
    final events = await Future.wait(List.generate(
        _dayCount, (i) => _calendarService.eventsForDay(_weekStart.add(Duration(days: i)))));
    if (!mounted) return;
    setState(() {
      _habits = rows.map((m) => HabitScheduleRow.fromMap(m, _utils)).toList();
      _existingEventsByDay = events;
      _loading = false;
    });
  }

  List<HabitScheduleRow> get _unscheduled =>
      _habits.where((h) => h.scheduledTime == null).toList();

  List<HabitScheduleRow> get _scheduled =>
      _habits.where((h) => h.scheduledTime != null).toList();

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// D-123 Phase 2: a scheduled habit's time is shared across every day
  /// it's active on (rescheduling moves the whole recurring series at
  /// once), so a collision has to be checked on every one of those days,
  /// not just the day column the drag was dropped into.
  bool _hasCollision(int hour, int minute, HabitScheduleRow excluding) {
    for (var i = 0; i < _dayCount; i++) {
      final day = _weekStart.add(Duration(days: i));
      if (!excluding.activeOn(day)) continue;
      final newStart = DateTime(day.year, day.month, day.day, hour, minute);
      final newEnd = newStart.add(_habitDuration);

      for (final e in _existingEventsByDay[i]) {
        if (intervalsOverlap(newStart, newEnd, e.startDate, e.endDate)) {
          return true;
        }
      }
      for (final h in _scheduled) {
        if (h.id == excluding.id) continue;
        if (!h.activeOn(day)) continue;
        final t = h.parsedTime!;
        final start = DateTime(day.year, day.month, day.day, t.$1, t.$2);
        final end = start.add(_habitDuration);
        if (intervalsOverlap(newStart, newEnd, start, end)) return true;
      }
    }
    return false;
  }

  Future<void> _handleDrop(
      HabitScheduleRow habit, int dayIndex, Offset globalOffset) async {
    final day = _weekStart.add(Duration(days: dayIndex));
    if (!habit.activeOn(day)) {
      HapticFeedback.heavyImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                '"${habit.description}" isn\'t active on ${DateFormat('EEEE').format(day)}.')));
      }
      return;
    }

    final box = _dayKeys[dayIndex].currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final localY =
        box.globalToLocal(globalOffset).dy.clamp(0.0, double.infinity);
    final (hour, minute) =
        snapDropToTime(localY, durationMinutes: _habitDuration.inMinutes);

    if (_hasCollision(hour, minute, habit)) {
      HapticFeedback.heavyImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('That time overlaps another event.')));
      }
      return;
    }

    final days = CalendarService.daysOfWeekFrom(
      sunday: habit.sunday,
      monday: habit.monday,
      tuesday: habit.tuesday,
      wednesday: habit.wednesday,
      thursday: habit.thursday,
      friday: habit.friday,
      saturday: habit.saturday,
    );
    final timeStr = _fmtTime(hour, minute);

    bool ok;
    String? eventId = habit.scheduledEventId;
    if (habit.scheduledTime == null) {
      eventId = await _calendarService.createHabitEvent(
        habitDescription: habit.description,
        hour: hour,
        minute: minute,
        daysOfWeek: days,
        duration: _habitDuration,
      );
      ok = eventId != null;
    } else {
      ok = await _calendarService.rescheduleHabitEvent(
        eventId: habit.scheduledEventId!,
        hour: hour,
        minute: minute,
        daysOfWeek: days,
        duration: _habitDuration,
      );
    }

    if (ok) {
      await _dbHelper.update({
        DatabaseHelper.columnId: habit.id,
        DatabaseHelper.columnScheduledTime: timeStr,
        DatabaseHelper.columnScheduledCalendarEventId: eventId,
      });
      HapticFeedback.mediumImpact();
      await _loadAll();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Couldn't write to your calendar. Nothing changed.")));
    }
  }

  Future<void> _confirmUnschedule(HabitScheduleRow habit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _sumiBlack,
        title:
            const Text('Remove this time?', style: TextStyle(color: _washiCream)),
        content: Text(
            '"${habit.description}" will go back to being flexible, with '
            'no time attached, and its calendar event will be deleted.',
            style: const TextStyle(color: _washiCream)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: _bengaraRed)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    if (habit.scheduledEventId != null) {
      await _calendarService.deleteHabitEvent(habit.scheduledEventId!);
    }
    await _dbHelper.update({
      DatabaseHelper.columnId: habit.id,
      DatabaseHelper.columnScheduledTime: null,
      DatabaseHelper.columnScheduledCalendarEventId: null,
    });
    await _loadAll();
  }

  String _fmtTime(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    if (_loading) return _stateView(_loadingBody());
    if (_permissionDenied) return _stateView(_permissionBody());

    final weekLabel =
        '${DateFormat('MMMM d').format(_weekStart)} – ${DateFormat('MMMM d').format(_weekStart.add(const Duration(days: _dayCount - 1)))}';

    return Scaffold(
      backgroundColor: _sumiBlack,
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Text('Schedule Habits — $weekLabel',
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
        actions: [
          _legendChip(_existingGrey, 'Existing'),
          const SizedBox(width: 12),
          _legendChip(_aqua, 'Habit'),
          const SizedBox(width: 16),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _dayHeader(),
              Expanded(child: _calendarGrid()),
              if (_unscheduled.isNotEmpty) _tray(),
            ],
          ),
          if (_dragging != null) _deleteZone(),
        ],
      ),
    );
  }

  Widget _legendChip(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: color.withOpacity(0.8), borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(fontSize: 10, color: _washiCream.withOpacity(0.5))),
      ],
    );
  }

  Widget _stateView(Widget body) => Scaffold(backgroundColor: _sumiBlack, body: body);

  Widget _loadingBody() => const Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: _aqua),
      );

  Widget _permissionBody() => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.calendar_today_outlined, size: 36, color: _aqua.withOpacity(0.6)),
            const SizedBox(height: 20),
            const Text('Calendar access needed.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white)),
            const SizedBox(height: 8),
            Text(
              'Grant access in Settings → Privacy → Calendars to schedule habits.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _washiCream.withOpacity(0.5), height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() => _loading = true);
                _init();
              },
              style: ElevatedButton.styleFrom(backgroundColor: _aqua, foregroundColor: _sumiBlack),
              child: const Text('Try Again'),
            ),
          ]),
        ),
      );

  Widget _dayHeader() {
    return Container(
      color: const Color(0xFF111111),
      child: Row(
        children: [
          const SizedBox(width: _timeW),
          ...List.generate(_dayCount, (i) {
            final day = _weekStart.add(Duration(days: i));
            final isToday = _sameDay(day, DateTime.now());
            return Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                alignment: Alignment.center,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    DateFormat('EEE').format(day).toUpperCase(),
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: isToday ? _aqua : _washiCream.withOpacity(0.35)),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    width: 26,
                    height: 26,
                    decoration:
                        isToday ? const BoxDecoration(color: _aqua, shape: BoxShape.circle) : null,
                    alignment: Alignment.center,
                    child: Text(
                      DateFormat('d').format(day),
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isToday ? _sumiBlack : _washiCream.withOpacity(0.7)),
                    ),
                  ),
                ]),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _calendarGrid() {
    final totalH = (_endHour - _startHour) * _hourH;
    final now = DateTime.now();
    final nowY = _timeToY(now.hour, now.minute).clamp(0.0, totalH);

    return SingleChildScrollView(
      controller: _scrollCtrl,
      child: SizedBox(
        height: totalH,
        child: Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: _timeW,
                  child: Stack(
                    children: List.generate(_endHour - _startHour, (i) {
                      final hour = _startHour + i;
                      return Positioned(
                        top: i * _hourH - 7,
                        left: 0,
                        right: 0,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Text(
                              DateFormat('ha').format(DateTime(0, 1, 1, hour)),
                              style: TextStyle(fontSize: 10, color: _washiCream.withOpacity(0.6)),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                ...List.generate(_dayCount, (i) {
                  final day = _weekStart.add(Duration(days: i));
                  return Expanded(child: _dayColumn(day, totalH, i));
                }),
              ],
            ),
            Positioned(
              top: nowY - 3,
              left: _timeW - 4,
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              ),
            ),
            Positioned(
              top: nowY,
              left: _timeW,
              right: 0,
              child: Container(height: 1, color: Colors.red.withOpacity(0.75)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayColumn(DateTime day, double totalH, int dayIndex) {
    final dayExisting = _existingEventsByDay[dayIndex];
    final dayHabits = _scheduled.where((h) => h.activeOn(day)).toList();

    return DragTarget<HabitScheduleRow>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) =>
          _handleDrop(details.data, dayIndex, details.offset),
      builder: (ctx, candidates, _) {
        final isTarget = candidates.isNotEmpty;
        return Container(
          key: _dayKeys[dayIndex],
          height: totalH,
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: _washiCream.withOpacity(0.07))),
            color: isTarget ? _aqua.withOpacity(0.05) : Colors.transparent,
          ),
          child: Stack(
            children: [
              ...List.generate(
                  _endHour - _startHour,
                  (i) => Positioned(
                        top: i * _hourH,
                        left: 0,
                        right: 0,
                        child: Container(height: 0.5, color: _washiCream.withOpacity(0.06)),
                      )),
              ...dayExisting.map((e) => _positionedExisting(e, day)),
              ...dayHabits.map(_positionedHabit),
              if (isTarget)
                Positioned.fill(
                  child: Container(
                    decoration:
                        BoxDecoration(border: Border.all(color: _aqua.withOpacity(0.3), width: 1.5)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _positionedExisting(dc.Event e, DateTime day) {
    final wakeStart = DateTime(day.year, day.month, day.day, _startHour);
    final wakeEnd = DateTime(day.year, day.month, day.day, _endHour);
    final dispStart = e.startDate.isBefore(wakeStart) ? wakeStart : e.startDate;
    final dispEnd = e.endDate.isAfter(wakeEnd) ? wakeEnd : e.endDate;
    final top = _timeToY(dispStart.hour, dispStart.minute).clamp(0.0, double.infinity);
    final rawH = dispEnd.difference(dispStart).inMinutes / 60 * _hourH;
    final h = rawH.clamp(18.0, double.infinity);
    return Positioned(
      top: top,
      left: 2,
      right: 2,
      height: h,
      child: Container(
        decoration: BoxDecoration(
          color: _existingGrey,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: _existingGreyBorder, width: 0.5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(
          e.title,
          maxLines: rawH < 30 ? 1 : 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: _washiCream.withOpacity(0.65)),
        ),
      ),
    );
  }

  Widget _positionedHabit(HabitScheduleRow h) {
    final t = h.parsedTime!;
    final top = _timeToY(t.$1, t.$2).clamp(0.0, double.infinity);
    final rawH = _habitDuration.inMinutes / 60 * _hourH;
    final height = rawH.clamp(24.0, double.infinity);

    return Positioned(
      top: top,
      left: 2,
      right: 2,
      height: height,
      child: LongPressDraggable<HabitScheduleRow>(
        data: h,
        delay: const Duration(milliseconds: 250),
        onDragStarted: () => setState(() => _dragging = h),
        onDragUpdate: _onDragUpdate,
        onDragEnd: (_) {
          _stopAutoScroll();
          if (mounted) setState(() => _dragging = null);
        },
        onDraggableCanceled: (v, o) {
          _stopAutoScroll();
          if (mounted) setState(() => _dragging = null);
        },
        feedback: Material(
          color: Colors.transparent,
          child: Container(
            width: 80,
            height: height,
            decoration: BoxDecoration(
              color: _aqua.withOpacity(0.8),
              borderRadius: BorderRadius.circular(4),
              boxShadow: [BoxShadow(color: _aqua.withOpacity(0.4), blurRadius: 12)],
            ),
          ),
        ),
        childWhenDragging: Container(
          decoration: BoxDecoration(
            color: _aqua.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: _aqua.withOpacity(0.3)),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: _aqua.withOpacity(0.18),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: _aqua.withOpacity(0.55), width: 0.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                h.description,
                maxLines: rawH < 36 ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _aqua.withOpacity(0.95)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _deleteZone() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: DragTarget<HabitScheduleRow>(
        onWillAcceptWithDetails: (_) => true,
        onAcceptWithDetails: (details) => _confirmUnschedule(details.data),
        builder: (ctx, candidates, _) {
          final hovered = candidates.isNotEmpty;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: hovered ? 72 : 56,
            color: hovered ? _bengaraRed.withOpacity(0.92) : _bengaraRed.withOpacity(0.75),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.delete_outline,
                    color: Colors.white.withOpacity(hovered ? 1.0 : 0.85), size: hovered ? 22 : 18),
                const SizedBox(width: 8),
                Text(
                  hovered ? 'Release to remove' : 'Drop here to unschedule',
                  style: TextStyle(
                      color: Colors.white.withOpacity(hovered ? 1.0 : 0.85),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _tray() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        border: Border(top: BorderSide(color: _washiCream.withOpacity(0.08))),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _unscheduled.length,
        itemBuilder: (context, i) {
          final h = _unscheduled[i];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: LongPressDraggable<HabitScheduleRow>(
              data: h,
              delay: const Duration(milliseconds: 250),
              onDragStarted: () => setState(() => _dragging = h),
              onDragUpdate: _onDragUpdate,
              onDragEnd: (_) {
                _stopAutoScroll();
                if (mounted) setState(() => _dragging = null);
              },
              onDraggableCanceled: (v, o) {
                _stopAutoScroll();
                if (mounted) setState(() => _dragging = null);
              },
              feedback: Material(
                color: Colors.transparent,
                child: Container(
                  width: 160,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                      color: _aqua.withOpacity(0.85), borderRadius: BorderRadius.circular(8)),
                  child: Text(h.description,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _sumiBlack)),
                ),
              ),
              childWhenDragging: Opacity(opacity: 0.3, child: _trayChip(h)),
              child: _trayChip(h),
            ),
          );
        },
      ),
    );
  }

  Widget _trayChip(HabitScheduleRow h) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
            color: _aqua.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _aqua.withOpacity(0.35))),
        alignment: Alignment.center,
        constraints: const BoxConstraints(maxWidth: 160),
        child: Text(h.description,
            maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _washiCream)),
      );

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_scrollCtrl.hasClients) return;
    final screenH = MediaQuery.of(context).size.height;
    final dy = details.globalPosition.dy;
    const edgePx = 100.0;
    const maxSpeed = 6.0;

    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;

    double delta = 0;
    if (dy < edgePx) {
      delta = -maxSpeed * (1.0 - dy / edgePx);
    } else if (dy > screenH - edgePx) {
      delta = maxSpeed * (1.0 - (screenH - dy) / edgePx);
    }

    if (delta != 0) {
      _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
        if (!_scrollCtrl.hasClients) return;
        final next = (_scrollCtrl.offset + delta).clamp(0.0, _scrollCtrl.position.maxScrollExtent);
        _scrollCtrl.jumpTo(next);
      });
    }
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }
}

class HabitScheduleRow {
  final int id;
  final String category;
  final String description;
  final bool sunday, monday, tuesday, wednesday, thursday, friday, saturday;
  final String? scheduledTime;
  final String? scheduledEventId;

  HabitScheduleRow({
    required this.id,
    required this.category,
    required this.description,
    required this.sunday,
    required this.monday,
    required this.tuesday,
    required this.wednesday,
    required this.thursday,
    required this.friday,
    required this.saturday,
    required this.scheduledTime,
    required this.scheduledEventId,
  });

  factory HabitScheduleRow.fromMap(Map<String, dynamic> m, Utils utils) {
    bool flag(dynamic v) => utils.toBoolean(v?.toString() ?? '');
    return HabitScheduleRow(
      id: m[DatabaseHelper.columnId] as int,
      category: m[DatabaseHelper.columnCategory] as String? ?? '',
      description: m[DatabaseHelper.columnTaskDescription] as String? ?? '',
      sunday: flag(m[DatabaseHelper.columnSunday]),
      monday: flag(m[DatabaseHelper.columnMonday]),
      tuesday: flag(m[DatabaseHelper.columnTuesday]),
      wednesday: flag(m[DatabaseHelper.columnWednesday]),
      thursday: flag(m[DatabaseHelper.columnThursday]),
      friday: flag(m[DatabaseHelper.columnFriday]),
      saturday: flag(m[DatabaseHelper.columnSaturday]),
      scheduledTime: m[DatabaseHelper.columnScheduledTime] as String?,
      scheduledEventId: m[DatabaseHelper.columnScheduledCalendarEventId] as String?,
    );
  }

  bool activeOn(DateTime day) {
    switch (day.weekday) {
      case DateTime.sunday:
        return sunday;
      case DateTime.monday:
        return monday;
      case DateTime.tuesday:
        return tuesday;
      case DateTime.wednesday:
        return wednesday;
      case DateTime.thursday:
        return thursday;
      case DateTime.friday:
        return friday;
      case DateTime.saturday:
        return saturday;
    }
    return false;
  }

  (int, int)? get parsedTime {
    final t = scheduledTime;
    if (t == null) return null;
    final parts = t.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return (hour, minute);
  }
}
