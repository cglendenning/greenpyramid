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

/// D-124 Phase 5: one Yes/No row per scheduled habit named in a batch
/// check-in push (D-124's replacement for Kansei's per-session "Did you
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

  const BatchCheckinScreen({required this.habits, super.key});

  @override
  State<BatchCheckinScreen> createState() => _BatchCheckinScreenState();
}

class _BatchCheckinScreenState extends State<BatchCheckinScreen> {
  final _dbHelper = DatabaseHelper.instance;
  final _dateFmt = DateFormat('yyyy-MM-dd');
  FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  late List<_HabitCheckin> _rows;

  @override
  void initState() {
    super.initState();
    analytics.logEvent(name: 'batch_checkin');
    _rows = widget.habits.map(_HabitCheckin.fromMap).toList();
  }

  @override
  void dispose() {
    for (final row in _rows) {
      if (row.status == _RowStatus.recording) row.speechService.cancel();
    }
    super.dispose();
  }

  bool get _allDone => _rows.every((r) => r.status == _RowStatus.done);

  Future<void> _markYes(_HabitCheckin row) async {
    HapticFeedback.mediumImpact();
    await _dbHelper.recordBatchCheckinResult(
      category: row.category,
      taskDescription: row.description,
      taskDate: _dateFmt.format(DateTime.now()),
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
    await _dbHelper.recordBatchCheckinResult(
      category: row.category,
      taskDescription: row.description,
      taskDate: _dateFmt.format(DateTime.now()),
      checked: false,
      missReason: row.transcript.isEmpty ? null : row.transcript,
    );
    if (!mounted) return;
    setState(() {
      row.status = _RowStatus.done;
      row.answeredYes = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: const NavBar(),
        backgroundColor: AppColors.background,
        body: _rows.isEmpty
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
                    child: Text(
                        "Today's scheduled habits — one at a time.",
                        style: TextStyle(color: AppColors.textSecondary)),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: _rows.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) => _row(_rows[i]),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _allDone
                            ? () => Navigator.of(context).popUntil(
                                (route) => route.isFirst)
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
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary)),
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
              child: ElevatedButton(
                onPressed: () => _markYes(row),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandGreen),
                child: const Text('Yes'),
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
                onPressed: row.transcript.isEmpty
                    ? null
                    : () => _submitMiss(row),
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
    return Row(
      children: [
        Icon(yes ? Icons.check_circle : Icons.cancel_outlined,
            color: yes ? AppColors.brandGreen : AppColors.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(row.description,
              style: const TextStyle(color: AppColors.textPrimary)),
        ),
      ],
    );
  }
}
