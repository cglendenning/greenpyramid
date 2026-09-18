import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

import 'package:life_ops/services/db.dart';
import 'package:life_ops/services/speech_service.dart';
import 'package:life_ops/theme/app_colors.dart';
import 'package:life_ops/widgets/microphone_recorder.dart';
import 'package:life_ops/widgets/navbar.dart';

enum _RowStatus { pending, recording, done }

class _HabitCheckin {
  final String id;
  final String category;
  final String description;
  final String? scheduledtime;
  _RowStatus status = _RowStatus.pending;
  bool? answeredYes;
  String transcript = '';
  final SpeechService speechService = SpeechService();

  _HabitCheckin({
    required this.id,
    required this.category,
    required this.description,
    required this.scheduledtime,
  });

  factory _HabitCheckin.fromMap(Map<String, dynamic> m) => _HabitCheckin(
        id: m['id']?.toString() ?? '',
        category: m['category']?.toString() ?? '',
        description: m['description']?.toString() ?? '',
        scheduledtime: m['scheduledtime']?.toString(),
      );
}

/// D-099 Phase 5: one Yes/No row per scheduled habit named in a batch
/// check-in push (D-099's replacement for Kansei's per-session "Did you
/// do it?"). Yes writes a `task_log` completion immediately — the
/// notification's answer *is* the completion action, per the owner's
/// explicit choice, not just a reminder to go check something off
/// manually elsewhere. No opens a voice-recorded reason capture, ported
/// from Kansei's own check-in screen
/// (`goal-executor/lib/screens/session_checkin_screen.dart`) via
/// [MicrophoneRecorder]/[SpeechService]. Every write goes straight to the
/// database — there is no separate "confirm" step, matching how the rest
/// of Green Pyramid's editing screens already work.
class BatchCheckinScreen extends StatefulWidget {
  final List<Map<String, dynamic>> habits;
  final DateTime? occurrenceDate;

  const BatchCheckinScreen(
      {required this.habits, this.occurrenceDate, super.key});

  @override
  State<BatchCheckinScreen> createState() => _BatchCheckinScreenState();
}

class _BatchCheckinScreenState extends State<BatchCheckinScreen> {
  final _dbHelper = DatabaseHelper.instance;
  final _dateFmt = DateFormat('yyyy-MM-dd');
  FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  late List<_HabitCheckin> _rows;
  bool _loadingExistingResults = true;
  bool _openedWithExistingCheckin = false;

  @override
  void initState() {
    super.initState();
    analytics.logEvent(name: 'batch_checkin');
    _rows = widget.habits.map(_HabitCheckin.fromMap).toList();
    _loadExistingResults();
  }

  Future<void> _loadExistingResults() async {
    final occurrenceDate = _occurrenceDate;
    final results = await Future.wait(_rows.map((row) {
      return _dbHelper.queryBatchCheckinResult(
        category: row.category,
        taskDescription: row.description,
        taskDate: occurrenceDate,
      );
    }));
    if (!mounted) return;
    var foundExistingResult = false;
    for (var i = 0; i < results.length; i++) {
      final result = results[i];
      if (result == null) continue;
      foundExistingResult = true;
      final checked = result[DatabaseHelper.columnTLChecked]?.toString();
      _rows[i]
        ..status = _RowStatus.done
        ..answeredYes = checked == 'true'
        ..transcript =
            result[DatabaseHelper.columnTLMissReason]?.toString() ?? '';
    }
    setState(() {
      _loadingExistingResults = false;
      _openedWithExistingCheckin = foundExistingResult;
    });
  }

  @override
  void dispose() {
    for (final row in _rows) {
      if (row.status == _RowStatus.recording) row.speechService.cancel();
    }
    super.dispose();
  }

  bool get _allDone => _rows.every((r) => r.status == _RowStatus.done);

  // The push may be opened after midnight. Both answers must still write the
  // occurrence the notification was about, not the calendar day of the tap.
  String get _occurrenceDate =>
      _dateFmt.format(widget.occurrenceDate ?? DateTime.now());

  Future<void> _markYes(_HabitCheckin row) async {
    HapticFeedback.mediumImpact();
    await _dbHelper.recordBatchCheckinResult(
      category: row.category,
      taskDescription: row.description,
      taskDate: _occurrenceDate,
      checked: true,
    );
    if (!mounted) return;
    setState(() {
      row.status = _RowStatus.done;
      row.answeredYes = true;
    });
  }

