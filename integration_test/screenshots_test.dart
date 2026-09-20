// Captures current-build App Store screenshots on a paired iOS device.
//
// Run with:
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/screenshots_test.dart -d <simulator-id>
//
// Seeds the demo dataset into the REAL tables (demo mode stays off, so the
// DemoModeBanner never renders), replicates main()'s startup minus the ads
// stack (so an interstitial can never appear mid-capture), then navigates
// via the app's navigatorKey and snapshots each screen.
import 'dart:async';
import 'dart:io';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:life_ops/services/db.dart';
import 'package:life_ops/services/dbtools.dart';
import 'package:life_ops/firebase_options.dart';
import 'package:life_ops/screens/homescreen.dart';
import 'package:life_ops/main.dart' show navigatorKey;
import 'package:life_ops/widgets/pyramid_painting.dart';
import 'package:life_ops/screens/visualizations.dart';
import 'package:timezone/data/latest.dart' as tz show initializeTimeZones;

// Screenshots are captured host-side: this prints a marker the host watcher
// greps for, then keeps pumping frames until the watcher acks that it took
// the shot (simulator apps share the host filesystem, so a stamp file works
// as the handshake). In-test takeScreenshot returned blank frames on this
// setup, so the host owns image capture.
const String _ackDir = '/private/tmp/gp-shot-acks';

Future<void> _shot(WidgetTester tester, String name) async {
  // Let synthetic gestures and platform touch indicators fully disappear
  // before the host captures the frame.
  await _settle(tester, total: const Duration(seconds: 2));
  final ack = File('$_ackDir/$name');
  // A leftover ack from an earlier run would let the test race past the
  // screen before the watcher captures it — clear it before signalling.
  if (ack.existsSync()) ack.deleteSync();
  debugPrint('MARKER_SHOT:$name');
  // The host-side ack directory is shared with iOS simulators/physical
  // runners, but an Android integration test sees `/private/tmp` inside the
  // emulator rather than on the host. The host watcher captures Android via
  // adb, so allow one settled frame instead of waiting for an unreachable
  // host file.
  if (Platform.isAndroid) {
    await _settle(tester, total: const Duration(seconds: 1));
    return;
  }
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (!ack.existsSync() && DateTime.now().isBefore(deadline)) {
    await _settle(tester, total: const Duration(milliseconds: 500));
  }
  if (!ack.existsSync()) {
    debugPrint('MARKER_SHOT_TIMEOUT:$name');
  }
}

Future<void> _settle(WidgetTester tester,
    {Duration total = const Duration(seconds: 4)}) async {
  // pumpAndSettle can spin forever on looping animations (the 3D pyramid),
  // so pump on a fixed clock instead.
  final Duration step = const Duration(milliseconds: 250);
  var elapsed = Duration.zero;
  while (elapsed < total) {
    await tester.pump(step);
    elapsed += step;
  }
}

Future<void> main() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture App Store screenshots', (tester) async {
    PyramidPainting.ensureStoneLoaded();
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    tz.initializeTimeZones();

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } on FirebaseException catch (e) {
      if (e.code != 'duplicate-app') rethrow;
    }

    // Simulators don't support DeviceCheck/App Attest; the debug provider
    // prints a token to the console that must be registered once in the
    // Firebase console for the AI proxy to accept calls from this run.
    try {
      await FirebaseAppCheck.instance.activate(
        appleProvider: AppleProvider.debug,
      );
    } catch (e) {
      debugPrint('App Check debug activation failed: $e');
    }

    // Seed baseline rows the way main() does, then overwrite with the demo
    // dataset. Demo mode is OFF, so populateDemoData targets the real
    // tables and no demo banner renders.
    final dbHelper = DatabaseHelper.instance;
    dbHelper.populateQuote();
    dbHelper.populateCategory();
    await Future.delayed(const Duration(seconds: 1));
    await DBTools().populateDemoData();

    await tester.pumpWidget(HomeScreen());
    await _settle(tester, total: const Duration(seconds: 6));
    await _shot(tester, '01-home-pyramid');

    final nav = navigatorKey.currentState!;

    nav.pushNamed('/morning');
    await _settle(tester);
    await _shot(tester, '02-morning-tasks');
    nav.pop();
    await _settle(tester, total: const Duration(seconds: 1));

    nav.pushNamed('/evening');
    await _settle(tester);
    await _shot(tester, '03-evening-tasks');
    nav.pop();
    await _settle(tester, total: const Duration(seconds: 1));

    nav.push(MaterialPageRoute(builder: (_) => const VisualizationsScreen()));
    await _settle(tester, total: const Duration(seconds: 6));
    await _shot(tester, '04-analysis-showing-up');
    for (final name in [
      '05-analysis-strength',
      '06-analysis-rhythm',
      '07-analysis-return',
      '08-analysis-care',
      '09-analysis-close',
    ]) {
      await tester.fling(find.byType(PageView), const Offset(-520, 0), 1200);
      await _settle(tester, total: const Duration(seconds: 2));
      await _shot(tester, name);
    }
    nav.pop();
    await _settle(tester, total: const Duration(seconds: 1));
  });
}
