import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/models/board_session.dart';
import 'package:life_ops/services/resonance_service.dart';

/// D-178: the category Council replied to a transcript one message stale and
/// ignored direct questions, and the essence control sat unexplained under
/// every user message.
///
/// The first two groups also carry D-100-AC-01 and D-100-AC-03, the general
/// rule D-178 turned out to be a violation of. D-100 was recorded as verified
/// on a manual review that did not reach this screen, so these are the first
/// automated checks that the rule holds on the category Council specifically.
void main() {
  final councilScreen = File('lib/screens/council_screen.dart').readAsStringSync();
  final transcript = File('lib/widgets/council_transcript.dart').readAsStringSync();

  group('D-178-AC-01 (also D-100-AC-01): the advisor answers what was just '
      'said', () {
    test('the turn is given the history including the new user message', () {
      // The defect was passing session.messages, captured before the append.
      expect(councilScreen, contains('appendUserMessage'));
      expect(councilScreen, contains("{'advisor': 'user', 'text': userMessage.text}"));
      expect(councilScreen, contains('conversationHistoryOverride: conversationHistory'));
    });

    test('general council, which was already correct, still composes it the '
        'same way — the fix matches the working sibling', () {
      final general =
          File('lib/screens/general_council_screen.dart').readAsStringSync();
      expect(general, contains("{'advisor': 'user', 'text': userMessage.text}"));
    });
  });

  group('D-178-AC-02 (also D-100-AC-03): a direct question goes to the '
      'advisor who just spoke', () {
    test('the screen routes through advisorKeyForUserMessage', () {
      expect(councilScreen, contains('session.advisorKeyForUserMessage(text)'));
      expect(councilScreen, isNot(contains('final next = session.nextAdvisorKey;')));
    });

    test('a question is routed back to the last advisor, not the rotation',
        () {
      final session = BoardSession(
        sessionId: 's1',
        type: BoardSessionType.category,
        categoryId: 1,
        rotationOrder: const ['mira', 'kenji', 'noa', 'eli'],
        sliderSettings: const {},
        messages: [
          BoardMessage(advisorKey: 'noa', text: 'How does it feel?', timestamp: DateTime(2026)),
          BoardMessage(advisorKey: 'user', text: 'Like losing my ego.', timestamp: DateTime(2026)),
          BoardMessage(advisorKey: 'kenji', text: 'Quiet. Usually quiet.', timestamp: DateTime(2026)),
        ],
        createdAt: DateTime(2026),
        lastUpdatedAt: DateTime(2026),
        isComplete: false,
        totalInputTokens: 0,
        totalOutputTokens: 0,
      );

      // The reported case: "What?!" was answered by the next advisor in
      // rotation rather than by Kenji, who had just spoken.
      expect(session.advisorKeyForUserMessage('What?!'), 'kenji');
      // A statement still follows the ordinary rotation.
      expect(session.advisorKeyForUserMessage('It feels like relief.'),
          session.nextAdvisorKey);
    });
  });

  group('D-178-AC-03/D-178-AC-04/D-178-AC-05: the essence is chosen deliberately', () {
    test('no per-message essence control remains in the transcript', () {
      expect(transcript, isNot(contains('Use as my essence')));
      expect(transcript, isNot(contains('onAcceptEssence')));
    });

    test('a single labelled action opens an explained sheet', () {
      expect(councilScreen, contains("Text('Set essence'"));
      expect(councilScreen, contains('_openEssenceSheet'));
      expect(councilScreen, contains('class _EssenceSheet'));
      // It must say what an essence is and what accepting costs.
      expect(councilScreen, contains('An essence is your own words for why'));
      expect(councilScreen,
          contains('Saving your essence ends this conversation'));
    });

    test('only messages that could actually become an essence are offered',
        () {
      expect(councilScreen, contains('.where(ResonanceService.qualifies)'));
      // The exact replies from the reported session: neither can qualify, so
      // neither should ever have carried the control.
      expect(ResonanceService.qualifies('What?!'), isFalse);
      expect(
          ResonanceService.qualifies('Hi. No, his answer made no sense to me.'),
          isFalse);
      expect(
          ResonanceService.qualifies(
              'What emerges is peace, tranquility and a sensation of being '
              'settled. Like I do not need to be on guard anymore.'),
          isTrue);
    });
  });
}
