import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D-102/D-103/D-104/D-105/D-106: structural checks on setup_screen.dart's
/// phase flow between confirming categories and reaching the completion
/// screen — SetupScreen owns live service singletons (SetupService.instance)
/// the same way CouncilScreen does and isn't widget-tested directly, matching
/// this repo's convention (setup_screen_opening_line_test.dart).
void main() {
  final source = File('lib/screens/setup_screen.dart').readAsStringSync();

  test('D-102: confirming categories stops on a handoff screen rather '
      'than dropping straight back into the essence-deepening chat — '
      'found live: "This feels right" leading straight into an '
      'identical-looking chat read as being "tossed back into chat"', () {
    final start = source.indexOf('Future<void> _confirmCategories()');
    expect(start, greaterThan(-1));
    final end = source.indexOf('\n  }', start);
    final body = source.substring(start, end);

    expect(body, contains('_Phase.essenceIntro'));
    expect(body, isNot(contains('_askAboutCurrentFoundational()')),
        reason: 'the essence conversation itself must not start until the '
            'handoff screen is tapped through, not the instant categories '
            'commit');
  });

  test('D-102: the handoff screen\'s own action is what actually starts '
      'essence-deepening', () {
    final start = source.indexOf('Future<void> _beginEssenceDeepening()');
    expect(start, greaterThan(-1));
    final end = source.indexOf('\n  }', start);
    final body = source.substring(start, end);

    expect(body, contains('_Phase.essences'));
    expect(body, contains('_askAboutCurrentFoundational()'));
  });

  test('D-102: the handoff screen uses the shared OnboardingStyles type '
      'scale, matching the welcome screen\'s "vibe" — not a bespoke text '
      'style reintroducing visual drift', () {
    final start = source.indexOf('Widget _buildEssenceIntro()');
    expect(start, greaterThan(-1));
    final end = source.indexOf('\n  Widget _buildCategories', start);
    final body = source.substring(start, end);

    expect(body, contains('OnboardingStyles.headline'));
    expect(body, contains('OnboardingStyles.subhead'));
    expect(body, contains('OnboardingStyles.primaryButton'));
    expect(body, contains('_beginEssenceDeepening'));
  });

  test('D-103: habit proposals reserve at least one slot per remaining '
      'category and never request more than 3, keeping the pyramid\'s '
      'total at or under 10 across all six categories', () {
    final start = source.indexOf('Future<void> _loadAllHabits()');
    expect(start, greaterThan(-1));
    final end = source.indexOf('\n  }', start);
    final body = source.substring(start, end);

    expect(body, contains('_maxTotalHabits'));
    expect(body, contains('remainingAfterThis'));
    expect(body, contains('.clamp(1, 3)'));
    expect(body, contains('maxAllowed: maxAllowed'));
  });

  test('D-103: the total habit ceiling is exactly 10, the owner\'s '
      'explicit number', () {
    expect(source, contains('_maxTotalHabits = 10'));
  });

  test('D-104: the pre-completion habit screen states plainly that tasks '
      'are daily by default and editable after setup — found live, '
      'neither fact was ever said in words, only implied by the chips\' '
      'own affordances', () {
    final start = source.indexOf('Widget _buildHabits()');
    expect(start, greaterThan(-1));
    final end = source.indexOf('\n  Widget _buildTextInput', start);
    expect(end, greaterThan(start));
    final body = source.substring(start, end);

    expect(body, contains('daily'));
    expect(body, contains('anytime after setup'));
  });

  test('D-105: the essence-deepening transcript is scoped to this '
      'category\'s own exchange, not the whole session — found live via '
      'direct Firestore inspection: the full session included the entire '
      'opening conversation (Mira\'s own readyToBuild closing line among '
      'it) sitting directly above the category\'s actual question', () {
    final start = source.indexOf('Widget _buildEssences()');
    expect(start, greaterThan(-1));
    final end = source.indexOf('\n  void _editHabit', start);
    expect(end, greaterThan(start));
    final body = source.substring(start, end);

    expect(body, contains('_essenceStepStartIndex'));
    expect(body, contains('stepMessages'));
    expect(body, isNot(contains('_session?.messages ?? const []')),
        reason: 'the old unscoped whole-session render must not reappear');
  });

  test('D-105: the "save this" button is gated on the same resonance bar '
      '_acceptEssence itself enforces, not merely "any reply exists" — '
      'found live: a short filler reply showed the button immediately, '
      'and tapping it just bounced with a snackbar since the answer was '
      'never actually going to qualify', () {
    final start = source.indexOf('Widget _buildEssences()');
    final end = source.indexOf('\n  void _editHabit', start);
    final body = source.substring(start, end);

    expect(body, contains('ResonanceService.qualifies(m.text)'));
  });

  test('D-105: sending an essence reply scrolls the new message (and, '
      'once it qualifies, the button) into view rather than leaving it '
      'below the fold', () {
    final start = source.indexOf('Future<void> _sendEssenceReply()');
    expect(start, greaterThan(-1));
    final end = source.indexOf('\n  }', start);
    final body = source.substring(start, end);

    expect(body, contains('_scrollToBottom()'));
  });

  test('D-106: the opening conversation (openingRound/refining) still '
      'always speaks as Mira — D-109 only reverses D-106 for '
      'essence-deepening specifically, not the opening conversation', () {
    final start = source.indexOf('Future<void> _sendOpeningReply()');
    expect(start, greaterThan(-1));
    final end = source.indexOf('\n  }', start);
    expect(source.substring(start, end), contains('_runMiraTurn()'));
  });

  test('D-109: essence-deepening rotates through session.rotationOrder — '
      'one advisor per category, varying across the three — reversing '
      'D-106\'s "always Mira" for this specific case. The owner\'s '
      'follow-up call, once D-105/D-108 fixed the actual context-leak '
      'that made advisor variety look disjointed: "I would like to '
      'randomize the council members that answer the various '
      'questions... it gives this idea that there\'s different '
      'personalities within the application"', () {
    final start = source.indexOf('Future<void> _askAboutCurrentFoundational()');
    expect(start, greaterThan(-1));
    final end = source.indexOf('\n  }', start);
    final body = source.substring(start, end);

    expect(body, contains('session.rotationOrder[_essenceIndex'));
    expect(body, isNot(contains("advisorKey: 'mira'")),
        reason: 'D-106\'s hardcoded Mira must not reappear here');
  });

  test('D-109: the essence-phase typing indicator matches the rotation '
      'pick, not a hardcoded Mira', () {
    final start = source.indexOf('Widget _buildEssences()');
    final end = source.indexOf('\n  void _editHabit', start);
    final body = source.substring(start, end);

    expect(body, contains('_session!.rotationOrder[_essenceIndex'));
  });

  test('D-108: essence-deepening\'s kickoff call passes an explicit '
      'empty conversationHistoryOverride — found live: without this, '
      'a category\'s kickoff call inherited the whole session\'s '
      'history (D-043, one continuous session), so "respond to what '
      'was just said" reacted to the previous category\'s leftover '
      'closing message instead of asking a fresh, directed question '
      'about the new category', () {
    final start = source.indexOf('Future<void> _askAboutCurrentFoundational()');
    final end = source.indexOf('\n  }', start);
    final body = source.substring(start, end);

    expect(body, contains('conversationHistoryOverride: const []'));
  });

  test('D-110: a fixed acknowledgment is appended once a reply qualifies, '
      'before the "save this" button — found live: the button appearing '
      'with no acknowledgment at all was a hard, jarring cut straight '
      'from "you typed something" to "here\'s a button"', () {
    final start = source.indexOf('Future<void> _sendEssenceReply()');
    expect(start, greaterThan(-1));
    final end = source.indexOf('\n  }', start);
    final body = source.substring(start, end);

    expect(body, contains('_essenceAcknowledged'));
    expect(body, contains('ResonanceService.qualifies(text)'));
    expect(body, contains('appendAdvisorMessage('));
  });

  test('D-110: the acknowledgment fires at most once per category — reset '
      'alongside _essenceStepStartIndex, which is captured fresh at the '
      'start of every category\'s own exchange', () {
    final start = source.indexOf('Future<void> _askAboutCurrentFoundational()');
    final end = source.indexOf('\n  }', start);
    final body = source.substring(start, end);

    expect(body, contains('_essenceAcknowledged = false'));
  });

  test('D-110: the acknowledgment text is fixed, zero-cost copy — no new '
      'model call for a purely transitional line', () {
    expect(source, contains('_essenceAcknowledgment ='));
  });
}
