import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D-067: Mira's opening line is fixed, hand-written copy — not generated.
/// Structural (source-text) test, matching this repo's convention for
/// literal required copy, since SetupScreen itself depends on live
/// singletons (SetupService.instance) the same way CouncilScreen does and
/// isn't widget-tested directly.
void main() {
  test('D-067: the opening line is the exact fixed copy, word for word', () {
    final source = File('lib/screens/setup_screen.dart').readAsStringSync();
    // The Dart source may wrap the literal across adjacent string
    // concatenation, so compare against source with line-break whitespace
    // collapsed, not the raw file text as one continuous line.
    final flattened = source.replaceAll(RegExp(r'"\s*\n\s*"'), '');
    expect(
      flattened,
      contains("Hi! Let me know what energizes you. What are things that "
          "you want more of in your life?"),
    );
  });

  test('D-042: setup carries one action, not a menu — a text field, no '
      'category picker widget', () {
    final source = File('lib/screens/setup_screen.dart').readAsStringSync();
    expect(source, isNot(contains('DropdownButton')));
    expect(source, isNot(contains('preset')));
  });

  test('D-045: no review, confirmation, or "does this look right?" step '
      'exists anywhere in the setup path', () {
    final source = File('lib/screens/setup_screen.dart').readAsStringSync();
    for (final phrase in ['Does this look right', 'Confirm your', 'Review your']) {
      expect(source, isNot(contains(phrase)),
          reason: '"$phrase" would be a review step, forbidden by D-045');
    }
    // Essences remain editable *later*, from the category detail screen
    // (D-047) — never inside setup itself.
    expect(source, isNot(contains('Edit your essence')));
  });

  test('D-053: none of the six duplicate habit-generator files survive', () {
    for (final n in [1, 2, 3, 4, 5, 6]) {
      expect(File('lib/screens/setup/tasks/cat${n}tasks.dart').existsSync(), isFalse);
    }
    expect(File('lib/screens/setup/tasks/taskdow.dart').existsSync(), isFalse);
    expect(Directory('lib/screens/setup/tasks').existsSync(), isFalse);
  });

  test('D-001: none of the eighteen old-flow setup screens survive', () {
    for (final n in List.generate(18, (i) => i + 1)) {
      expect(File('lib/screens/setup/setup$n.dart').existsSync(), isFalse);
    }
  });

  test(
      'D-032: _load() awaits sign-in before touching the Council session — '
      'regression test for the startup race that surfaced in production as '
      '"Could not start setup." main.dart fires anonymous sign-in unawaited '
      'so it never gates the first frame, which means this screen is the '
      'one place that must wait for it before any Firestore call, or a '
      'fresh device (no cached auth session) loses the race.', () {
    final source = File('lib/screens/setup_screen.dart').readAsStringSync();
    final loadStart = source.indexOf('Future<void> _load()');
    expect(loadStart, greaterThan(-1), reason: '_load() must exist');
    // Cheap method-body bound: the next top-level method signature after
    // _load(), consistent with this file's other structural checks.
    final loadEnd = source.indexOf('\n  void _scrollToBottom()', loadStart);
    expect(loadEnd, greaterThan(loadStart));
    final loadBody = source.substring(loadStart, loadEnd);

    final signInIndex = loadBody.indexOf('AuthService.instance.signInSilently()');
    final sessionIndex = loadBody.indexOf('_setup.startOrResumeSetup()');
    expect(signInIndex, greaterThan(-1),
        reason: '_load() must await AuthService.instance.signInSilently() '
            'before creating/resuming a Council session');
    expect(sessionIndex, greaterThan(-1));
    expect(signInIndex, lessThan(sessionIndex),
        reason: 'sign-in must be awaited strictly before the Council '
            'session call, not after or in parallel');
  });

  test(
      'D-042/D-067: Mira\'s opening line always renders in the openingRound '
      'phase, not only when a session is brand new — regression test for a '
      'defect found live: Mira\'s line is client-only copy, never persisted '
      'to Firestore, so a session resumed after an earlier launch failed '
      'mid-round (real messages exist, but none from Mira) rendered '
      'straight into an unframed transcript with no visible Council prompt '
      'at all.', () {
    final source = File('lib/screens/setup_screen.dart').readAsStringSync();
    final bodyStart = source.indexOf('Widget _buildBody()');
    expect(bodyStart, greaterThan(-1));
    final bodyEnd = source.indexOf('\n  Widget _buildTranscript', bodyStart);
    expect(bodyEnd, greaterThan(bodyStart));
    final body = source.substring(bodyStart, bodyEnd);

    final openingRoundCase = body.indexOf('case _Phase.openingRound:');
    expect(openingRoundCase, greaterThan(-1));
    final nextCase = body.indexOf('case _Phase.categories:', openingRoundCase);
    final openingRoundBranch = body.substring(openingRoundCase, nextCase);

    expect(openingRoundBranch, contains('_openingMessage'),
        reason: 'the openingRound phase must always include the synthetic '
            'Mira opening message, prepended to whatever the session '
            'actually has, so a resumed session is never shown without it');
  });

  test(
      'D-067/D-093: Mira\'s opening line always renders in the refining '
      'phase too — regression test for a defect found live: tapping "Not '
      'quite right" and returning to the chat silently dropped the very '
      'first message, because refining renders the conversation from its '
      'start but the opening line is never persisted to Firestore.', () {
    final source = File('lib/screens/setup_screen.dart').readAsStringSync();
    final bodyStart = source.indexOf('Widget _buildBody()');
    final bodyEnd = source.indexOf('\n  Widget _buildTranscript', bodyStart);
    final body = source.substring(bodyStart, bodyEnd);

    final refiningCase = body.indexOf('case _Phase.refining:');
    expect(refiningCase, greaterThan(-1));
    final nextCase = body.indexOf('case _Phase.essences:', refiningCase);
    final refiningBranch = body.substring(refiningCase, nextCase);

    expect(refiningBranch, contains('_openingMessage'),
        reason: 'the refining phase renders the whole conversation from '
            'the start, so it must prepend the synthetic Mira opening '
            'message the same way the openingRound phase does');
  });

  test(
      'D-090: a pause follows Mira\'s closing line before the categories '
      'phase replaces the transcript — same pacing discipline D-042 '
      'established for the old multi-advisor round, kept for the solo one',
      () {
    final source = File('lib/screens/setup_screen.dart').readAsStringSync();
    final roundStart = source.indexOf('Future<void> _runMiraTurn()');
    expect(roundStart, greaterThan(-1));
    final roundEnd = source.indexOf('\n  Future<BoardSession> _runSetupTurn', roundStart);
    expect(roundEnd, greaterThan(roundStart));
    final delays = 'Future.delayed'.allMatches(source.substring(roundStart, roundEnd)).length;
    expect(delays, greaterThanOrEqualTo(1),
        reason: 'expected a pause before the categories transition, so '
            'Mira\'s closing line is read, not instantly replaced');
  });

  test(
      'D-090: setup is a solo conversation with Mira — no rotation over the '
      'other three advisors happens inside the opening round anymore',
      () {
    final source = File('lib/screens/setup_screen.dart').readAsStringSync();
    final roundStart = source.indexOf('Future<void> _runMiraTurn()');
    expect(roundStart, greaterThan(-1));
    final roundEnd = source.indexOf('\n  Future<BoardSession> _runSetupTurn', roundStart);
    final round = source.substring(roundStart, roundEnd);
    expect(round, contains('runMiraSetupTurn'));
    expect(round, isNot(contains('rotationOrder')));
    expect(round, contains('readyToBuild'));
  });

  test(
      'D-051: the category card renders both the name and the description '
      '— regression test for owner feedback that names alone, with no '
      'resonant line under them, read as too bare', () {
    final source = File('lib/screens/setup_screen.dart').readAsStringSync();
    final buildCategoriesStart = source.indexOf('Widget _buildCategories()');
    expect(buildCategoriesStart, greaterThan(-1));
    final buildCategoriesEnd =
        source.indexOf('\n  Widget _buildEssences()', buildCategoriesStart);
    expect(buildCategoriesEnd, greaterThan(buildCategoriesStart));
    final body = source.substring(buildCategoriesStart, buildCategoriesEnd);
    expect(body, contains('c.name'));
    expect(body, contains('c.description'));
  });

  test(
      'D-051: moving a category into a full tier swaps positions rather '
      'than silently overwriting one — regression test for owner feedback '
      'from a real run: moving a Peak category into Foundational (already '
      'full at 3) left four categories at position 1 and none at position '
      '6, because the old fallback (orElse: openPositions.first) just '
      'dropped the moved category onto an already-taken position with no '
      'check.', () {
    final source = File('lib/screens/setup_screen.dart').readAsStringSync();

    // The exact defect: a naive "pick the first position in the target
    // tier" fallback with no regard for whether it's already occupied.
    expect(source, isNot(contains('orElse: () => openPositions.first')));
    expect(source, isNot(contains('orElse: () => tierPositions.first')));

    final moveStart = source.indexOf(
        'void _moveToTier(int index, List<int> tierPositions)');
    expect(moveStart, greaterThan(-1));
    final moveEnd = source.indexOf('\n  void _pickSwapTarget', moveStart);
    expect(moveEnd, greaterThan(moveStart));
    final moveBody = source.substring(moveStart, moveEnd);
    expect(moveBody, contains('_pickSwapTarget'),
        reason: 'a full tier must hand off to picking a swap partner, not '
            'silently assign a taken position');

    expect(source, contains('void _pickSwapTarget('));
    expect(source, contains('void _swapPositions('));
  });

  test(
      'D-051: every tier section shows its occupancy against a fixed '
      'capacity (e.g. "Foundational (3/3)") — regression test for owner '
      'feedback: "I don\'t understand how the organizational system '
      'works" after a move left a tier silently empty with no indication '
      'anything was wrong', () {
    final source = File('lib/screens/setup_screen.dart').readAsStringSync();
    final buildCategoriesStart = source.indexOf('Widget _buildCategories()');
    final buildCategoriesEnd =
        source.indexOf('\n  Widget _buildEssences()', buildCategoriesStart);
    final body = source.substring(buildCategoriesStart, buildCategoriesEnd);
    expect(body, contains(r'$label (${list.length}/$capacity)'));
    // A tier that has been emptied by a bad move must still render — it
    // is exactly the state that most needs to be visible, not hidden.
    expect(body, isNot(contains('if (list.isEmpty) return const SizedBox.shrink()')));
  });

  test(
      'D-093: the categories screen offers "Not quite right" alongside '
      '"This feels right" — the owner needed a way to keep working on the '
      'list, not just confirm or abandon it', () {
    final source = File('lib/screens/setup_screen.dart').readAsStringSync();
    final buildCategoriesStart = source.indexOf('Widget _buildCategories()');
    final buildCategoriesEnd =
        source.indexOf('\n  Widget _buildEssences()', buildCategoriesStart);
    final body = source.substring(buildCategoriesStart, buildCategoriesEnd);
    expect(body, contains('Not quite right'));
    expect(body, contains('_requestRefinement'));
    expect(body, contains('This feels right'));
  });

  test(
      'D-093: "Not quite right" re-enters the conversation and refines the '
      'existing categories — it must never discard them and start over',
      () {
    final source = File('lib/screens/setup_screen.dart').readAsStringSync();

    final requestStart = source.indexOf('Future<void> _requestRefinement()');
    expect(requestStart, greaterThan(-1));
    final requestEnd = source.indexOf('\n  Future<void> _runMiraTurn()', requestStart);
    expect(requestEnd, greaterThan(requestStart));
    final requestBody = source.substring(requestStart, requestEnd);
    expect(requestBody, contains('_Phase.refining'),
        reason: 'refinement must re-enter the chat, not stay on the '
            'categories screen or silently reset it');
    expect(requestBody, contains('appendAdvisorMessage'),
        reason: 'Mira must ask what felt off, not silently reopen an '
            'empty text field');

    // The re-derivation after a refinement round must be handed the prior
    // proposal, never called with nothing — that would be indistinguishable
    // from throwing the old categories away. D-118 extracted the actual
    // "existingCategories: priorCategories" call into a shared
    // _proceedFromReadyToBuild helper (also used by the fresh, non-
    // refining path) — this scan now covers both, since that's where the
    // call moved to.
    final turnStart = source.indexOf('Future<void> _runMiraTurn()');
    final turnEnd = source.indexOf('\n  Future<BoardSession> _runSetupTurn', turnStart);
    final turnBody = source.substring(turnStart, turnEnd);
    expect(turnBody, contains('existingCategories: _refinementContext'));
    expect(turnBody, contains('_proceedFromReadyToBuild(priorCategories)'));

    final helperStart = source.indexOf('Future<void> _proceedFromReadyToBuild(');
    final helperEnd = source.indexOf('\n  Future<void> _deriveOpeningVisionStatement', helperStart);
    final helperBody = source.substring(helperStart, helperEnd);
    expect(helperBody, contains('existingCategories: priorCategories'));
  });

  test(
      'D-093: the refining phase shows the text input and dispatches '
      'replies the same way the opening round does', () {
    final source = File('lib/screens/setup_screen.dart').readAsStringSync();
    final buildStart = source.indexOf('Widget build(BuildContext context)');
    final buildEnd = source.indexOf('\n  double _progressFor', buildStart);
    expect(source.substring(buildStart, buildEnd), contains('_phase == _Phase.refining'));

    final submitStart = source.indexOf('void _onSubmitText()');
    expect(submitStart, greaterThan(-1));
    final submitEnd = source.indexOf('\n}', submitStart);
    expect(source.substring(submitStart, submitEnd), contains('_phase == _Phase.refining'));
  });

  test(
      'D-009: _confirmCategories kicks off the first foundational '
      'category\'s essence question — regression test for a defect found '
      'live: only _acceptEssence (moving to the 2nd and 3rd category) ever '
      'called _askAboutCurrentFoundational, so the first category\'s '
      'screen opened onto whatever was already in the transcript from '
      'earlier in setup, never a question actually directed at it', () {
    final source = File('lib/screens/setup_screen.dart').readAsStringSync();
    final start = source.indexOf('Future<void> _confirmCategories()');
    expect(start, greaterThan(-1));
    final end = source.indexOf('\n  // ── Essences', start);
    expect(end, greaterThan(start));
    expect(source.substring(start, end), contains('_askAboutCurrentFoundational()'));
  });

  test(
      'D-009/D-105: the "save this" essence button only considers messages '
      'sent after this category\'s own question was asked — regression '
      'test for a defect found live: it only ever checked "does any user '
      'message exist," so the button appeared immediately using whatever '
      'the user last said earlier in setup, unrelated to this category. '
      'D-105 replaced the original timestamp-based check '
      '(_essenceQuestionAskedAt/isAfter) with message-index scoping '
      '(_essenceStepStartIndex/stepMessages), which also fixed a second '
      'live defect this same mechanism enables: the whole transcript view '
      'no longer leaks the entire prior session into this category\'s '
      'chat.', () {
    final source = File('lib/screens/setup_screen.dart').readAsStringSync();
    final start = source.indexOf('Widget _buildEssences()');
    expect(start, greaterThan(-1));
    final end = source.indexOf('\n  void _editHabit', start);
    expect(end, greaterThan(start));
    final body = source.substring(start, end);
    expect(body, contains('_essenceStepStartIndex'));
    expect(body, contains('stepMessages'));
    // D-005/P-12: "essence" is internal spec terminology — the owner
    // found it confusing in user-facing copy, alongside the whole screen
    // giving no indication of what was happening or why.
    expect(body, isNot(contains('Use as my essence')));
  });

  test(
      'D-052: habits can be edited and new ones added by hand, not only '
      'deleted — the auto-generated set is a starting point, never the '
      'only option', () {
    final source = File('lib/screens/setup_screen.dart').readAsStringSync();
    final buildHabitsStart = source.indexOf('Widget _buildHabits()');
    expect(buildHabitsStart, greaterThan(-1));
    final habitsBody = source.substring(buildHabitsStart);

    expect(habitsBody, contains('InputChip'),
        reason: 'a plain Chip only supports the delete (x) affordance — '
            'InputChip is what makes the habit itself tappable to edit');
    expect(habitsBody, contains('_editHabit'));
    expect(habitsBody, contains('_addHabit'));
    expect(source, contains('void _editHabit('));
    expect(source, contains('void _addHabit('));
  });

  test(
      'D-046: _confirmHabitsAndClose() catches its own failures instead of '
      'stranding the user on the closing screen forever — regression test '
      'for a defect found live: the whole method had no catch clause at '
      'all, only a finally, so any failure (most plausibly AiGuard\'s '
      'client-side daily budget, after repeated setup runs) left the '
      'screen permanently stuck on static "closing" text with no error '
      'shown and no way back.', () {
    final source = File('lib/screens/setup_screen.dart').readAsStringSync();
    final methodStart = source.indexOf('Future<void> _confirmHabitsAndClose()');
    expect(methodStart, greaterThan(-1));
    final methodEnd = source.indexOf('\n  @override', methodStart);
    expect(methodEnd, greaterThan(methodStart));
    final body = source.substring(methodStart, methodEnd);

    expect(body, contains('on AiBudgetException catch'),
        reason: 'closeSynthesis() calls AiGuard.instance.acquire() first, '
            'which throws exactly this when the local daily/per-minute '
            'budget is exhausted');
    expect(body, contains('_phase = _Phase.habits'),
        reason: 'on failure the screen must return to a state the user '
            'can retry from, not stay on the closing phase\'s dead end');
    expect(body, contains('catch (e, st)'),
        reason: 'a catch-all is required too — the point of this fix is '
            'that no failure here, known or not, can strand the user '
            'silently again');
  });
}
