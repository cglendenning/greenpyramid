import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/screens/push_permission_screen.dart';
import 'package:life_ops/screens/trial_disclosure_screen.dart';
import 'package:life_ops/screens/welcome_screen.dart';
import 'package:life_ops/services/auth_service.dart';
import 'package:life_ops/widgets/crossfading_stock_images.dart';

/// D-099: welcome, trial-disclosure, and push-permission screens share one
/// rotating-photograph background and Raleway type scale (OnboardingBackdrop
/// / OnboardingStyles) rather than each screen carrying its own
/// reimplementation of the look the owner singled out as exactly right.
void main() {
  testWidgets('D-099: TrialDisclosureScreen renders the shared rotating '
      'backdrop and preserves its existing copy', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: TrialDisclosureScreen(onDone: () {}),
    ));
    await tester.pump();

    expect(find.byType(CrossfadingStockImages), findsOneWidget);
    expect(find.text('You have 3 days of full access.'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Got it'), findsOneWidget);
  });

  testWidgets('D-099: TrialDisclosureScreen keeps the lapsed-entitlement '
      'copy unchanged', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: TrialDisclosureScreen(onDone: () {}, entitlement: 'lapsed'),
    ));
    await tester.pump();

    expect(find.text('Your pyramid is ready.'), findsOneWidget);
  });

  testWidgets('D-099/D-065: PushPermissionScreen renders the shared '
      'rotating backdrop and its copy is unambiguous about requesting '
      'push notification permission', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: PushPermissionScreen(onDone: () {}),
    ));
    await tester.pump();

    expect(find.byType(CrossfadingStockImages), findsOneWidget);

    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join(' ')
        .toLowerCase();
    expect(texts, contains('notification'));
    expect(find.widgetWithText(ElevatedButton, 'Allow notifications'),
        findsOneWidget);
    // D-065: one action only, still — no skip path was introduced.
    expect(find.byType(ElevatedButton), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('D-099: WelcomeScreen still renders the shared backdrop after '
      'being refactored onto OnboardingBackdrop', (tester) async {
    final authService = AuthService(
        auth: MockFirebaseAuth(
            signedIn: true, mockUser: MockUser(uid: 'anon', isAnonymous: true)));
    await tester.pumpWidget(
        MaterialApp(home: WelcomeScreen(authService: authService)));
    await tester.pump();

    expect(find.byType(CrossfadingStockImages), findsOneWidget);
  });
}
