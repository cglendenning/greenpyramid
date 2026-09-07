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
      contains("I'm not going to ask what you want to change. Tell me "
          "about a day recently that felt like it mattered."),
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
      'D-042/P-9: a pause follows every advisor turn in the opening round, '
      'and another follows the round before the categories phase replaces '
      'the transcript — regression test for owner feedback that four '
      'replies landing back to back "flew by"', () {
    final source = File('lib/screens/setup_screen.dart').readAsStringSync();
    final roundStart = source.indexOf('Future<void> _runOpeningRound()');
    expect(roundStart, greaterThan(-1));
    final roundEnd = source.indexOf('\n  Future<BoardSession> _runSetupTurn', roundStart);
    expect(roundEnd, greaterThan(roundStart));
    final delays = 'Future.delayed'.allMatches(source.substring(roundStart, roundEnd)).length;
    expect(delays, greaterThanOrEqualTo(2),
        reason: 'expected one pause per advisor turn plus one more before '
            'the categories transition');
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
}
