import 'package:flutter/material.dart';
import 'package:life_ops/screens/homescreen.dart';
import 'package:life_ops/services/notification.dart';
import "package:timezone/data/latest.dart" as tz show initializeTimeZones;
import 'package:life_ops/services/db.dart';
import 'package:flutter/services.dart';
import 'package:app_install_date/app_install_date.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/widgets.dart';
import 'package:life_ops/widgets/pyramid_painting.dart';

// Forces the App Check *debug* provider even in a release/OTA build, so a
// sideloaded test build can authenticate with a registered debug token.
// App Attest works fine for ad-hoc iOS sideloads (it attests the device, not
// the install channel), but Play Integrity refuses to attest an Android APK
// that wasn't installed via Google Play (error: "App attestation failed"),
// so any Android build distributed via direct OTA (not the Play Store) needs
// this on. Default stays false so App Store / Play Store builds use the real
// attestation providers; set via `--dart-define=FORCE_APP_CHECK_DEBUG=true`
// for an OTA build instead of editing this file.
const bool kForceAppCheckDebug =
    bool.fromEnvironment('FORCE_APP_CHECK_DEBUG', defaultValue: false);

final GlobalKey<NavigatorState> navigatorKey =
    GlobalKey(debugLabel: "Main Navigator");

String routeToGo = '/';
String payload = '';
bool populateGap = true;
DateTime installDate = DateTime.now();
bool interventionShown = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Decode the pyramid's stone texture in the background so it's ready by
  // the time any pyramid paints (they fall back to a gradient until then).
  PyramidPainting.ensureStoneLoaded();

  try {
    installDate = await AppInstallDate().installDate;
  } catch (e, st) {
    debugPrint('Failed to load install date due to $e\n$st');
  }

  // Only allow portrait.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  LocalNotificationService().intialize();
  tz.initializeTimeZones();
  final dbHelper = DatabaseHelper.instance;
  dbHelper.populateQuote();
  dbHelper.populateCategory();
  // hack to prevent getCategory() from returning nothing on first
  // app launch.
  await Future.delayed(const Duration(seconds: 1));

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    // The native side can already have "[DEFAULT]" registered if the Dart
    // entrypoint runs more than once against the same engine (e.g. a hot
    // restart) — that's not a real failure, just a no-op.
    if (e.code != 'duplicate-app') {
      rethrow;
    }
    debugPrint('Firebase already initialized, continuing.');
  }

  // App Check gates the backend AI proxy: it proves requests come from the
  // genuine app binary, so the OpenAI key never has to live in the app.
  // Debug builds use the debug providers (register the printed debug token
  // in the Firebase console to test).
  try {
    final useDebugProvider = kDebugMode || kForceAppCheckDebug;
    await FirebaseAppCheck.instance.activate(
      appleProvider:
          useDebugProvider ? AppleProvider.debug : AppleProvider.appAttest,
      androidProvider: useDebugProvider
          ? AndroidProvider.debug
          : AndroidProvider.playIntegrity,
    );
  } catch (e, st) {
    debugPrint('App Check setup failed: $e\n$st');
  }


  int defaultCats = await dbHelper.queryLaunchSetup();

  if (defaultCats == 6) {
    routeToGo = '/setup';
  }
  runApp(HomeScreen());
}
