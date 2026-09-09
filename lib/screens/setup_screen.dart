import 'dart:async';

import 'package:flutter/material.dart';

import '../models/board_session.dart';
import '../services/ai_guard.dart';
import '../services/auth_service.dart';
import '../services/council_client.dart';
import '../services/council_service.dart';
import '../services/db.dart';
import '../services/entitlement_service.dart';
import '../services/resonance_service.dart';
import '../services/setup_service.dart';
import '../theme/app_colors.dart';
import '../widgets/chat_backdrop.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/council_transcript.dart';
import '../widgets/onboarding_backdrop.dart';
import '../widgets/setup_progress_indicator.dart';
import 'setup_completion_screen.dart';
import 'push_permission_screen.dart';
import 'trial_disclosure_screen.dart';

/// D-042/D-043: the app's first screen and setup in full — one continuous
/// Council conversation (D-082's `setup`-typed session), never a
/// step-by-step wizard. D-051 (categories) and D-052 (habits) appear as
/// tappable elements inline in the same scrolling conversation, not
/// separate screens; D-045 means no review step exists anywhere in this
/// file.
///
/// Simplification, disclosed in the spec: D-051 mentions dragging to
/// change tier placement as one adjustment mechanism among several — this
/// implements the same outcome (the user can move a category to a
/// different tier) via tap, not a drag gesture.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

enum _Phase {
  opening,
  openingRound,
  categories,
  refining,
  // D-102: a brief, explicit handoff between confirming categories and
  // being dropped back into chat for essence-deepening — found live: with
  // no signposting, "This feels right" leading straight back into an
  // identical-looking chat interface read as being "tossed back into
  // chat," not entering a new, purposeful phase of setup.
  essenceIntro,
  essences,
  habits,
  closing
}

class _FoundationalStep {
  final int categoryId;
  final String categoryName;
  String? capturedEssence;
  _FoundationalStep({required this.categoryId, required this.categoryName});
}

class _SetupScreenState extends State<SetupScreen> {
  static const _openingLine =
      "Hi! Let me know what energizes you. What are things that you want "
      "more of in your life?"; // D-067: fixed, not generated.

  // D-093: fixed, same rationale as D-067's opening line — a simple,
  // reliable question that doesn't need a model call to ask well. Unlike
  // the opening line, this one IS persisted (see appendAdvisorMessage's
  // doc comment): the next model call needs it in the real history to
  // understand the conversation just switched into refinement mode.
  static const _refinementPrompt =
      "What didn't feel right about this? Tell me more, and I'll refine it.";

  // D-051: the pyramid is fixed at 3/2/1 — shared by _buildCategories'
  // tier headers and _changeTier's tier-choice sheet, so the two never
  // drift into different ideas of which positions belong to which tier.
  static const List<(String, List<int>)> _tierDefinitions = [
    ('Foundational', [1, 2, 3]),
    ('Essential', [4, 5]),
    ('Peak', [6]),
  ];

  BoardMessage get _openingMessage => BoardMessage(
      advisorKey: 'mira', text: _openingLine, timestamp: DateTime.now());

  final _setup = SetupService.instance;
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  _Phase _phase = _Phase.opening;
  BoardSession? _session;
  bool _busy = false;
  String? _error;
  // D-093: true while re-entering the conversation from "Not quite
  // right" — routes both the Mira turn and the eventual re-derivation
  // through the refine-not-replace path.
  bool _refining = false;

  /// The categories to treat as "already proposed" for this turn — only
  /// meaningful while [_refining], and read before any re-derivation
  /// overwrites [_categories] with the refined result.
  List<CategoryProposal>? get _refinementContext =>
      _refining ? _categories : null;

