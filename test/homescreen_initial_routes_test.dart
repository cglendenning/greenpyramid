import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D-138: structural regression test, not a full widget pump —
/// HomeScreenWidget's initState() owns Firebase/DB/notification
/// bootstrap end to end, which this suite doesn't mock. Same
/// source-text-assertion pattern main_stale_session_test.dart already
/// uses for D-137.
///
/// Found live: a genuine fresh install correctly showed WelcomeScreen
/// ('/setup') first, then ~2-3 seconds later AccountCreationScreen
/// popped up on top of it. Root cause, confirmed against the Flutter
/// SDK source (navigator.dart's defaultGenerateInitialRoutes): with
/// only `initialRoute`/`onGenerateRoute` set, Flutter's default initial
/// route generation unconditionally mounts '/' (HomeScreenWidget, via
/// `home`) underneath whatever `initialRoute` actually points to. The
/// buried HomeScreenWidget still ran its own D-132 _enforceRealAccount
/// gate, which popped AccountCreationScreen once its signInSilently()
/// call resolved.
void main() {
  test('D-138: launching straight into /setup must not also silently '
      'mount HomeScreenWidget underneath it', () {
    final source = File('lib/screens/homescreen.dart').readAsStringSync();

    final onGenerateInitialRoutes = source.indexOf('onGenerateInitialRoutes:');
    expect(onGenerateInitialRoutes, greaterThan(-1),
        reason: 'HomeScreen must override onGenerateInitialRoutes — '
            "otherwise Flutter's Navigator.defaultGenerateInitialRoutes "
            "unconditionally mounts '/' underneath any other initialRoute");

    final initialRoute = source.indexOf('initialRoute: routeToGo');
    expect(initialRoute, greaterThan(-1));
    expect(onGenerateInitialRoutes, greaterThan(initialRoute));

    final body = source.substring(
        onGenerateInitialRoutes, onGenerateInitialRoutes + 700);

    // The override must actually generate exactly one route per call —
    // never delegate back to the buggy default.
    expect(body, isNot(contains('return Navigator.defaultGenerateInitialRoutes')));
    expect(body, contains("if (initialRouteName == '/')"));
    expect(body, contains('_generateRoute(RouteSettings(name: initialRouteName))'));
  });
}
