import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/screens/welcome_screen.dart';

/// D-089: a single welcome screen precedes Mira's opening line, telling
/// the user a short guided conversation is coming before dropping them
/// into it — added after the owner found the previous behavior (straight
/// into a chat bubble with zero framing) jarring on a real first run.
///
/// D-136 (supersedes D-132/D-133/D-135): this screen no longer checks
/// auth state, a flag, or local data at all — it is now a pure, static
/// screen with exactly one appearance, reached only while genuinely
/// signed out (a fresh install or right after sign-out are, structurally,
/// the same "no session" state). Found live, after a real bug caused by
/// a persisted flag whose lifetime didn't match reality: "when you're
/// logged out you're in the logged out state, PERIOD." Owns no service
/// dependency at all now — even simpler to widget-test than before.
void main() {
  testWidgets('D-089/D-136: shows the welcome photograph, headline, a '
      'single "Begin" action, and the "Sign in" link — identically every '
      'time, whether a fresh install or right after sign-out',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WelcomeScreen()));
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Say what matters. We’ll build your life around it.'),
        findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Begin'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Already have an account? Sign in'),
        findsOneWidget);
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
      'is reached by pushing on top of another screen. Found live: '
      'tapping Setup by accident had no way out.', (tester) async {
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

  test('D-089/D-136: the "/setup" route (fresh install and a relaunch '
      'right after sign-out) goes through WelcomeScreen — but the '
      'hamburger menu\'s "Set up again" (an already signed-in user '
      'rebuilding their real pyramid) deliberately does not, since that '
      'is a different, more consequential action with its own explicit '
      'confirmation', () {
    final source = File('lib/screens/homescreen.dart').readAsStringSync();

    final setupRouteCase = source.indexOf("case '/setup':");
    expect(setupRouteCase, greaterThan(-1));
    final setupRouteEnd = source.indexOf('default:', setupRouteCase);
    expect(source.substring(setupRouteCase, setupRouteEnd), contains('WelcomeScreen'));

    final navigateToSetupStart = source.indexOf('Future<void> navigateToSetup(');
    expect(navigateToSetupStart, greaterThan(-1));
    final navigateToSetupEnd = source.indexOf('\n  }', navigateToSetupStart);
    final navigateToSetupBody =
        source.substring(navigateToSetupStart, navigateToSetupEnd);
    expect(navigateToSetupBody, isNot(contains('WelcomeScreen')));
    expect(navigateToSetupBody, contains('SetupScreen'));
    expect(navigateToSetupBody, contains("title: const Text('Set up again?'"));
  });

  group('D-141: the "Welcome back." sign-in screen shows a random '
      'inspiring tagline instead of a fixed, disliked phrase — owner: '
      '"\'Sign up with the account you set up before\' is not a phrase '
      'that I like."', () {
    test('exactly 20 taglines, each short, non-empty, and distinct', () {
      expect(welcomeBackTaglines.length, 20);
      expect(welcomeBackTaglines.toSet().length, 20,
          reason: 'no duplicates');
      for (final tagline in welcomeBackTaglines) {
        expect(tagline.trim(), tagline, reason: 'no stray whitespace');
        expect(tagline, isNotEmpty);
        expect(tagline.length, lessThanOrEqualTo(70),
            reason: 'short, per the owner\'s ask');
      }
    });

    test('the removed phrase is gone for good', () {
      expect(welcomeBackTaglines,
          isNot(contains('Sign in with the account you set up before.')));
    });

    test('_signIn wires the subhead from welcomeBackTaglines, chosen at '
        'random — not a single fixed line', () {
      final source = File('lib/screens/welcome_screen.dart').readAsStringSync();
      expect(source, contains('welcomeBackTaglines[Random().nextInt(welcomeBackTaglines.length)]'));
    });
  });
}
