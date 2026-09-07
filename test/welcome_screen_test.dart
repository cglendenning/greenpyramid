import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/screens/welcome_screen.dart';

/// D-089: a single welcome screen precedes Mira's opening line, telling
/// the user a short guided conversation is coming before dropping them
/// into it — added after the owner found the previous behavior (straight
/// into a chat bubble with zero framing) jarring on a real first run.
///
/// Unlike SetupScreen, WelcomeScreen owns no service singleton, so it can
/// be genuinely widget-tested rather than only source-checked.
void main() {
  testWidgets('D-089: shows the welcome photograph, headline, and a '
      'single "Begin" action — no feature list, no carousel', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WelcomeScreen()));
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Say what matters.\nWe’ll build around it.'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Begin'), findsOneWidget);
    // One action only (P-14): no other buttons anywhere on the screen.
    expect(find.byType(ElevatedButton), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('D-089: does not explain the pyramid mechanic — no tier '
      'or category vocabulary appears on this screen', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WelcomeScreen()));
    await tester.pump();

    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join(' ')
        .toLowerCase();
    for (final forbidden in ['foundational', 'essential', 'peak', 'tier']) {
      expect(texts, isNot(contains(forbidden)),
          reason: '"$forbidden" would be explaining the mechanic, which '
              'D-042/P-15 reserve for nowhere on the first screen');
    }
  });

  test('D-089: both routes into setup (a fresh install\'s "/setup" route '
      'and the Settings-menu re-entry point) go through WelcomeScreen, '
      'not straight to SetupScreen', () {
    final source = File('lib/screens/homescreen.dart').readAsStringSync();

    final setupRouteCase = source.indexOf("case '/setup':");
    expect(setupRouteCase, greaterThan(-1));
    final setupRouteEnd = source.indexOf('\n', source.indexOf('MaterialPageRoute', setupRouteCase));
    expect(source.substring(setupRouteCase, setupRouteEnd), contains('WelcomeScreen'));

    final navigateToSetupStart = source.indexOf('void navigateToSetup(');
    expect(navigateToSetupStart, greaterThan(-1));
    final navigateToSetupEnd = source.indexOf('\n  }', navigateToSetupStart);
    expect(source.substring(navigateToSetupStart, navigateToSetupEnd),
        contains('WelcomeScreen'));
  });
}
