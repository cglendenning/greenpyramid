import 'dart:io';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// D-135: the persisted "just signed out" flag — the missing signal that
/// let main.dart's purely-local-data launch routing tell "an existing
/// anonymous pyramid owner" (D-132's home-screen gate is correct for
/// them) apart from "just signed out, hasn't chosen sign-in-or-rebuild
/// yet" (found live: the latter landed on the home screen showing the
/// wrong, setup-flavored account screen after being killed and
/// relaunched before making a choice).
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  AuthService authService() =>
      AuthService(auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u')));

  test('D-135: consumeJustSignedOutFlag returns false when sign-out never '
      'happened', () async {
    expect(await authService().consumeJustSignedOutFlag(), isFalse);
  });

  test('D-135: markJustSignedOut then consumeJustSignedOutFlag returns '
      'true exactly once — it only matters for the single next launch it '
      'is read on', () async {
    final auth = authService();
    await auth.markJustSignedOut();

    expect(await auth.consumeJustSignedOutFlag(), isTrue);
    expect(await auth.consumeJustSignedOutFlag(), isFalse,
        reason: 'consuming the flag must clear it, not just read it');
  });

  test('D-135: clearJustSignedOutFlag resolves it without needing a '
      'launch to consume it — called as soon as the user signs back in '
      'or rebuilds, in-session, so a much later unrelated relaunch is '
      'never incorrectly rerouted', () async {
    final auth = authService();
    await auth.markJustSignedOut();
    await auth.clearJustSignedOutFlag();

    expect(await auth.consumeJustSignedOutFlag(), isFalse);
  });

  test('D-135: main.dart checks the flag before the local-data check, '
      'and homescreen.dart\'s /setup route passes it through to '
      'WelcomeScreen as isResetup', () {
    // Structural, not a full widget pump: main() owns Firebase/
    // notification bootstrap end to end, which this suite doesn't mock.
    // Same source-text-assertion pattern schedule_habits_screen_test
    // .dart already uses for its D-128 group.
    final mainSource = File('lib/main.dart').readAsStringSync();
    expect(mainSource, contains('consumeJustSignedOutFlag()'));
    final flagCheck = mainSource.indexOf('justSignedOut');
    final localDataCheck = mainSource.indexOf('defaultCats == 6');
    expect(flagCheck, greaterThan(-1));
    expect(localDataCheck, greaterThan(flagCheck),
        reason: 'the sign-out flag must be checked before the local-data '
            'fallback, not after — both can\'t independently set '
            'routeToGo without one winning deterministically');

    final homescreenSource = File('lib/screens/homescreen.dart').readAsStringSync();
    expect(homescreenSource, contains('WelcomeScreen(isResetup: routeToGoIsResetup)'));
  });
}
