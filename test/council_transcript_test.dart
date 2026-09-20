import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/models/board_session.dart';
import 'package:life_ops/widgets/council_transcript.dart';
import 'package:life_ops/widgets/typing_indicator.dart';

/// D-075: CouncilTranscript is the transcript rendering shared by every
/// screen the Council appears on — extracted so it's tested once rather
/// than duplicated (and drifting) across setup, category, and general
/// Council screens.
void main() {
  BoardMessage msg(String advisorKey, String text) => BoardMessage(
        advisorKey: advisorKey,
        text: text,
        timestamp: DateTime(2026, 1, 1),
      );

  testWidgets('D-031/D-022: an advisor message shows a portrait and the '
      'advisor\'s name; a user message shows neither', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: CouncilTranscript(
          messages: [msg('mira', 'hello there'), msg('user', 'hi Mira')]),
    ));
    await tester.pump();

    expect(find.byType(CircleAvatar), findsOneWidget);
    expect(find.text('Mira'), findsOneWidget);
    expect(find.text('hello there'), findsOneWidget);
    expect(find.text('hi Mira'), findsOneWidget);
  });

  testWidgets('onAcceptEssence null (the default): no "Use as my essence" '
      'action appears anywhere, even under a user message', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: CouncilTranscript(messages: [msg('user', 'my body carries me')]),
    ));
    await tester.pump();

    expect(find.text('Use as my essence'), findsNothing);
  });

  // D-178-AC-03: the per-message essence action was removed entirely. It read as
  // an annotation on the user's own words rather than a deliberate,
  // conversation-ending choice, and it rendered on messages that could never
  // qualify. Choosing an essence is now one explained action on the category
  // Council screen, so the transcript must never offer it.
  testWidgets('the transcript never renders an essence action, whatever it '
      'is given', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: CouncilTranscript(messages: [
        msg('user', 'my body carries me and I want to treat it that way'),
        msg('mira', 'say more about that'),
      ]),
    ));
    await tester.pump();

    expect(find.text('Use as my essence'), findsNothing);
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('D-083: typingAdvisorKey null (the default): no typing '
      'indicator appears, even with messages present', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: CouncilTranscript(messages: [msg('mira', 'hello there')]),
    ));
    await tester.pump();

    expect(find.byType(TypingIndicator), findsNothing);
  });

  testWidgets('D-083: typingAdvisorKey set: a TypingIndicator renders as '
      'the trailing item, after every real message — the screen never '
      'goes visually dead while waiting for a reply', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: CouncilTranscript(
        messages: [msg('user', 'hi'), msg('mira', 'hello there')],
        typingAdvisorKey: 'kenji',
      ),
    ));
    await tester.pump();

    expect(find.byType(TypingIndicator), findsOneWidget);
    final indicator =
        tester.widget<TypingIndicator>(find.byType(TypingIndicator));
    expect(indicator.advisorKey, 'kenji');
  });

  group('D-120: long-press a Council response to copy it — found live: '
      '"enable the ability to long press one of the responses from the '
      'council and copy it - again, goal-executor (Kansei) should have '
      'that"', () {
    testWidgets('long-pressing an advisor bubble copies its text and shows '
        'a confirmation snackbar', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CouncilTranscript(messages: [msg('mira', 'hello there')]),
        ),
      ));
      await tester.pump();

      await tester.longPress(find.text('hello there'));
      await tester.pump();

      expect(copied, 'hello there');
      expect(find.text('Copied'), findsOneWidget);
    });

    testWidgets('long-pressing a user bubble copies its text too',
        (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CouncilTranscript(messages: [msg('user', 'my body carries me')]),
        ),
      ));
      await tester.pump();

      await tester.longPress(find.text('my body carries me'));
      await tester.pump();

      expect(copied, 'my body carries me');
      expect(find.text('Copied'), findsOneWidget);
    });
  });
}
