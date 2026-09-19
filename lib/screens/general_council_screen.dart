import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';

import '../models/board_session.dart';
import '../services/ai_guard.dart';
import '../services/auth_service.dart';
import '../services/council_client.dart';
import '../services/council_service.dart';
import '../services/db.dart';
import '../services/entitlement_gate.dart';
import '../theme/app_colors.dart';
import '../widgets/chat_backdrop.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/council_transcript.dart';

/// D-075: a free-form conversation with the whole Council, not scoped to
/// any one category — reachable any time from the home screen, mirroring
/// Kansei's own "talk to the Council" entry point rather than confining
/// Council access to setup and per-category re-clarification.
///
/// This is where the four-advisor, one-turn-per-message round-robin that
/// used to run during setup now lives — moved here, not deleted, when
/// D-074 made setup a solo conversation with Mira alone.
class GeneralCouncilScreen extends StatefulWidget {
  const GeneralCouncilScreen({
    super.key,
    this.notificationMessageKey,
    this.notificationTitle,
    this.notificationBody,
  });

  /// The stable key from a notification payload. When Council is opened
  /// from a push, the rendered copy is loaded from the account inbox rather
  /// than copied into the push payload.
  final String? notificationMessageKey;
  final String? notificationTitle;
  final String? notificationBody;

  @override
  State<GeneralCouncilScreen> createState() => _GeneralCouncilScreenState();
}

class _GeneralCouncilScreenState extends State<GeneralCouncilScreen> {
  final _council = CouncilService.instance;
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  BoardSession? _session;
  bool _busy = false;
  String? _error;
  String? _typingAdvisorKey;
  Map<String, dynamic>? _notificationItem;

  // D-079: real grounding for the advisors' advice — replaces the
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
    _scrollController.dispose();
    super.dispose();
  }

  // D-120: found live — "the screen does not scroll automatically down to
  // the bottom to show the latest response so the response is sitting
  // there below the visible screen." Scheduled a frame after every state
  // change that can add a message or the typing indicator, since the new
  // content's height (and therefore the scroll extent to reach it) isn't
  // known until that frame has laid out.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      // D-029/found live: the same startup race SetupScreen was already
      // fixed for — main.dart's account bootstrap is fire-and-forget so
      // it never gates the first frame, so a screen that touches
      // Firestore before sign-in resolves can lose that race on a fresh
      // launch (a fresh install/reinstall, or D-148's wipe, both leave no
      // cached session). GeneralCouncilScreen was added after that fix
      // and never got it. signInSilently() is a no-op once already
      // signed in, so awaiting it here is always cheap.
      await AuthService.instance.signInSilently();
      if (!mounted) return;
      if (!await ensureEntitled(
          context, reason: 'Talk to the Council of Advisors')) {
        if (mounted) {
          setState(() => _error =
              'The Council of Advisors is available with an active subscription.');
        }
        return;
      }
      await _loadNotificationContext();
      _pyramidContext = await DatabaseHelper.instance.queryPyramidSummary();
      var session =
          await _council.getActiveSession(type: BoardSessionType.general);
      session ??= await _council.createSession(type: BoardSessionType.general);
      setState(() => _session = session);
      _scrollToBottom();

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

  Future<void> _loadNotificationContext() async {
    final key = widget.notificationMessageKey;
    if (key == null || key.isEmpty) return;

    final title = widget.notificationTitle;
    final body = widget.notificationBody;
    if (title != null || body != null) {
      _notificationItem = {'title': title, 'body': body};
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('inbox')
          .where('messageKey', isEqualTo: key)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        _notificationItem = snapshot.docs.first.data();
      }
    } catch (e, st) {
      // Notification context is explanatory, not a prerequisite for Council.
      // A missing inbox record or transient read failure must not make the
      // destination itself fail to open.
      debugPrint('GeneralCouncilScreen: notification context unavailable: $e\n$st');
    }
  }

  Widget _buildNotificationContext() {
    final item = _notificationItem;
    if (item == null) return const SizedBox.shrink();
    final title = item['title'] as String?;
    final body = item['body'] as String?;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Card(
        color: AppColors.surface,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Opened from your notification',
                  style: Theme.of(context).textTheme.labelMedium),
              if (title != null && title.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
              if (body != null && body.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(body),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _runAdvisorTurn(
    String advisorKey, {
    List<Map<String, String>>? conversationHistoryOverride,
  }) async {
    final session = _session;
    if (session == null) return;
    try {
      await _council.runAdvisorTurn(
        session: session,
        advisorKey: advisorKey,
        categoryName: _categoryName,
        pyramidContext: _pyramidContext,
        conversationHistoryOverride: conversationHistoryOverride,
      );
      final refreshed =
          await _council.getActiveSession(type: BoardSessionType.general);
      if (mounted) {
        setState(() => _session = refreshed ?? session);
        _scrollToBottom();
      }
    } on AiBudgetException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on SpendLimitException catch (e) {
      if (mounted) {
        setState(() => _error =
            'You\'ve reached this month\'s spend limit (\$${e.totalSpendUsd.toStringAsFixed(2)}'
                ' of \$${e.spendCapUsd.toStringAsFixed(2)}). Your AI access resets at the start of next month; tracking remains available now.');
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
    final replyAdvisorKey = session.advisorKeyForUserMessage(text);
    setState(() {
      _busy = true;
      _typingAdvisorKey = replyAdvisorKey;
    });
    try {
      final userMessage =
          await _council.appendUserMessage(session.sessionId, text);
      final conversationHistory = [
        ...session.messages
            .map((m) => {'advisor': m.advisorKey, 'text': m.text}),
        {'advisor': 'user', 'text': userMessage.text},
      ];
      await _runAdvisorTurn(
        replyAdvisorKey,
        conversationHistoryOverride: conversationHistory,
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _typingAdvisorKey = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('The Council of Advisors'),
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
            _buildNotificationContext(),
            Expanded(
              child: session == null
                  ? const Center(child: CircularProgressIndicator())
                  : CouncilTranscript(
                      messages: session.messages,
                      scrollController: _scrollController,
                      // D-083: the real next speaker (session.nextAdvisorKey
                      // is meaningful here, unlike setup's solo-Mira turns —
                      // this is a genuine four-advisor rotation) while
                      // genuinely awaiting their reply.
                      typingAdvisorKey: _busy
                          ? (_typingAdvisorKey ?? session.nextAdvisorKey)
                          : null,
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
