import 'dart:async';

import 'package:flutter/material.dart';

import '../models/board_session.dart';
import '../widgets/advisor.dart';
import '../services/ai_guard.dart';
import '../services/auth_service.dart';
import '../services/council_client.dart';
import '../services/council_service.dart';
import '../services/db.dart';
import '../services/resonance_service.dart';
import '../services/sync_service.dart';
import '../theme/app_colors.dart';

/// D-028: a Council session scoped to one category. R5 ships the mechanism
/// — rotation, resume, an essence accepted once it meets P-12's quality bar
/// (scored by ResonanceService, D-026) — not the richer Council-driven
/// convergence D-051/D-055 define for setup; that lands in R6, built on
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
  BoardSession? _session;
  String? _priorEssence;
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
    super.dispose();
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
        categoryName: widget.categoryName,
        categoryTier: widget.categoryTier,
        priorEssence: _priorEssence,
      );
      final refreshed = await _council.getActiveSession(
          type: BoardSessionType.category, categoryId: widget.categoryId);
      if (mounted) setState(() => _session = refreshed ?? session);
    } on AiBudgetException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on SpendLimitException catch (e) {
      // D-087/D-088: the purchase flow itself waits on R8's store products
      // — for now this names the limit plainly rather than pretending it's
      // a generic failure.
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
      final next = session.nextAdvisorKey;
      await _runAdvisorTurn(next);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _acceptAsEssence(String text) async {
    if (!ResonanceService.qualifies(text)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Say a little more before accepting this as your essence.'),
      ));
      return;
    }
    final session = _session;
    if (session == null) return;

    await DatabaseHelper.instance.insertCategoryEssence(
      categoryId: widget.categoryId,
      essence: AiGuard.sanitizeField(text, maxChars: 400),
      sourceSessionId: session.sessionId,
    );
    await _council.endSession(session.sessionId);

    // Push the new essence version to Firestore (D-075) same as any other
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
      ),
      body: Column(
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ),
          Expanded(
            child: session == null
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: session.messages.length,
                    itemBuilder: (context, index) {
                      final m = session.messages[index];
                      final isUser = m.advisorKey == 'user';
                      final advisor =
                          isUser ? null : AdvisorConfig.forKey(m.advisorKey);
                      return Align(
                        alignment: isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.all(12),
                          constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.78),
                          decoration: BoxDecoration(
                            color: isUser
                                ? AppColors.surfaceHigh
                                : advisor!.bubbleColor,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isUser)
                                Text(advisor!.name,
                                    style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                              Text(m.text,
                                  style: const TextStyle(
                                      color: AppColors.textPrimary)),
                              if (isUser)
                                TextButton(
                                  onPressed: () => _acceptAsEssence(m.text),
                                  child: const Text('Use as my essence'),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
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
                      decoration: const InputDecoration(hintText: 'Say more…'),
                      onSubmitted: (_) => _sendUserMessage(),
                    ),
                  ),
                  IconButton(
                    onPressed: _busy ? null : _sendUserMessage,
                    icon: const Icon(Icons.arrow_upward, color: AppColors.brandGreen),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
