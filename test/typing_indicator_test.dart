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

  testWidgets(
      'D-107: the dots actually animate in the normal (motion-enabled) '
      'case — regression test for a defect found live: '
      '"reduceMotion == _reduceMotion" as the sole didChangeDependencies '
      'guard meant the very first call — the overwhelmingly common case, '
      'where the real value is also false — short-circuited before ever '
      'calling _controller.repeat(), so the dots rendered but were '
      'frozen at the controller\'s initial value forever, in every real '
      'build that ever shipped', (tester) async {
    await tester.pumpWidget(wrap(const TypingIndicator(advisorKey: 'mira')));
    await tester.pump();

    List<double> opacities() => tester
        .widgetList<Opacity>(find.descendant(
            of: find.byType(TypingIndicator), matching: find.byType(Opacity)))
        .map((o) => o.opacity)
        .toList();

    final before = opacities();
    await tester.pump(const Duration(milliseconds: 400));
    final after = opacities();

    expect(after, isNot(equals(before)),
        reason: 'the animation must actually be running, not frozen at '
            'its initial value — this is exactly what shipped broken');
  });
}
