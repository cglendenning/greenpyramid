import 'dart:async';

import 'package:flutter/material.dart';
import 'package:life_ops/screens/homescreen.dart';
import 'package:life_ops/screens/database_recovery_screen.dart';
import 'package:life_ops/services/notification.dart';
import "package:timezone/data/latest.dart" as tz show initializeTimeZones;
import 'package:life_ops/services/db.dart';
import 'package:life_ops/services/auth_service.dart';
import 'package:life_ops/services/sync_service.dart';
import 'package:flutter/services.dart';
import 'package:app_install_date/app_install_date.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
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


  // D-086: migration is best-effort. If the database cannot be opened or
  // migrated, tell the user plainly rather than crashing on a null database
  // or wiping their data without saying so.
  int defaultCats;
  try {
    defaultCats = await dbHelper.queryLaunchSetup();
  } catch (e, st) {
    debugPrint('Database unavailable, showing recovery screen: $e\n$st');
    runApp(const DatabaseRecoveryScreen());
    return;
  }

  if (defaultCats == 6) {
    routeToGo = '/setup';
  }
  runApp(HomeScreen());

  // D-032/D-034: silent account bootstrap, kicked off after the first frame
  // so it never gates app startup or changes the setup step count (D-007).
  // Not awaited — a failure here is retried on the next launch, never shown
  // to the user (D-032 acceptance criteria).
  unawaited(_bootstrapAccountSync(setupComplete: defaultCats != 6));
}

/// D-032: create (or resume) the silent anonymous account, then run D-034's
/// migration / D-075's ongoing sync. Every step logs its own failure rather
/// than throwing past this function — one failed step must not stop the
/// others, and none of them may ever block habit check-off (D-031).
Future<void> _bootstrapAccountSync({required bool setupComplete}) async {
  final uid = await AuthService.instance.signInSilently();
  if (uid == null) return;

  final dbHelper = DatabaseHelper.instance;
  try {
    await dbHelper.setAccountUid(uid);
  } catch (e, st) {
    debugPrint('Failed to persist account uid locally: $e\n$st');
  }

  try {
    final timezone = await FlutterTimezone.getLocalTimezone();
    await dbHelper.setAccountTimezone(timezone);
  } catch (e, st) {
    debugPrint('Failed to persist account timezone locally: $e\n$st');
  }

  await SyncService.instance.syncAll(uid, setupComplete: setupComplete);
}