  List<CategoryProposal> _categories = const [];
  int _essenceIndex = 0;
  List<_FoundationalStep> _foundational = const [];
  // D-105: the index into _session.messages where this category's own
  // essence-deepening exchange begins — captured right before
  // _askAboutCurrentFoundational asks the question, so _buildEssences can
  // show only this category's Q&A rather than the whole session (see its
  // own doc comment for what that used to leak into view).
  int? _essenceStepStartIndex;
  final Map<String, List<String>> _habitsByCategory = {};
  Set<String> _habitCategoriesLoading = {};

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

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      // D-032's silent account bootstrap is deliberately fire-and-forget
      // from main.dart so it never gates the first frame — but a Council
      // session write needs request.auth to already exist. On a brand-new
      // device (no cached Firebase Auth session) this screen would
      // otherwise race that sign-in and lose. signInSilently() is a no-op
      // once already signed in, so awaiting it here is always cheap.
      await AuthService.instance.signInSilently();
      final session = await _setup.startOrResumeSetup();
      setState(() {
        _session = session;
        // D-062-adjacent resume: an in-progress session with messages
        // already resumes into the opening round rather than replaying
        // Mira's fixed line a second time.
        _phase =
            session.messages.isEmpty ? _Phase.opening : _Phase.openingRound;
      });
      // D-090: resuming mid-round only needs a fresh Mira turn if the
      // session was interrupted right after the user's own message —
      // otherwise she has already replied and it's the user's turn next,
      // so there is nothing to run and the text input just waits for them.
      final last = session.messages.isNotEmpty ? session.messages.last : null;
      if (_phase == _Phase.openingRound && last?.advisorKey == 'user') {
        await _runMiraTurn();
      }
    } on SetupAlreadyCompleteException {
      // D-082: this account already has a real local pyramid and already
      // completed a setup session — nothing here to resume or redo.
      // Leave setup entirely rather than show an error inside a chat UI
      // with nothing behind it.
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e, st) {
      debugPrint('SetupScreen: failed to start or resume setup: $e\n$st');
      setState(() => _error = 'Could not start setup. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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

  // ── Opening (D-042/D-067/D-090): a solo, back-and-forth conversation ───
  // with Mira alone — not the four-advisor pile-on this used to be. That
  // mechanic moved to the general Council chat (D-091); setup is now one
  // advisor, a few real exchanges, until she signals she has enough.

  Future<void> _sendOpeningReply() async {
    final text = _textController.text.trim();
    final session = _session;
    if (text.isEmpty || session == null || _busy) return;
    _textController.clear();
    setState(() => _busy = true);
    try {
      await CouncilService.instance.appendUserMessage(session.sessionId, text);
      final refreshed = await CouncilService.instance
          .getActiveSession(type: BoardSessionType.setup);
      setState(() {
        _session = refreshed ?? session;
        // D-093: a reply sent while refining stays in the refining phase
        // — only the very first reply (not yet refining) advances into
        // the shared openingRound phase.
        _phase = _refining ? _Phase.refining : _Phase.openingRound;
      });
      await _runMiraTurn();
    } on AiBudgetException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Refinement (D-093): "Not quite right" re-enters the conversation ───
  // instead of only offering to accept the proposal — Mira asks what felt
  // off, then refines the existing six categories rather than discarding
  // them and starting over.

  Future<void> _requestRefinement() async {
    final session = _session;
    if (session == null) return;
    setState(() => _busy = true);
    try {
      await CouncilService.instance
          .appendAdvisorMessage(session.sessionId, 'mira', _refinementPrompt);
      final refreshed = await CouncilService.instance
          .getActiveSession(type: BoardSessionType.setup);
      setState(() {
        _session = refreshed ?? session;
        _refining = true;
        _phase = _Phase.refining;
      });
      _scrollToBottom();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runMiraTurn() async {
    final session = _session;
    if (session == null) return;
    setState(() => _busy = true);
    try {
      final result = await CouncilService.instance
          .runMiraSetupTurn(session, existingCategories: _refinementContext);
      setState(() => _session = result.session);
      _scrollToBottom();
      if (result.readyToBuild) {
        // A beat before the categories phase replaces the transcript
        // outright — Mira's closing line deserves to be read, not
        // instantly swapped out from under the user (same pacing D-042
        // already established for the old multi-advisor round).
        if (mounted) await Future.delayed(const Duration(milliseconds: 700));
        // Captured before _categories is overwritten by the re-derivation
        // below, and before _refining resets — this is the last point
        // _refinementContext still reflects the proposal being refined.
        final priorCategories = _refinementContext;
        setState(() {
          _phase = _Phase.categories;
          _refining = false;
        });
        await _loadCategories(existingCategories: priorCategories);
      }
      // Otherwise: stay in the current phase. The text input is already
      // visible there, waiting for the user's next reply.
    } on AiBudgetException catch (e) {
      setState(() => _error = e.message);
    } on SpendLimitException catch (e) {
      setState(() => _error = e.toString());
    } on SetupCallLimitException {
      // D-072: approaching the bound — close gracefully rather than fail.
      final priorCategories = _refinementContext;
      setState(() {
        _phase = _Phase.categories;
        _refining = false;
      });
      await _loadCategories(existingCategories: priorCategories);
    } on CouncilClientException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<BoardSession> _runSetupTurn(BoardSession session, String advisorKey,
      {String? categoryName}) async {
    await CouncilService.instance.runAdvisorTurn(
      session: session,
      advisorKey: advisorKey,
      categoryName: categoryName ?? 'their life',
    );
    final refreshed = await CouncilService.instance
        .getActiveSession(type: BoardSessionType.setup);
    final updated = refreshed ?? session;
    if (mounted) setState(() => _session = updated);
    return updated;
  }

  // ── Categories (D-051) ──────────────────────────────────────────────────

  Future<void> _loadCategories(
      {List<CategoryProposal>? existingCategories}) async {
    final session = _session;
    if (session == null) return;
    setState(() => _busy = true);
    try {
      final categories = await _setup.proposeCategories(session,
          existingCategories: existingCategories);
      setState(() => _categories = categories);
    } on SetupCallLimitException {
      // Nothing to propose from if the bound is already hit on the very
      // first derivation call — surface plainly rather than looping.
      setState(
          () => _error = 'Setup reached its limit. Please try again shortly.');
    } on CouncilClientException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _renameCategory(int index) {
    final controller = TextEditingController(text: _categories[index].name);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Your own words',
            style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: AppColors.textPrimary),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final name = AiGuard.sanitizeField(controller.text, maxChars: 60);
              if (name.isNotEmpty) {
                setState(() {
                  _categories = [..._categories];
                  _categories[index] = CategoryProposal(
                      position: _categories[index].position,
                      name: name,
                      description: _categories[index].description);
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _changeTier(int index) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final tier in _tierDefinitions)
              ListTile(
                title: Text(
                    '${tier.$1} (${_categories.where((c) => tier.$2.contains(c.position)).length}/${tier.$2.length})',
                    style: const TextStyle(color: AppColors.textPrimary)),
                onTap: () => _moveToTier(index, tier.$2),
              ),
          ],
        ),
      ),
    );
  }

  // D-051: the pyramid's shape is fixed at 3/2/1 — every position 1-6 is
  // always occupied by exactly one category. Found live: moving into a
  // full tier used to silently drop the moved category onto an already-
  // taken position, duplicating it and leaving the tier it came from
  // empty ("four in Foundational, none in Peak"). A tier with room still
  // gets a plain move; a full tier requires picking who to swap places
  // with, so the 3/2/1 shape can never break.
  void _moveToTier(int index, List<int> tierPositions) {
    Navigator.pop(context); // the tier-choice sheet
    final sourcePosition = _categories[index].position;
    if (tierPositions.contains(sourcePosition)) return; // already there

    final taken = _categories.map((c) => c.position).toSet();
    final openSlot =
        tierPositions.firstWhere((p) => !taken.contains(p), orElse: () => -1);
    if (openSlot != -1) {
      setState(() {
        _categories = [..._categories];
        _categories[index] = CategoryProposal(
            position: openSlot,
            name: _categories[index].name,
            description: _categories[index].description);
        _categories.sort((a, b) => a.position.compareTo(b.position));
      });
      return;
    }
    _pickSwapTarget(index, tierPositions);
  }

  void _pickSwapTarget(int index, List<int> tierPositions) {
    final candidates = _categories
        .where((c) => tierPositions.contains(c.position))
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text('This tier is full — swap places with:',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ),
            for (final c in candidates)
              ListTile(
                title:
                    Text(c.name, style: const TextStyle(color: AppColors.textPrimary)),
                onTap: () => _swapPositions(index, c.position),
              ),
          ],
        ),
      ),
    );
  }

  void _swapPositions(int index, int otherPosition) {
    Navigator.pop(context); // the swap-choice sheet
    final otherIndex = _categories.indexWhere((c) => c.position == otherPosition);
    final sourcePosition = _categories[index].position;
    setState(() {
      _categories = [..._categories];
      _categories[otherIndex] = CategoryProposal(
          position: sourcePosition,
          name: _categories[otherIndex].name,
          description: _categories[otherIndex].description);
      _categories[index] = CategoryProposal(
          position: otherPosition,
          name: _categories[index].name,
          description: _categories[index].description);
      _categories.sort((a, b) => a.position.compareTo(b.position));
    });
  }

  Future<void> _confirmCategories() async {
    setState(() => _busy = true);
    try {
      await _setup.commitCategories(_categories);
      _foundational = _categories
          .where((c) => c.position <= 3)
          .map((c) =>
              _FoundationalStep(categoryId: c.position, categoryName: c.name))
          .toList()
        ..sort((a, b) => a.categoryId.compareTo(b.categoryId));
      // D-102: stop here, on a plain handoff screen, rather than dropping
      // straight back into chat with no signal a new phase has begun —
      // found live: "This feels right" leading straight into what looks
      // like the identical chat interface read as being "tossed back into
      // chat," not entering a new, purposeful step of setup.
      setState(() => _phase = _Phase.essenceIntro);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // D-102: the actual start of essence-deepening, moved out of
  // _confirmCategories — now triggered by the person tapping through the
  // handoff screen, not fired automatically the instant categories commit.
  // _askAboutCurrentFoundational manages its own _busy toggle, so this
  // only needs to set the phase and index before calling it.
  Future<void> _beginEssenceDeepening() async {
    setState(() {
      _phase = _Phase.essences;
      _essenceIndex = 0;
    });
    // Found live: nothing ever kicked off the first foundational
    // category's essence conversation — only _acceptEssence() (moving to
    // the 2nd and 3rd) called this. The first category's screen opened
    // onto whatever was already in the transcript from earlier in setup,
    // never a question actually directed at it.
    await _askAboutCurrentFoundational();
  }

  // ── Essences for the three foundational categories (D-009/D-028) ───────

  Future<void> _acceptEssence(String text) async {
    if (!ResonanceService.qualifies(text)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Say a little more before we call that your essence.'),
      ));
      return;
    }
    final session = _session;
    if (session == null) return;
    final step = _foundational[_essenceIndex];
    await _setup.commitEssence(
        categoryId: step.categoryId,
        essence: text,
        sessionId: session.sessionId);
    step.capturedEssence = text;

    // D-048: advisory, never required (D-074) — never blocks setup's
    // progression, which continues immediately below.
    unawaited(_setup.recordDomainFindings(
      session: session,
      categoryId: step.categoryId,
      categoryName: step.categoryName,
      essence: text,
      isSetup: true,
    ));

    if (_essenceIndex + 1 < _foundational.length) {
      setState(() => _essenceIndex++);
      await _askAboutCurrentFoundational();
    } else {
      setState(() => _phase = _Phase.habits);
      await _loadAllHabits();
    }
  }

  Future<void> _askAboutCurrentFoundational() async {
    final session = _session;
    if (session == null) return;
    final step = _foundational[_essenceIndex];
    setState(() => _busy = true);
    try {
      // D-105: captured before the question is appended — the index this
      // category's own exchange starts at, so _buildEssences can scope
      // the visible transcript to just this Q&A.
      _essenceStepStartIndex = session.messages.length;
      // D-106: always Mira — never session.rotationOrder's shuffled pick.
      // Found live: a different advisor appearing partway through
      // essence-deepening (still nominally "one continuous setup
      // conversation," D-043) read as a confusing non-sequitur switch,
      // on top of the leftover-context defect above. The owner's
      // decision: multiple advisors belong to the general Council
      // conversation (D-091) and post-setup re-clarification (D-061),
      // once there's real data for a council of voices to be useful
      // against — setup itself stays one continuous voice throughout,
      // matching D-090's opening conversation.
      await CouncilService.instance.runAdvisorTurn(
        session: session,
        advisorKey: 'mira',
        categoryName: step.categoryName,
      );
      final refreshed = await CouncilService.instance
          .getActiveSession(type: BoardSessionType.setup);
      setState(() => _session = refreshed ?? session);
      _scrollToBottom();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendEssenceReply() async {
    final text = _textController.text.trim();
    final session = _session;
    if (text.isEmpty || session == null || _busy) return;
    _textController.clear();
    setState(() => _busy = true);
    try {
      await CouncilService.instance.appendUserMessage(session.sessionId, text);
      final refreshed = await CouncilService.instance
          .getActiveSession(type: BoardSessionType.setup);
      setState(() => _session = refreshed ?? session);
      // D-105: found live — the "Save this" button (once it earns
      // showing, per _buildEssences' resonance gate above) could land
      // below the fold with nothing scrolling it into view.
      _scrollToBottom();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Habits (D-052/D-054/D-103) ──────────────────────────────────────────

  // D-103: the owner's explicit ceiling — never more than this many daily
  // habits across the whole pyramid, regardless of category count.
  static const _maxTotalHabits = 10;

  Future<void> _loadAllHabits() async {
    final session = _session;
    if (session == null) return;
    var totalCommitted = 0;
    for (var i = 0; i < _categories.length; i++) {
      final c = _categories[i];
      setState(
          () => _habitCategoriesLoading = {..._habitCategoriesLoading, c.name});
      final essence = _foundational
          .where((f) => f.categoryName == c.name)
          .map((f) => f.capturedEssence)
          .firstOrNull;
      // D-103: reserve at least 1 slot for every category still to come,
      // so an early category greedily using its full allowance can never
      // leave a later one with nothing — the running total this produces
      // can undershoot 10 (a category is free to propose fewer than its
      // allowance) but never exceed it.
      final remainingAfterThis = _categories.length - 1 - i;
      final maxAllowed =
          (_maxTotalHabits - totalCommitted - remainingAfterThis).clamp(1, 3);
      try {
        final habits = await _setup.proposeHabits(
          session: session,
          categoryName: c.name,
          essence: essence,
          maxAllowed: maxAllowed,
        );
        totalCommitted += habits.length;
        setState(() => _habitsByCategory[c.name] = habits);
      } catch (e) {
        // D-052: the proposed set is allowed to be empty — the user can
        // always add their own — so a failure here degrades rather than
        // blocks setup. Still logged: a silently empty category otherwise
        // looks identical to "the Council had nothing to suggest."
        debugPrint('SetupScreen: habit proposal failed for "${c.name}": $e');
        setState(() => _habitsByCategory[c.name] = const []);
      } finally {
        setState(() => _habitCategoriesLoading = {..._habitCategoriesLoading}
          ..remove(c.name));
      }
    }
  }

  Future<void> _confirmHabitsAndClose() async {
    setState(() {
      _busy = true;
      _phase = _Phase.closing;
    });
    try {
      for (final entry in _habitsByCategory.entries) {
        await _setup.commitHabits(entry.key, entry.value);
      }
      final session = _session!;
      final essences = _foundational
          .where((f) => f.capturedEssence != null)
          .map((f) =>
              (categoryName: f.categoryName, essence: f.capturedEssence!))
          .toList();
      await _setup.closeSynthesis(session: session, essences: essences);
      await _setup.syncAfterSetup();
      // D-058: the trial clock starts here, at the pyramid reveal — awaited
      // before navigating so the D-014 disclosure screen below can show the
      // real outcome (a device that already consumed its trial lands in
      // 'lapsed', not 'trialing').
      await EntitlementService.instance.requestTrialAfterSetup();
      final account = await DatabaseHelper.instance.getAccountState();
      final entitlement = account[DatabaseHelper.columnEntitlement] as String?;
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (context) => SetupCompletionScreen(
          onDone: () => Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (context) => TrialDisclosureScreen(
              entitlement: entitlement,
              // D-065: push permission is requested here — immediately
              // after the completion moment settles, before the home
              // screen, never on first launch.
              onDone: () =>
                  Navigator.of(context).pushReplacement(MaterialPageRoute(
                builder: (context) => PushPermissionScreen(
                  onDone: () => Navigator.of(context)
                      .pushNamedAndRemoveUntil('/', (route) => false),
                ),
              )),
            ),
          )),
        ),
      ));
    } on AiBudgetException catch (e) {
      // Found live: this whole method had no catch clause at all — any
      // failure here (most plausibly this one, a client-side rate/day
      // budget, after enough setup runs in one day) left the user
      // permanently stuck on the "closing" phase's static text with no
      // error shown and no way back, only `_busy` quietly reset to false
      // by the finally block underneath. Reverting to the habits phase
      // means "Build my pyramid" is tappable again once the real cause
      // (budget, network, spend cap) clears, instead of a dead end.
      setState(() {
        _error = e.message;
        _phase = _Phase.habits;
      });
    } on SpendLimitException catch (e) {
      setState(() {
        _error = e.toString();
        _phase = _Phase.habits;
      });
    } on CouncilClientException catch (e) {
      setState(() {
        _error = e.message;
        _phase = _Phase.habits;
      });
    } catch (e, st) {
      debugPrint('SetupScreen: _confirmHabitsAndClose failed: $e\n$st');
      setState(() {
        _error = 'Something went wrong finishing setup. Please try again.';
        _phase = _Phase.habits;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ChatBackdrop(
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(_error!,
                          style: const TextStyle(color: Colors.redAccent)),
                    ),
                  Expanded(child: _buildBody()),
                  if (_phase == _Phase.opening ||
                      _phase == _Phase.openingRound ||
                      _phase == _Phase.refining ||
                      _phase == _Phase.essences)
                    _buildTextInput(),
                ],
              ),
              Positioned(
                top: 8,
                right: 8,
                child: SetupProgressIndicator(progress: _progressFor(_phase)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _progressFor(_Phase phase) {
    switch (phase) {
      case _Phase.opening:
        return 0.05;
      case _Phase.openingRound:
        return 0.15;
      case _Phase.categories:
        return 0.35;
      case _Phase.refining:
        return 0.3;
      case _Phase.essenceIntro:
        return 0.35;
      case _Phase.essences:
        return 0.35 + 0.3 * (_essenceIndex / 3);
      case _Phase.habits:
        return 0.8;
      case _Phase.closing:
        return 0.95;
    }
  }

  Widget _buildBody() {
    switch (_phase) {
      case _Phase.opening:
        return _buildTranscript([_openingMessage],
            typingAdvisorKey: _busy ? 'mira' : null);
      case _Phase.openingRound:
        // D-067/D-042: Mira's opening line is never persisted to Firestore
        // (it's fixed, client-only copy) — only the user's reply and each
        // advisor's turn are. A session resumed after an earlier launch
        // failed mid-round (e.g. a backend call that errored before any
        // advisor replied) therefore has real messages but no Mira line at
        // all, and would otherwise render straight into an unframed
        // transcript with no visible Council prompt. Always prepending it
        // here — cheap, since it's static — means the user sees Mira's
        // opening on every render of this phase, resumed or not.
        return _buildTranscript([_openingMessage, ...?_session?.messages],
            typingAdvisorKey: _busy ? 'mira' : null);
      case _Phase.categories:
        return _buildCategories();
      case _Phase.refining:
        // D-067/D-093: found live — refining renders the conversation from
        // its start, but Mira's opening line is never persisted (it's
        // fixed, client-only copy, same as the openingRound case above),
        // so without prepending it here it silently vanished the moment a
        // user tapped "Not quite right" and came back to the chat. The
        // refinement prompt itself IS persisted (see appendAdvisorMessage)
        // and is already part of session.messages — only the very first
        // line needs reconstructing.
        return _buildTranscript([_openingMessage, ...?_session?.messages],
            typingAdvisorKey: _busy ? 'mira' : null);
      case _Phase.essenceIntro:
        return _buildEssenceIntro();
      case _Phase.essences:
        return _buildEssences();
      case _Phase.habits:
        return _buildHabits();
      case _Phase.closing:
        // D-046: this phase covers committing habits, the closing
        // synthesis, syncing, and requesting the trial — "writing your
        // vision statement" named only one of those four steps and read
        // as wrong/stuck-sounding once the others were running.
        return const Center(
          child: Text('Building your pyramid…',
              style: TextStyle(color: AppColors.textSecondary)),
        );
    }
  }

  // D-101: every caller of this in opening/openingRound/refining is a
  // solo-Mira conversation (D-090) — 'mira' is always correct, unlike
  // session.nextAdvisorKey, which reflects a shuffled four-advisor
  // rotationOrder that setup sessions carry but never actually use for
  // these turns.
  Widget _buildTranscript(List<BoardMessage> messages, {String? typingAdvisorKey}) {
    return CouncilTranscript(
      messages: messages,
      scrollController: _scrollController,
      typingAdvisorKey: typingAdvisorKey,
    );
  }

  // D-102: the explicit handoff between confirming categories and being
  // dropped back into chat for essence-deepening — plain typography over
  // the existing ChatBackdrop (this phase's content, like every other
  // phase's, renders inside SetupScreen's own ChatBackdrop already; a
  // second, different full-bleed backdrop stacked on top of it would
  // fight rather than match). OnboardingStyles gives it the same type
  // scale as the welcome screen without introducing a second background
  // treatment for one screen.
  Widget _buildEssenceIntro() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(flex: 5),
          const Text(
            'Now, three questions worth sitting with.',
            style: OnboardingStyles.headline,
          ),
          const SizedBox(height: 14),
          OnboardingStyles.accentDivider,
          const SizedBox(height: 16),
          const Text(
            "The Council will ask about your top three values, one at a "
            "time. What you say here is what makes every habit — and "
            "every conversation from here on — actually fit you, instead "
            "of being generic.",
            style: OnboardingStyles.subhead,
          ),
          const Spacer(flex: 4),
          Padding(
            padding: const EdgeInsets.only(bottom: 28),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _busy ? null : _beginEssenceDeepening,
                style: OnboardingStyles.primaryButton,
                child: const Text("Let's go deeper", style: OnboardingStyles.buttonLabel),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategories() {
    if (_categories.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    Widget tierSection(String label, int capacity, Iterable<CategoryProposal> items) {
      final list = items.toList();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // D-051: every tier always holds exactly its fixed count
            // (3/2/1) — shown here so a tier can never quietly read as
            // empty or overfull the way it used to when a move onto a
            // full tier silently duplicated a position.
            Text('$label (${list.length}/$capacity)',
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            for (final c in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onLongPress: () => _changeTier(_categories.indexOf(c)),
                  onTap: () => _renameCategory(_categories.indexOf(c)),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.brandGreen.withValues(alpha: 0.18)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.name,
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                        if (c.description != null) ...[
                          const SizedBox(height: 3),
                          Text(c.description!,
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                  height: 1.35)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Here is what I heard.',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 18)),
            const SizedBox(height: 4),
            const Text(
                'Tap a name to change it. Hold to move it to a different tier.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            for (final tier in _tierDefinitions)
              tierSection(tier.$1, tier.$2.length,
                  _categories.where((c) => tier.$2.contains(c.position))),
            const SizedBox(height: 16),
            // D-093: "Not quite right" re-enters the conversation instead
            // of only offering to accept the proposal — the owner
            // specifically wanted a way to keep working on the list, not
            // just confirm or abandon it.
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : _requestRefinement,
                    child: const Text('Not quite right'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _busy ? null : _confirmCategories,
                    child: const Text('This feels right'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEssences() {
    if (_foundational.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final step = _foundational[_essenceIndex];
    // D-105: found live — this used to render the whole session's
    // messages, unscoped. Setup is one continuous session (D-043), so
    // that included the entire opening conversation that already built
    // the pyramid (Mira's own readyToBuild closing line among it) sitting
    // directly above this category's actual question, and — for the 2nd
    // and 3rd categories — every earlier category's essence exchange too.
    // _essenceStepStartIndex, captured right before this category's
    // question is asked (_askAboutCurrentFoundational), scopes the view
    // to just this category's own Q&A.
    final stepMessages = (_session != null && _essenceStepStartIndex != null)
        ? _session!.messages.sublist(
            _essenceStepStartIndex!.clamp(0, _session!.messages.length))
        : const <BoardMessage>[];
    // D-105: gated on the same resonance bar _acceptEssence itself
    // enforces (ResonanceService.qualifies), not merely "any reply
    // exists" — found live, the button used to appear the instant any
    // message landed, including a short filler reply nowhere near
    // substantial enough, so tapping it immediately bounced with a
    // snackbar. The button now only ever appears once it will actually
    // work.
    final userMessages = stepMessages
        .where((m) => m.advisorKey == 'user' && ResonanceService.qualifies(m.text))
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
              'Going deeper: ${step.categoryName} (${_essenceIndex + 1} of 3)',
              style: const TextStyle(color: AppColors.textSecondary)),
        ),
        Expanded(child: _buildTranscript(
          stepMessages,
          // D-106: always 'mira' — matches _askAboutCurrentFoundational,
          // which no longer rotates through session.rotationOrder.
          typingAdvisorKey: _busy ? 'mira' : null,
        )),
        if (userMessages.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _acceptEssence(userMessages.last.text),
                child: const Text("That's it — save this"),
              ),
            ),
          ),
      ],
    );
  }

  // D-052: the auto-generated set is a starting point, never the only
  // option — the user can reword any of them, drop them (the chip's own
  // x), or write one of their own from scratch.
  void _editHabit(String categoryName, String current) {
    final controller = TextEditingController(text: current);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Say it your way',
            style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: AppColors.textPrimary),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final text = AiGuard.sanitizeField(controller.text, maxChars: 60);
              if (text.isNotEmpty) {
                setState(() {
                  _habitsByCategory[categoryName] = [
                    for (final h in _habitsByCategory[categoryName] ?? const [])
                      if (h == current) text else h,
                  ];
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _addHabit(String categoryName) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Add a habit',
            style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: AppColors.textPrimary),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final text = AiGuard.sanitizeField(controller.text, maxChars: 60);
              if (text.isNotEmpty) {
                setState(() {
                  _habitsByCategory[categoryName] = [
                    ...?_habitsByCategory[categoryName],
                    text,
                  ];
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _buildHabits() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // D-104: explicit, not implicit — the chips below are editable
          // right here, but nothing said so in words, and nothing said
          // these default to a daily schedule (D-054) or that either fact
          // still holds after setup ends. Found live: the owner asked for
          // this stated plainly before the completion reveal, not left
          // for the person to infer from the chips' own affordances.
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              "Here's what you'll track daily. Tap any habit to reword it, "
              "or the x to drop it — and you can change all of this again "
              "anytime after setup, from the category itself.",
              style: TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
          ),
          for (final c in _categories) ...[
            Text(c.name,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
            if (_habitCategoriesLoading.contains(c.name))
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final h in _habitsByCategory[c.name] ?? const [])
                    InputChip(
                      label: Text(h),
                      backgroundColor: AppColors.surfaceHigh,
                      labelStyle: const TextStyle(color: AppColors.textPrimary),
                      // The auto-generated ones are a starting point, not
                      // the final word: tap to change the wording, the x
                      // to drop it entirely.
                      onPressed: () => _editHabit(c.name, h),
                      onDeleted: () => setState(() {
                        _habitsByCategory[c.name] = [
                          for (final x in _habitsByCategory[c.name]!)
                            if (x != h) x,
                        ];
                      }),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add,
                        size: 18, color: AppColors.brandGreen),
                    label: const Text('Add'),
                    backgroundColor: AppColors.surfaceHigh,
                    labelStyle: const TextStyle(color: AppColors.brandGreen),
                    onPressed: () => _addHabit(c.name),
                  ),
                ],
              ),
            const SizedBox(height: 16),
          ],
          ElevatedButton(
            onPressed: (_busy || _habitCategoriesLoading.isNotEmpty)
                ? null
                : _confirmHabitsAndClose,
            child: const Text('Build my pyramid'),
          ),
        ],
      ),
    );
  }

  Widget _buildTextInput() {
    return ChatInputBar(
      controller: _textController,
      enabled: !_busy,
      onSubmit: _onSubmitText,
    );
  }

  void _onSubmitText() {
    if (_phase == _Phase.opening ||
        _phase == _Phase.openingRound ||
        _phase == _Phase.refining) {
      // D-090/D-093: the same handler serves the very first reply, every
      // back-and-forth exchange after it, and every refinement reply —
      // Mira decides when she has enough, not a fixed turn count, so
      // there is no separate "continue the round" path.
      _sendOpeningReply();
    } else if (_phase == _Phase.essences) {
      _sendEssenceReply();
    }
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
