import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';

import '../models/board_session.dart';
import '../services/ai_guard.dart';
import '../services/auth_service.dart';
import '../services/council_client.dart';
import '../services/council_service.dart';
import '../services/db.dart';
import '../theme/app_colors.dart';
import '../widgets/chat_backdrop.dart';
import '../widgets/chat_input_bar.dart';
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

  // D-095: real grounding for the advisors' advice — replaces the
  // "their life" placeholder that produced disconnected, sometimes
  // non-sequitur replies (found live: Kenji replied to a message about
  // Crossfit consistency with a generic "what's on your mind?").
  static const _categoryName = 'their life';
  List<Map<String, dynamic>>? _pyramidContext;

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
      // D-032/found live: the same startup race SetupScreen was already
      // fixed for — main.dart's account bootstrap is fire-and-forget so
      // it never gates the first frame, so a screen that touches
      // Firestore before sign-in resolves can lose that race on a fresh
      // launch (a fresh install/reinstall, or D-098's wipe, both leave no
      // cached session). GeneralCouncilScreen was added after that fix
      // and never got it. signInSilently() is a no-op once already
      // signed in, so awaiting it here is always cheap.
      await AuthService.instance.signInSilently();
      _pyramidContext = await DatabaseHelper.instance.queryPyramidSummary();
      var session = await _council.getActiveSession(type: BoardSessionType.general);
      session ??= await _council.createSession(type: BoardSessionType.general);
      setState(() => _session = session);

      if (session.resumeAction == BoardResumeAction.retryOpeningRound) {
        await _runAdvisorTurn(session.rotationOrder.first);
      }
    } catch (e, st) {
      // Found live: this was a silent catch — no log at all, so a real
      // failure here was undiagnosable without guessing.
      debugPrint('GeneralCouncilScreen: failed to open conversation: $e\n$st');
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
        pyramidContext: _pyramidContext,
      );
      final refreshed =
          await _council.getActiveSession(type: BoardSessionType.general);
      if (mounted) setState(() => _session = refreshed ?? session);

      // D-100: once per completed round (all four advisors have spoken),
      // not every message — same checkpoint discipline D-048 already uses
      // elsewhere (once per essence acceptance), applied to the moment
      // that actually exists in a conversation with no such acceptance
      // event of its own. Advisory, never required (D-074); never blocks
      // the chat.
      final pyramid = _pyramidContext;
      if (pyramid != null && (refreshed ?? session).isRoundComplete) {
        unawaited(_council.recordDomainFindings(
          session: refreshed ?? session,
          isSetup: false,
          pyramidContext: pyramid,
        ));
      }
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
                  : CouncilTranscript(
                      messages: session.messages,
                      // D-101: the real next speaker (session.nextAdvisorKey
                      // is meaningful here, unlike setup's solo-Mira turns —
                      // this is a genuine four-advisor rotation) while
                      // genuinely awaiting their reply.
                      typingAdvisorKey:
                          _busy ? session.nextAdvisorKey : null,
                    ),
            ),
            ChatInputBar(
              controller: _textController,
              enabled: !_busy,
              hintText: 'Say something…',
              onSubmit: _sendUserMessage,
            ),
          ],
        ),
      ),
    );
  }
}
