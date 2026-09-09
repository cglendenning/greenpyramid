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

  test('D-106: essence-deepening always speaks as Mira, never rotating '
      'through the other three advisors — the owner\'s explicit call: '
      '"multiple advisors should only be in the talk to the council '
      'section... that can be a bit confusing during setup too"', () {
    final start = source.indexOf('Future<void> _askAboutCurrentFoundational()');
    expect(start, greaterThan(-1));
    final end = source.indexOf('\n  }', start);
    final body = source.substring(start, end);

    expect(body, contains("advisorKey: 'mira'"));
    expect(body, isNot(contains('session.rotationOrder[_essenceIndex')),
        reason: 'the old per-category rotation must not reappear');
  });

  test('D-106: the essence-phase typing indicator always shows Mira, '
      'matching the advisor that will actually reply', () {
    final start = source.indexOf('Widget _buildEssences()');
    final end = source.indexOf('\n  void _editHabit', start);
    final body = source.substring(start, end);

    expect(body, contains("typingAdvisorKey: _busy ? 'mira' : null"));
  });
}
