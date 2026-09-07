import 'package:flutter/material.dart';

import '../models/board_session.dart';
import '../services/ai_guard.dart';
import '../services/council_client.dart';
import '../services/council_service.dart';
import '../theme/app_colors.dart';
import '../widgets/chat_backdrop.dart';
import '../widgets/council_transcript.dart';

/// D-091: a free-form conversation with the whole Council, not scoped to
/// any one category — reachable any time from the home screen, mirroring
/// Kansei's own "talk to the Council" entry point rather than confining
/// Council access to setup and per-category re-clarification.
///
/// This is where the four-advisor, one-turn-per-message round-robin that
/// used to run during setup now lives — moved here, not deleted, when
/// D-090 made setup a solo conversation with Mira alone.
class GeneralCouncilScreen extends StatefulWidget {
  const GeneralCouncilScreen({super.key});

  @override
  State<GeneralCouncilScreen> createState() => _GeneralCouncilScreenState();
}

class _GeneralCouncilScreenState extends State<GeneralCouncilScreen> {
  final _council = CouncilService.instance;
  final _textController = TextEditingController();
  BoardSession? _session;
  bool _busy = false;
  String? _error;

  static const _categoryName = 'their life';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      var session = await _council.getActiveSession(type: BoardSessionType.general);
      session ??= await _council.createSession(type: BoardSessionType.general);
      setState(() => _session = session);

      if (session.resumeAction == BoardResumeAction.retryOpeningRound) {
        await _runAdvisorTurn(session.rotationOrder.first);
      }
    } catch (e) {
      setState(() => _error = 'Could not open this conversation. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runAdvisorTurn(String advisorKey) async {
    final session = _session;
    if (session == null) return;
    try {
      await _council.runAdvisorTurn(
        session: session,
        advisorKey: advisorKey,
        categoryName: _categoryName,
      );
      final refreshed =
          await _council.getActiveSession(type: BoardSessionType.general);
      if (mounted) setState(() => _session = refreshed ?? session);
    } on AiBudgetException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on SpendLimitException catch (e) {
      if (mounted) {
        setState(() => _error =
            'You\'ve reached this month\'s spend limit (\$${e.totalSpendUsd.toStringAsFixed(2)}'
                ' of \$${e.spendCapUsd.toStringAsFixed(2)}). More can be purchased soon.');
      }
    } on CouncilClientException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _sendUserMessage() async {
    final text = _textController.text.trim();
    final session = _session;
    if (text.isEmpty || session == null || _busy) return;
    _textController.clear();
    setState(() => _busy = true);
    try {
      await _council.appendUserMessage(session.sessionId, text);
      await _runAdvisorTurn(session.nextAdvisorKey);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('The Council'),
      ),
      body: ChatBackdrop(
        child: Column(
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!,
                    style: const TextStyle(color: Colors.redAccent)),
              ),
            Expanded(
              child: session == null
                  ? const Center(child: CircularProgressIndicator())
                  : CouncilTranscript(messages: session.messages),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        enabled: !_busy,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration:
                            const InputDecoration(hintText: 'Say something…'),
                        onSubmitted: (_) => _sendUserMessage(),
                      ),
                    ),
                    IconButton(
                      onPressed: _busy ? null : _sendUserMessage,
                      icon: const Icon(Icons.arrow_upward,
                          color: AppColors.brandGreen),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
