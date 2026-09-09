import 'dart:async';

import 'package:device_calendar_plus/device_calendar_plus.dart' as dc;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

import 'package:life_ops/services/calendar_service.dart';
import 'package:life_ops/services/db.dart';
import 'package:life_ops/services/utils.dart';
import 'package:life_ops/theme/app_colors.dart';
import 'package:life_ops/widgets/navbar.dart';

/// D-123 Phase 2: drag a habit onto a time to give it a recurring
/// scheduled time, backed by a real native-calendar event — the
/// scheduling UI promised by D-123, ported from Kansei's
/// `calendar_proposal_screen.dart` mechanics (long-press to pick up,
/// 15-minute snap, collision detection, edge auto-scroll, a drop zone to
/// remove) but adapted for Green Pyramid's model: a habit's days are
/// already fixed by its own Sunday–Saturday flags (set elsewhere, in
/// EditTaskDetail), so this screen only ever changes a habit's *time* —
/// there is no cross-day dragging the way Kansei's week-wide session
/// grid has, so a single scrollable day column replaces its 7-day Row.
/// Every write goes straight to [CalendarService] and the database, the
/// same immediate-write pattern the rest of Green Pyramid's editing
/// screens already use — there is no separate "confirm" step to submit.
class ScheduleHabitsScreen extends StatefulWidget {
  const ScheduleHabitsScreen({super.key});

  @override
  State<ScheduleHabitsScreen> createState() => _ScheduleHabitsScreenState();
}