  void _markNo(_HabitCheckin row) {
    HapticFeedback.lightImpact();
    setState(() => row.status = _RowStatus.recording);
  }

  Future<void> _submitMiss(_HabitCheckin row) async {
    final reason = row.transcript.trim();
    await _dbHelper.recordBatchCheckinResult(
      category: row.category,
      taskDescription: row.description,
      taskDate: _occurrenceDate,
      checked: false,
      missReason: reason.isEmpty ? null : reason,
    );
    if (!mounted) return;
    setState(() {
      row.status = _RowStatus.done;
      row.answeredYes = false;
      row.transcript = reason;
    });
  }

  void _changeCheckin(_HabitCheckin row) {
    HapticFeedback.selectionClick();
    setState(() {
      row.status = _RowStatus.pending;
      row.answeredYes = null;
      row.transcript = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: const NavBar(),
        backgroundColor: AppColors.background,
        body: _loadingExistingResults
            ? const Center(child: CircularProgressIndicator())
            : _rows.isEmpty
                ? const Center(
                    child: Text('Nothing to check in on.',
                        style: TextStyle(color: AppColors.textSecondary)))
                : Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(24, 16, 24, 4),
                        child: Text('Did you do it?',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Exo2',
                                color: AppColors.textPrimary)),
                      ),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
                        child: Text("Today's scheduled habits — one at a time.",
                            style: TextStyle(color: AppColors.textSecondary)),
                      ),
                      if (_openedWithExistingCheckin) _existingCheckinNotice(),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          itemCount: _rows.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, i) => _row(_rows[i]),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _allDone
                                ? () => Navigator.of(context)
                                    .popUntil((route) => route.isFirst)
                                : null,
                            child: const Text('Done'),
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _row(_HabitCheckin row) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: switch (row.status) {
        _RowStatus.pending => _pendingRow(row),
        _RowStatus.recording => _recordingRow(row),
        _RowStatus.done => _doneRow(row),
      },
    );
  }

  Widget _pendingRow(_HabitCheckin row) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(row.description,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        Text(row.category,
            style:
                const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _markNo(row),
                child: const Text('No'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Semantics(
                button: true,
                label: 'Yes',
                child: Material(
                  color: AppColors.brandGreen,
                  borderRadius: BorderRadius.circular(28),
                  child: InkWell(
                    onTap: () => _markYes(row),
                    borderRadius: BorderRadius.circular(28),
                    child: const SizedBox(
                      height: 48,
                      child: Center(
                        child: Text(
                          'YES',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _recordingRow(_HabitCheckin row) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(row.description,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        const Text('What happened?',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 12),
        MicrophoneRecorder(
          speechService: row.speechService,
          onTranscriptChanged: (t) => setState(() => row.transcript = t),
        ),
        if (row.transcript.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(row.transcript,
                style: const TextStyle(color: AppColors.textPrimary)),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () {
                  row.transcript = '';
                  _submitMiss(row);
                },
                child: const Text('Skip — no explanation'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed:
                    row.transcript.isEmpty ? null : () => _submitMiss(row),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _doneRow(_HabitCheckin row) {
    final yes = row.answeredYes == true;
    final reason = row.transcript.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(yes ? Icons.check_circle : Icons.cancel_outlined,
                color: yes ? AppColors.brandGreen : AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(row.description,
                  style: const TextStyle(color: AppColors.textPrimary)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          yes
              ? 'You answered YES.'
              : reason.isEmpty
                  ? 'Recorded as missed. No explanation was provided.'
                  : 'Note received. We’ll use it with your check-in history to shape future guidance.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        if (reason.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('Your note: “$reason”',
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontStyle: FontStyle.italic)),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => _changeCheckin(row),
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            child: const Text('Change check-in'),
          ),
        ),
      ],
    );
  }

  Widget _existingCheckinNotice() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.brandGreen.withValues(alpha: 0.45)),
      ),
      child: const Text(
        'Check-in already recorded. Your answers and any note are shown below. You can change an answer if you need to.',
        style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
      ),
    );
  }
}
