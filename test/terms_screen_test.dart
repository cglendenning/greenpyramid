import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/screens/terms_screen.dart';

/// D-149: found live — "ensure that you have a terms and conditions link
/// that indicates that this is not medical advice and I think you already
/// have this for Kansei (goal-executor) so if any of the copy is relatable
/// to what Green Pyramid does then copy it verbatim." The disclaimer and
/// boilerplate legal sections are ported from goal-executor's own
/// terms_screen.dart, reworded for Green Pyramid's actual domain (the
/// Council of Advisors, categories/habits, RevenueCat subscriptions)
/// rather than Kansei's goal-setting language.
void main() {
  testWidgets('shows the not-medical-advice disclaimer prominently',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TermsScreen()));
    await tester.pump();

    expect(find.text('NOT MEDICAL OR PROFESSIONAL ADVICE'), findsOneWidget);
    expect(find.textContaining('does not provide medical, psychological'),
        findsOneWidget);
  });

  testWidgets('is reworded for Green Pyramid, not left with Kansei\'s own '
      'copy', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TermsScreen()));
    await tester.pump();

    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join(' ');
    expect(texts, contains('Green Pyramid'));
    expect(texts, isNot(contains('Kansei')));
    expect(texts, contains('Council of Advisors'));
  });

  testWidgets('mentions AI-generated content and subscription billing',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TermsScreen()));
    await tester.pump();

    expect(find.textContaining('AI-GENERATED CONTENT'), findsOneWidget);
    expect(find.textContaining('SUBSCRIPTIONS, BILLING'), findsOneWidget);
  });
}
