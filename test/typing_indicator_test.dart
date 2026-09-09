import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/widgets/typing_indicator.dart';

/// D-101: the three-pulsing-dots "typing" bubble shown while a Council
/// screen is genuinely awaiting an advisor's reply.
void main() {
  Widget wrap(Widget child, {bool disableAnimations = false}) => MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: MaterialApp(home: child),
      );

  testWidgets('D-101: renders exactly three dots and the given advisor\'s '
      'portrait', (tester) async {
    await tester.pumpWidget(wrap(const TypingIndicator(advisorKey: 'noa')));
    await tester.pump();

    expect(find.byType(CircleAvatar), findsOneWidget);
    // Three dots, each its own small circular Container inside the bubble
    // — excludes the CircleAvatar's own circular Container (32x32), which
    // matches the same shape/decoration predicate at a different size.
    final dotFinder = find.descendant(
      of: find.byType(TypingIndicator),
      matching: find.byWidgetPredicate((w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).shape == BoxShape.circle &&
          w.constraints?.maxWidth == 7),
    );
    expect(dotFinder, findsNWidgets(3));
  });

  testWidgets(
      'D-101: respects reduce-motion — no AnimatedBuilder in the tree, '
      'same discipline as SetupProgressIndicator (D-044): the static '
      'branch is taken, not merely a paused animation', (tester) async {
    await tester.pumpWidget(wrap(const TypingIndicator(advisorKey: 'eli'),
        disableAnimations: true));
    await tester.pump();

    expect(
      find.descendant(
        of: find.byType(TypingIndicator),
        matching: find.byType(AnimatedBuilder),
      ),
      findsNothing,
    );
  });
}