const double _hourH = 60.0; // pixels per hour
const double _timeW = 48.0; // width of the time-label column
const int _startHour = 0;
const int _endHour = 24;
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
  final _gridKey = GlobalKey();
  final _dowFmt = DateFormat('EEE');
  final _dayFmt = DateFormat('d');
  final _hourFmt = DateFormat('ha');
  FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  bool _loading = true;
  bool _permissionDenied = false;
  late DateTime _selectedDay;
  List<HabitScheduleRow> _habits = [];
  List<dc.Event> _existingEvents = [];
  HabitScheduleRow? _dragging;
  Timer? _autoScrollTimer;
  Timer? _nowTimer;

  @override
  void initState() {
    super.initState();
    analytics.logEvent(name: 'schedule_habits');
    final now = DateTime.now();
    _selectedDay = DateTime(now.year, now.month, now.day);
    _nowTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _nowTimer?.cancel();
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
            title: const Text('Calendar access'),
            content: const Text(
                'Scheduling a habit writes a real event to your device '
                'calendar, so you can see it alongside everything else. '
                'This is optional — you can keep using habits without a '
                'time attached.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Not now'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Continue'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final rows = await _dbHelper.queryAllTasks();
    final events = await _calendarService.eventsForDay(_selectedDay);
    if (!mounted) return;
    setState(() {
      _habits = rows.map((m) => HabitScheduleRow.fromMap(m, _utils)).toList();
      _existingEvents = events;
      _loading = false;
    });
  }

  Future<void> _selectDay(DateTime day) async {
    setState(() => _selectedDay = day);
    final events = await _calendarService.eventsForDay(day);
    if (mounted) setState(() => _existingEvents = events);
  }

  List<HabitScheduleRow> get _habitsActiveToday =>
      _habits.where((h) => h.activeOn(_selectedDay)).toList();

  List<HabitScheduleRow> get _scheduledToday =>
      _habitsActiveToday.where((h) => h.scheduledTime != null).toList();

  List<HabitScheduleRow> get _unscheduledToday =>
      _habitsActiveToday.where((h) => h.scheduledTime == null).toList();

  bool _hasCollision(DateTime newStart, DateTime newEnd, HabitScheduleRow excluding) {
    for (final e in _existingEvents) {
      if (intervalsOverlap(newStart, newEnd, e.startDate, e.endDate)) {
        return true;
      }
    }
    for (final h in _scheduledToday) {
      if (h.id == excluding.id) continue;
      final t = h.parsedTime!;
      final start = DateTime(_selectedDay.year, _selectedDay.month,
          _selectedDay.day, t.$1, t.$2);
      final end = start.add(_habitDuration);
      if (intervalsOverlap(newStart, newEnd, start, end)) return true;
    }
    return false;
  }

  Future<void> _handleDrop(HabitScheduleRow habit, Offset globalOffset) async {
    final box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final localY =
        box.globalToLocal(globalOffset).dy.clamp(0.0, double.infinity);
    final (hour, minute) = snapDropToTime(localY,
        durationMinutes: _habitDuration.inMinutes);

    final newStart = DateTime(
        _selectedDay.year, _selectedDay.month, _selectedDay.day, hour, minute);
    final newEnd = newStart.add(_habitDuration);

    if (_hasCollision(newStart, newEnd, habit)) {
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
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text("Couldn't write to your calendar. Nothing changed.")));
      }
    }
  }

  Future<void> _confirmUnschedule(HabitScheduleRow habit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove this time?'),
        content: Text(
            '"${habit.description}" will go back to being flexible, with '
            'no time attached, and its calendar event will be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
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
    return SafeArea(
      child: Scaffold(
        appBar: const NavBar(),
        backgroundColor: AppColors.background,
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _permissionDenied
                ? _permissionBody()
                : Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text('Schedule Habits',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Exo2',
                                color: AppColors.textPrimary)),
                      ),
                      _daySelector(),
                      const Divider(height: 1, color: AppColors.surfaceHigh),
                      Expanded(
                        child: Stack(
                          children: [
                            _calendarGrid(),
                            if (_dragging != null) _deleteZone(),
                          ],
                        ),
                      ),
                      if (_unscheduledToday.isNotEmpty) _tray(),
                    ],
                  ),
      ),
    );
  }

  Widget _permissionBody() => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.calendar_today_outlined,
                size: 36, color: AppColors.textSecondary),
            const SizedBox(height: 20),
            const Text('Calendar access needed to schedule habits.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            const Text(
              'Grant access in Settings to give a habit a time on your '
              'calendar, or try again below.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() => _loading = true);
                _init();
              },
              child: const Text('Try Again'),
            ),
          ]),
        ),
      );

  Widget _daySelector() {
    final today = DateTime.now();
    return SizedBox(
      height: 64,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: 7,
        itemBuilder: (context, i) {
          final day = DateTime(today.year, today.month, today.day)
              .add(Duration(days: i));
          final isSelected = _sameDay(day, _selectedDay);
          final isToday = _sameDay(day, today);
          return GestureDetector(
            onTap: () => _selectDay(day),
            child: Container(
              width: 44,
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.brandGreen : AppColors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_dowFmt.format(day).toUpperCase(),
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? AppColors.background
                              : isToday
                                  ? AppColors.brandGreen
                                  : AppColors.textSecondary)),
                  Text(_dayFmt.format(day),
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? AppColors.background
                              : AppColors.textPrimary)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _calendarGrid() {
    final totalH = (_endHour - _startHour) * _hourH;
    final now = DateTime.now();
    final showNow = _sameDay(_selectedDay, now);
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
                              _hourFmt.format(DateTime(0, 1, 1, hour)),
                              style: const TextStyle(
                                  fontSize: 10, color: AppColors.textSecondary),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                Expanded(child: _dayColumn(totalH)),
              ],
            ),
            if (showNow) ...[
              Positioned(
                top: nowY - 3,
                left: _timeW - 4,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                      color: Colors.redAccent, shape: BoxShape.circle),
                ),
              ),
              Positioned(
                top: nowY,
                left: _timeW,
                right: 0,
                child: Container(height: 1, color: Colors.redAccent),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _dayColumn(double totalH) {
    return DragTarget<HabitScheduleRow>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) => _handleDrop(details.data, details.offset),
      builder: (ctx, candidates, _) {
        final isTarget = candidates.isNotEmpty;
        return Container(
          key: _gridKey,
          height: totalH,
          decoration: BoxDecoration(
            border: const Border(
                left: BorderSide(color: AppColors.surfaceHigh)),
            color: isTarget
                ? AppColors.brandGreen.withOpacity(0.06)
                : Colors.transparent,
          ),
          child: Stack(
            children: [
              ...List.generate(
                  _endHour - _startHour,
                  (i) => Positioned(
                        top: i * _hourH,
                        left: 0,
                        right: 0,
                        child: Container(
                            height: 0.5, color: AppColors.surfaceHigh),
                      )),
              ..._existingEvents.map(_positionedExisting),
              ..._scheduledToday.map(_positionedHabit),
              if (isTarget)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: AppColors.brandGreen.withOpacity(0.4),
                          width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _positionedExisting(dc.Event e) {
    final start = _sameDay(e.startDate, _selectedDay)
        ? e.startDate
        : DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day,
            _startHour);
    final end = _sameDay(e.endDate, _selectedDay)
        ? e.endDate
        : DateTime(
            _selectedDay.year, _selectedDay.month, _selectedDay.day, _endHour);
    final top = _timeToY(start.hour, start.minute).clamp(0.0, double.infinity);
    final rawH = end.difference(start).inMinutes / 60 * _hourH;
    final h = rawH.clamp(18.0, double.infinity);
    return Positioned(
      top: top,
      left: 2,
      right: 2,
      height: h,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(
          e.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
      ),
    );
  }

  Widget _positionedHabit(HabitScheduleRow h) {
    final t = h.parsedTime!;
    final top = _timeToY(t.$1, t.$2).clamp(0.0, double.infinity);
    final rawH = _habitDuration.inMinutes / 60 * _hourH;
    final height = rawH.clamp(22.0, double.infinity);

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
            width: 160,
            height: height,
            decoration: BoxDecoration(
              color: AppColors.brandGreen.withOpacity(0.85),
              borderRadius: BorderRadius.circular(4),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            alignment: Alignment.centerLeft,
            child: Text(h.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Colors.black)),
          ),
        ),
        childWhenDragging: Container(
          decoration: BoxDecoration(
            color: AppColors.brandGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.brandGreen.withOpacity(0.3)),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.brandGreen.withOpacity(0.25),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.brandGreen.withOpacity(0.6)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Text(
            h.description,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary),
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
            color: (hovered ? Colors.redAccent : Colors.redAccent.shade200)
                .withOpacity(0.9),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.delete_outline, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  hovered ? 'Release to remove' : 'Drop here to unschedule',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
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
      height: 64,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.surfaceHigh)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        itemCount: _unscheduledToday.length,
        itemBuilder: (context, i) {
          final h = _unscheduledToday[i];
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.brandGreen.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(h.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.black)),
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.3,
                child: _trayChip(h),
              ),
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
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        constraints: const BoxConstraints(maxWidth: 160),
        child: Text(h.description,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textPrimary)),
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
        final next = (_scrollCtrl.offset + delta)
            .clamp(0.0, _scrollCtrl.position.maxScrollExtent);
        _scrollCtrl.jumpTo(next);
      });
    }
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
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
      scheduledEventId:
          m[DatabaseHelper.columnScheduledCalendarEventId] as String?,
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
