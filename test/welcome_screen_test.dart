import 'dart:io';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/screens/welcome_screen.dart';
import 'package:life_ops/services/auth_service.dart';

/// D-089: a single welcome screen precedes Mira's opening line, telling
/// the user a short guided conversation is coming before dropping them
/// into it — added after the owner found the previous behavior (straight
/// into a chat bubble with zero framing) jarring on a real first run.
///
/// D-132/D-133: this screen now checks live auth state (whether "Sign in"
/// should show) via an injected AuthService, rather than trusting a
/// caller-supplied flag — found live while adding this: the real
/// singleton touches FirebaseAuth.instance, which would otherwise crash
/// this screen in a plain widget test (no Firebase.initializeApp() here),
/// breaking the genuine widget-testability D-089's original comment
/// prized. `anonymousAuth`/`realAuth` below stand in for "signed out" and
/// "signed in with a real account."
AuthService _anonymousAuth() => AuthService(
    auth: MockFirebaseAuth(
        signedIn: true, mockUser: MockUser(uid: 'anon', isAnonymous: true)));

AuthService _realAuth() => AuthService(
    auth: MockFirebaseAuth(
        signedIn: true, mockUser: MockUser(uid: 'real', isAnonymous: false)));

void main() {
  testWidgets('D-089: shows the welcome photograph, headline, and a '
      'single primary "Begin" action — no feature list, no carousel',
      (tester) async {
    await tester.pumpWidget(
        MaterialApp(home: WelcomeScreen(authService: _anonymousAuth())));
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

  testWidgets('D-132: offers a secondary "Sign in" link for an anonymous '
      'user (signed out) — a fresh install and post-sign-out are both '
      'anonymous, so both see it', (tester) async {
    await tester.pumpWidget(
        MaterialApp(home: WelcomeScreen(authService: _anonymousAuth())));
    await tester.pump();

    expect(find.widgetWithText(TextButton, 'Already have an account? Sign in'),
        findsOneWidget);
  });

  testWidgets('D-133: never offers "Sign in" for a user who is actually '
      'signed in with a real account — checked live '
      '(AuthService.isAnonymous), never from a caller-supplied flag that '
      'could go stale, per the owner\'s explicit "there always needs to be '
      'a check before displaying that link"', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: WelcomeScreen(isResetup: true, authService: _realAuth())));
    await tester.pump();

    expect(find.text('Already have an account? Sign in'), findsNothing);
  });

  testWidgets('D-133: the primary button reads "Set up again", not '
      '"Begin", when isResetup is true — reached via the hamburger menu '
      'or post-sign-out, never on a genuine fresh install', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: WelcomeScreen(isResetup: true, authService: _realAuth())));
    await tester.pump();

    expect(find.widgetWithText(ElevatedButton, 'Set up again'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Begin'), findsNothing);
  });

  testWidgets('D-089: does not explain the pyramid mechanic — no tier '
      'or category vocabulary appears on this screen', (tester) async {
    await tester.pumpWidget(
        MaterialApp(home: WelcomeScreen(authService: _anonymousAuth())));
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
    await tester.pumpWidget(
        MaterialApp(home: WelcomeScreen(authService: _anonymousAuth())));
    await tester.pump();

    expect(find.byIcon(Icons.arrow_back), findsNothing);
  });

  testWidgets('D-111: a back button appears, and works, when WelcomeScreen '
      'is reached by pushing on top of another screen — the Settings-menu '
      're-entry point. Found live: tapping Setup by accident had no way '
      'out.', (tester) async {
    final auth = _anonymousAuth();
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => WelcomeScreen(authService: auth))),
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
