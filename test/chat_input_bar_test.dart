import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/widgets/chat_input_bar.dart';

/// D-101: the message composer shared by every Council chat screen — found
/// live, the single-line TextField this replaces had no maxLines, so long
/// messages scrolled off-screen instead of wrapping.
void main() {
  testWidgets('D-101: the field wraps rather than scrolling horizontally — '
      'multiline enabled, never a single fixed line', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ChatInputBar(controller: controller, enabled: true, onSubmit: () {}),
      ),
    ));
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.maxLines, greaterThan(1),
        reason: 'a bounded single line (maxLines: 1, the Flutter default) '
            'is exactly the defect this widget exists to fix');
    expect(field.minLines, 1);
    expect(field.keyboardType, TextInputType.multiline);
  });

  testWidgets('D-101: return inserts a newline rather than submitting — '
      'matching a messenger app\'s composer, not a single-line search box',
      (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ChatInputBar(controller: controller, enabled: true, onSubmit: () {}),
      ),
    ));
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.textInputAction, TextInputAction.newline);
  });

  testWidgets('D-101: submits via the send button and the tap handler',
      (tester) async {
    final controller = TextEditingController(text: 'hello');
    var submitted = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ChatInputBar(
          controller: controller,
          enabled: true,
          onSubmit: () => submitted = true,
        ),
      ),
    ));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.arrow_upward));
    expect(submitted, isTrue);
  });

  testWidgets('D-101: disabled state disables both the field and the send '
      'button — matches the existing busy-while-awaiting-reply gating',
      (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ChatInputBar(controller: controller, enabled: false, onSubmit: () {}),
      ),
    ));
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.enabled, isFalse);
    final button = tester.widget<IconButton>(find.byType(IconButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('D-101: the given hintText reaches the field — each caller '
      'keeps its own existing copy ("Say more…", "Say something…")',
      (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ChatInputBar(
          controller: controller,
          enabled: true,
          hintText: 'Say something…',
          onSubmit: () {},
        ),
      ),
    ));
    await tester.pump();

    expect(find.text('Say something…'), findsOneWidget);
  });
}
