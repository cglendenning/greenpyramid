import 'package:flutter/material.dart';

import '../models/board_session.dart';
import '../services/ai_guard.dart';
import '../services/council_client.dart';
import '../services/council_service.dart';
import '../services/resonance_service.dart';
import '../services/setup_service.dart';
import '../theme/app_colors.dart';
import '../widgets/advisor.dart';
import '../widgets/setup_progress_indicator.dart';
import 'setup_completion_screen.dart';
import 'push_permission_screen.dart';

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

enum _Phase { opening, openingRound, categories, essences, habits, closing }

class _FoundationalStep {
  final int categoryId;
  final String categoryName;
  String? capturedEssence;
  _FoundationalStep({required this.categoryId, required this.categoryName});
}

class _SetupScreenState extends State<SetupScreen> {
  static const _openingLine =
      "I'm not going to ask what you want to change. Tell me about a day "
      "recently that felt like it mattered."; // D-067: fixed, not generated.

  final _setup = SetupService.instance;
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  _Phase _phase = _Phase.opening;
  BoardSession? _session;
  bool _busy = false;
  String? _error;

  List<CategoryProposal> _categories = const [];
  int _essenceIndex = 0;
  List<_FoundationalStep> _foundational = const [];
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
      final session = await _setup.startOrResumeSetup();
      setState(() {
        _session = session;
        // D-062-adjacent resume: an in-progress session with messages
        // already resumes into the opening round rather than replaying
        // Mira's fixed line a second time.
        _phase = session.messages.isEmpty ? _Phase.opening : _Phase.openingRound;
      });
      if (_phase == _Phase.openingRound) await _runOpeningRound();
    } catch (e) {
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

  // ── Opening (D-042/D-067) and the other three advisors joining in ──────

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
        _phase = _Phase.openingRound;
      });
      await _runOpeningRound();
    } on AiBudgetException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runOpeningRound() async {
    var session = _session;
    if (session == null) return;
    setState(() => _busy = true);
    try {
      // The other three advisors, in rotation order, minus whichever
      // already spoke this session.
      final spoken = session.messages.map((m) => m.advisorKey).toSet();
      for (final advisorKey in session.rotationOrder) {
        if (spoken.contains(advisorKey)) continue;
        session = await _runSetupTurn(session!, advisorKey);
        _scrollToBottom();
      }
      setState(() => _phase = _Phase.categories);
      await _loadCategories();
    } on AiBudgetException catch (e) {
      setState(() => _error = e.message);
    } on SpendLimitException catch (e) {
      setState(() => _error = e.toString());
    } on SetupCallLimitException {
      // D-072: approaching the bound — close gracefully rather than fail.
      setState(() => _phase = _Phase.categories);
      await _loadCategories();
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

  Future<void> _loadCategories() async {
    final session = _session;
    if (session == null) return;
    setState(() => _busy = true);
    try {
      final categories = await _setup.proposeCategories(session);
      setState(() => _categories = categories);
    } on SetupCallLimitException {
      // Nothing to propose from if the bound is already hit on the very
      // first derivation call — surface plainly rather than looping.
      setState(() => _error = 'Setup reached its limit. Please try again shortly.');
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
              onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final name = AiGuard.sanitizeField(controller.text, maxChars: 60);
              if (name.isNotEmpty) {
                setState(() {
                  _categories = [..._categories];
                  _categories[index] =
                      CategoryProposal(position: _categories[index].position, name: name);
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
            for (final tier in [
              ('Foundational', [1, 2, 3]),
              ('Essential', [4, 5]),
              ('Peak', [6]),
            ])
              ListTile(
                title: Text(tier.$1,
                    style: const TextStyle(color: AppColors.textPrimary)),
                onTap: () => _moveToTier(index, tier.$2),
              ),
          ],
        ),
      ),
    );
  }

  void _moveToTier(int index, List<int> openPositions) {
    Navigator.pop(context);
    final taken = _categories.map((c) => c.position).toSet()
      ..remove(_categories[index].position);
    final target = openPositions.firstWhere((p) => !taken.contains(p),
        orElse: () => openPositions.first);
    setState(() {
      _categories = [..._categories];
      _categories[index] =
          CategoryProposal(position: target, name: _categories[index].name);
      _categories.sort((a, b) => a.position.compareTo(b.position));
    });
  }

  Future<void> _confirmCategories() async {
    setState(() => _busy = true);
    try {
      await _setup.commitCategories(_categories);
      _foundational = _categories
          .where((c) => c.position <= 3)
          .map((c) => _FoundationalStep(categoryId: c.position, categoryName: c.name))
          .toList()
        ..sort((a, b) => a.categoryId.compareTo(b.categoryId));
      setState(() {
        _phase = _Phase.essences;
        _essenceIndex = 0;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
      categoryId: step.categoryId, essence: text, sessionId: session.sessionId);
    step.capturedEssence = text;

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
      await CouncilService.instance.runAdvisorTurn(
        session: session,
        advisorKey: session.rotationOrder[_essenceIndex % session.rotationOrder.length],
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
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Habits (D-052/D-054) ────────────────────────────────────────────────

  Future<void> _loadAllHabits() async {
    final session = _session;
    if (session == null) return;
    for (final c in _categories) {
      setState(() => _habitCategoriesLoading = {..._habitCategoriesLoading, c.name});
      final essence = _foundational
          .where((f) => f.categoryName == c.name)
          .map((f) => f.capturedEssence)
          .firstOrNull;
      try {
        final habits = await _setup.proposeHabits(
          session: session,
          categoryName: c.name,
          essence: essence,
        );
        setState(() => _habitsByCategory[c.name] = habits);
      } catch (_) {
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
          .map((f) => (categoryName: f.categoryName, essence: f.capturedEssence!))
          .toList();
      await _setup.closeSynthesis(session: session, essences: essences);
      await _setup.syncAfterSetup();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (context) => SetupCompletionScreen(
          // D-065: push permission is requested here — immediately after
          // the completion moment settles, before the home screen, never
          // on first launch.
          onDone: () => Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (context) => PushPermissionScreen(
              onDone: () => Navigator.of(context)
                  .pushNamedAndRemoveUntil('/', (route) => false),
            ),
          )),
        ),
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
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
                if (_phase == _Phase.opening || _phase == _Phase.essences)
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
        return _buildTranscript([
          BoardMessage(advisorKey: 'mira', text: _openingLine, timestamp: DateTime.now())
        ]);
      case _Phase.openingRound:
        return _buildTranscript(_session?.messages ?? const []);
      case _Phase.categories:
        return _buildCategories();
      case _Phase.essences:
        return _buildEssences();
      case _Phase.habits:
        return _buildHabits();
      case _Phase.closing:
        return const Center(
          child: Text('The Council is writing your vision statement…',
              style: TextStyle(color: AppColors.textSecondary)),
        );
    }
  }

  Widget _buildTranscript(List<BoardMessage> messages) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final m = messages[index];
        final isUser = m.advisorKey == 'user';
        final advisor = isUser ? null : AdvisorConfig.forKey(m.advisorKey);
        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.all(12),
            constraints:
                BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
            decoration: BoxDecoration(
              color: isUser ? AppColors.surfaceHigh : advisor!.bubbleColor,
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
                Text(m.text, style: const TextStyle(color: AppColors.textPrimary)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategories() {
    if (_categories.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    const tierLabels = {1: 'Foundational', 2: 'Essential', 3: 'Peak'};
    Widget tierSection(String label, Iterable<CategoryProposal> items) {
      final list = items.toList();
      if (list.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in list)
                  GestureDetector(
                    onLongPress: () => _changeTier(_categories.indexOf(c)),
                    child: ActionChip(
                      label: Text(c.name),
                      backgroundColor: AppColors.surfaceHigh,
                      labelStyle: const TextStyle(color: AppColors.textPrimary),
                      onPressed: () => _renameCategory(_categories.indexOf(c)),
                    ),
                  ),
              ],
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
            const Text('Tap a name to change it. Hold to move it to a different tier.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            tierSection(tierLabels[1]!, _categories.where((c) => c.position <= 3)),
            tierSection(tierLabels[2]!,
                _categories.where((c) => c.position == 4 || c.position == 5)),
            tierSection(tierLabels[3]!, _categories.where((c) => c.position == 6)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _busy ? null : _confirmCategories,
              child: const Text('This feels right'),
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
    final userMessages = (_session?.messages ?? const [])
        .where((m) => m.advisorKey == 'user')
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text('${step.categoryName} (${_essenceIndex + 1} of 3)',
              style: const TextStyle(color: AppColors.textSecondary)),
        ),
        Expanded(child: _buildTranscript(_session?.messages ?? const [])),
        if (userMessages.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextButton(
              onPressed: () => _acceptEssence(userMessages.last.text),
              child: const Text('Use as my essence'),
            ),
          ),
      ],
    );
  }

  Widget _buildHabits() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                    Chip(
                      label: Text(h),
                      backgroundColor: AppColors.surfaceHigh,
                      labelStyle: const TextStyle(color: AppColors.textPrimary),
                      onDeleted: () => setState(() {
                        _habitsByCategory[c.name] = [
                          for (final x in _habitsByCategory[c.name]!)
                            if (x != h) x,
                        ];
                      }),
                    ),
                ],
              ),
            const SizedBox(height: 16),
          ],
          ElevatedButton(
            onPressed:
                (_busy || _habitCategoriesLoading.isNotEmpty) ? null : _confirmHabitsAndClose,
            child: const Text('Build my pyramid'),
          ),
        ],
      ),
    );
  }

  Widget _buildTextInput() {
    return SafeArea(
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
                onSubmitted: (_) => _onSubmitText(),
              ),
            ),
            IconButton(
              onPressed: _busy ? null : _onSubmitText,
              icon: const Icon(Icons.arrow_upward, color: AppColors.brandGreen),
            ),
          ],
        ),
      ),
    );
  }

  void _onSubmitText() {
    if (_phase == _Phase.opening) {
      _sendOpeningReply();
    } else if (_phase == _Phase.essences) {
      _sendEssenceReply();
    }
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
