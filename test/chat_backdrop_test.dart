import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/widgets/chat_backdrop.dart';

/// D-042/D-028: regression test for owner feedback that the Council chat
/// screens were "all dark and dreary" with no imagery or glow, unlike the
/// spinning pyramid on the home screen. ChatBackdrop owns no service
/// dependency, so — like WelcomeScreen — it's genuinely widget-testable.
void main() {
  testWidgets(
      'D-042: renders the background photograph behind the child, with '
      'the child still on top and interactive', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: ChatBackdrop(
        child: GestureDetector(
          onTap: () => tapped = true,
          child: const Text('content'),
        ),
      ),
    ));
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('content'), findsOneWidget);

    await tester.tap(find.text('content'));
    expect(tapped, isTrue);
  });
}
