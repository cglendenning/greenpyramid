import 'dart:async';

import 'package:flutter/material.dart';

import '../models/board_session.dart';
import '../widgets/chat_backdrop.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/council_transcript.dart';
import '../services/ai_guard.dart';
import '../services/auth_service.dart';
import '../services/council_client.dart';
import '../services/council_service.dart';
import '../services/db.dart';
import '../services/resonance_service.dart';
import '../services/sync_service.dart';
import '../theme/app_colors.dart';

/// D-145: a Council session scoped to one category. R5 ships the mechanism
/// — rotation, resume, an essence accepted once it meets P-12's quality bar
/// (scored by ResonanceService, D-148) — not the richer Council-driven
/// convergence D-038/D-042 define for setup; that lands in R6, built on
/// this same [CouncilService].
///
/// A user message can be accepted as the category's new essence version at
/// any point — there is no separate "closing synthesis" turn in this
/// release.
class CouncilScreen extends StatefulWidget {
  final int categoryId;
  final String categoryName;
  final int categoryTier;

  const CouncilScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
    required this.categoryTier,
  });

  @override
  State<CouncilScreen> createState() => _CouncilScreenState();
}

class _CouncilScreenState extends State<CouncilScreen> {
  final _council = CouncilService.instance;
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  BoardSession? _session;
  String? _priorEssence;
  String? _typingAdvisorKey;
  bool _busy = false;
  String? _error;

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
      _priorEssence = await DatabaseHelper.instance
          .getLatestEssenceForCategory(widget.categoryId);

      var session = await _council.getActiveSession(
          type: BoardSessionType.category, categoryId: widget.categoryId);
      session ??= await _council.createSession(
          type: BoardSessionType.category, categoryId: widget.categoryId);

      setState(() => _session = session);
      _scrollToBottom();

      if (session.resumeAction == BoardResumeAction.retryOpeningRound) {
        await _runAdvisorTurn(session.rotationOrder.first);
      }
    } catch (e) {
      setState(() => _error = 'Could not open this conversation. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runAdvisorTurn(String advisorKey,
      {List<Map<String, String>>? conversationHistoryOverride}) async {
    final session = _session;
    if (session == null) return;
    if (mounted) setState(() => _typingAdvisorKey = advisorKey);
    try {
      await _council.runAdvisorTurn(
        session: session,
        advisorKey: advisorKey,
        categoryName: widget.categoryName,
        categoryTier: widget.categoryTier,
        priorEssence: _priorEssence,
        conversationHistoryOverride: conversationHistoryOverride,
      );
      final refreshed = await _council.getActiveSession(
          type: BoardSessionType.category, categoryId: widget.categoryId);
      if (mounted) {
        setState(() => _session = refreshed ?? session);
        _scrollToBottom();
      }
    } on AiBudgetException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on SpendLimitException catch (e) {
      // D-061/D-062: additional-spend products are not live; explain the
      // reset boundary without promising a dead purchase flow.
      if (mounted) {
        setState(() => _error =
            'You\'ve reached this month\'s spend limit (\$${e.totalSpendUsd.toStringAsFixed(2)}'
                ' of \$${e.spendCapUsd.toStringAsFixed(2)}). Your AI access resets at the start of next month; tracking remains available now.');
      }
    } on CouncilClientException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _typingAdvisorKey = null);
    }
  }

  Future<void> _sendUserMessage() async {
    final text = _textController.text.trim();
    final session = _session;
    if (text.isEmpty || session == null || _busy) return;
    _textController.clear();
    setState(() => _busy = true);
    try {
      // D-178: the advisor must answer what was just said. `session` was
      // captured before this append and appendUserMessage does not mutate
      // it, so passing the session's own history sent every advisor a
      // transcript one message stale -- they replied to the previous turn,
      // and an advisor who had not yet spoken in that truncated view
      // introduced themselves mid-conversation. general_council_screen
      // already composes the history this way.
      final userMessage =
          await _council.appendUserMessage(session.sessionId, text);
      final conversationHistory = [
        ...session.messages
            .map((m) => {'advisor': m.advisorKey, 'text': m.text}),
        {'advisor': 'user', 'text': userMessage.text},
      ];
      // D-178: a direct question belongs to the advisor who just spoke,
      // not to whoever is next in the rotation.
      final replyAdvisorKey = session.advisorKeyForUserMessage(text);
      await _runAdvisorTurn(replyAdvisorKey,
          conversationHistoryOverride: conversationHistory);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// D-178: the essence is chosen deliberately, from one clearly labelled
  /// action, rather than by tapping an unexplained link attached to one of
  /// your own messages. The sheet says what an essence is, shows exactly
  /// what will be saved, and states that choosing one ends the conversation
  /// -- none of which the inline link conveyed.
  Future<void> _openEssenceSheet() async {
    final session = _session;
    if (session == null) return;
    final candidates = session.messages
        .where((m) => m.advisorKey == 'user')
        .map((m) => m.text)
        .where(ResonanceService.qualifies)
        .toList()
        .reversed
        .toList();

    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      builder: (sheetContext) => _EssenceSheet(
        categoryName: widget.categoryName,
        candidates: candidates,
      ),
    );
    if (chosen == null) return;
    await _acceptAsEssence(chosen);
  }

  Future<void> _acceptAsEssence(String text) async {
    final session = _session;
    if (session == null) return;

    final sanitizedEssence = AiGuard.sanitizeField(text, maxChars: 400);
    await DatabaseHelper.instance.insertCategoryEssence(
      categoryId: widget.categoryId,
      essence: sanitizedEssence,
      sourceSessionId: session.sessionId,
    );
    await _council.endSession(session.sessionId);

    // Push the new essence version to Firestore (D-147) same as any other
    // profile change; the account bootstrap in main.dart already ensures a
    // signed-in uid exists by the time this screen is reachable.
    final uid = AuthService.instance.currentUid;
    if (uid != null) {
      unawaited(SyncService.instance.syncAll(uid, setupComplete: true));
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(widget.categoryName),
        actions: [
          // D-178: one deliberate, labelled way to set the essence, replacing
          // the unexplained link that sat under every message the user sent.
          TextButton(
            onPressed: (_busy || session == null) ? null : _openEssenceSheet,
            child: const Text('Set essence',
                style: TextStyle(color: AppColors.brandGreen)),
          ),
        ],
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
                      scrollController: _scrollController,
                      // D-083: session.nextAdvisorKey is the real next
                      // speaker for this category-scoped rotation.
                      typingAdvisorKey: _busy
                          ? (_typingAdvisorKey ?? session.nextAdvisorKey)
                          : null,
                    ),
            ),
            ChatInputBar(
              controller: _textController,
              enabled: !_busy,
              onSubmit: _sendUserMessage,
            ),
          ],
        ),
      ),
    );
  }
}


