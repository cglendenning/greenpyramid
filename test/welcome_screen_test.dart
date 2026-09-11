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
      'single primary "Begin" action — no feature list, no carousel',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WelcomeScreen()));
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Say what matters. We’ll build your life around it.'),
        findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Begin'), findsOneWidget);
    // One *primary* action only (P-14) — but D-132 deliberately adds a
    // secondary "Sign in" link below it for someone who already has an
    // account, mirroring goal-executor's own first-screen pattern.
    expect(find.byType(ElevatedButton), findsOneWidget);
  });

  testWidgets('D-132: offers a secondary "Sign in" link for someone who '
      'already has an account — Start fresh stays hidden by default, since '
      'a genuine fresh install has nothing to "start fresh" from', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WelcomeScreen()));
    await tester.pump();

    expect(find.widgetWithText(TextButton, 'Already have an account? Sign in'),
        findsOneWidget);
    expect(find.text('Start fresh instead'), findsNothing);
  });

  testWidgets('D-132: shows "Start fresh instead" only when reached via '
      'sign-out (showStartFreshOption: true) — never on a genuine fresh '
      'install, where "Begin" already starts from empty', (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: WelcomeScreen(showStartFreshOption: true)));
    await tester.pump();

    expect(find.text('Start fresh instead'), findsOneWidget);
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

  testWidgets('D-111: no back button when there is nowhere to go back to '
      '— the fresh-install "/setup" route, where WelcomeScreen is the '
      'very first screen', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WelcomeScreen()));
    await tester.pump();

    expect(find.byIcon(Icons.arrow_back), findsNothing);
  });

  testWidgets('D-111: a back button appears, and works, when WelcomeScreen '
      'is reached by pushing on top of another screen — the Settings-menu '
      're-entry point. Found live: tapping Setup by accident had no way '
      'out.', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const WelcomeScreen())),
              child: const Text('Open Setup'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Open Setup'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('Open Setup'), findsOneWidget,
        reason: 'popping the back button must return to the previous screen');
    expect(find.byType(WelcomeScreen), findsNothing);
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
