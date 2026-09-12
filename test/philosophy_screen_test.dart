import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/screens/philosophy_screen.dart';

/// D-159: owner supplied the philosophy copy verbatim and asked for it to
/// be expanded into subsections "interwoven" with stock imagery, reachable
/// from the hamburger menu — "I want you to be an expert editor to create
/// a beautiful philosophy page ... The screen you generate will be static
/// text and this page will not need to leverage API calls for AI once it
/// is created." Purely static, so — like TermsScreen — it's directly
/// pumpWidget-testable with no Firebase/DB singleton involved.
void main() {
  testWidgets('D-159: renders the hero title and every subsection heading',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PhilosophyScreen()));
    await tester.pump();

    expect(find.text('Philosophy'), findsOneWidget);
    expect(find.text('What Truly Matters'), findsOneWidget);
    expect(find.text('The Shape of a Life'), findsOneWidget);
    expect(find.text('Not Every Habit Carries the Same Weight'),
        findsOneWidget);
    expect(find.text('Proof, Not Promises'), findsOneWidget);
    expect(find.text('The Infinite Game'), findsOneWidget);
    expect(find.text('When Life Gets Chaotic'), findsOneWidget);
  });

  testWidgets(
      'D-159: preserves the owner\'s own core ideas — six values, the '
      'three-tier hierarchy, unequal habit weighting, and the infinite '
      'game', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PhilosophyScreen()));
    await tester.pump();

    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join(' ');
    expect(texts, contains('foundational'));
    expect(texts, contains('essential'));
    expect(texts, contains('peak'));
    expect(texts, contains('Simon Sinek'));
    expect(texts, contains('infinite game'));
  });

  testWidgets('D-159: interweaves stock photography between subsections',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PhilosophyScreen()));
    await tester.pump();

    // The hero image plus five interstitial images placed between the
    // six subsections.
    expect(find.byType(Image), findsNWidgets(6));
  });

  testWidgets('D-159: has a back affordance and no other interactive chrome '
      '— purely static content, nothing to tap through', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PhilosophyScreen()));
    await tester.pump();

    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byType(ElevatedButton), findsNothing);
    expect(find.byType(TextButton), findsNothing);
  });
}