/// D-178: explains what an essence is, shows exactly what will be saved, and
/// states the consequence, before anything is written. Only messages that
/// pass [ResonanceService.qualifies] are offered — short replies like "What?!"
/// could never become an essence, and previously still displayed the control.
class _EssenceSheet extends StatefulWidget {
  const _EssenceSheet({required this.categoryName, required this.candidates});
  final String categoryName;
  final List<String> candidates;

  @override
  State<_EssenceSheet> createState() => _EssenceSheetState();
}

class _EssenceSheetState extends State<_EssenceSheet> {
  late String? selected =
      widget.candidates.isEmpty ? null : widget.candidates.first;

  @override
  Widget build(BuildContext context) {
    final empty = widget.candidates.isEmpty;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your essence for ${widget.categoryName}',
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text(
              'An essence is your own words for why this category matters to '
              'you. It is what the app returns to when it talks to you about '
              'this part of your life.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            if (empty)
              const Text(
                'Nothing you have said here yet stands on its own as an '
                'essence. Keep talking, then come back — a sentence or two '
                'about why this matters is enough.',
                style: TextStyle(color: AppColors.textSecondary),
              )
            else ...[
              const Text('Choose what to save:',
                  style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final candidate in widget.candidates)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          onTap: () => setState(() => selected = candidate),
                          title: Text(candidate,
                              style: const TextStyle(
                                  color: AppColors.textPrimary, fontSize: 14)),
                          trailing: selected == candidate
                              ? const Icon(Icons.check,
                                  color: AppColors.brandGreen)
                              : null,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Saving your essence ends this conversation. You can come '
                'back and deepen it any time.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel',
                      style: TextStyle(color: AppColors.textSecondary)),
                ),
                if (!empty)
                  TextButton(
                    onPressed: selected == null
                        ? null
                        : () => Navigator.of(context).pop(selected),
                    child: const Text('Save essence',
                        style: TextStyle(color: AppColors.brandGreen)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
