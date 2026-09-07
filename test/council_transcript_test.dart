import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/models/board_session.dart';
import 'package:life_ops/widgets/council_transcript.dart';

/// D-091: CouncilTranscript is the transcript rendering shared by every
/// screen the Council appears on — extracted so it's tested once rather
/// than duplicated (and drifting) across setup, category, and general
/// Council screens.
void main() {
  BoardMessage msg(String advisorKey, String text) => BoardMessage(
        advisorKey: advisorKey,
        text: text,
        timestamp: DateTime(2026, 1, 1),
      );

  testWidgets('D-042/D-027: an advisor message shows a portrait and the '
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

  testWidgets('onAcceptEssence set: the action appears under user messages '
      'and fires with that message\'s text', (tester) async {
    String? accepted;
    await tester.pumpWidget(MaterialApp(
      home: CouncilTranscript(
        messages: [msg('user', 'my body carries me')],
        onAcceptEssence: (text) => accepted = text,
      ),
    ));
    await tester.pump();

    expect(find.text('Use as my essence'), findsOneWidget);
    await tester.tap(find.text('Use as my essence'));
    expect(accepted, 'my body carries me');
  });
}
