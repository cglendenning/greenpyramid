import 'package:flutter/material.dart';
import 'package:life_ops/homescreen.dart';
import 'package:life_ops/notification.dart';
import "package:timezone/data/latest.dart" as tz show initializeTimeZones;
import 'package:life_ops/db.dart';
import 'package:flutter/services.dart';
import 'package:app_install_date/app_install_date.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:life_ops/pyramid_painting.dart';
import 'package:life_ops/services/ad_service.dart';

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

// AdMob device IDs for our own phones. Registering them makes the SDK serve
// *test* ads on these devices even from the genuine store build, so opening the
// app on a personal phone can never generate the self-inflicted invalid traffic
// that got ad serving suspended. Capture a device's id by running any build on
// it and reading the logged line:
//   "Use RequestConfiguration.Builder().setTestDeviceIds(Arrays.asList("<ID>"))"
// then add the id below (or pass --dart-define=ADMOB_TEST_DEVICE_IDS=id1,id2).
const List<String> _bakedInTestDeviceIds = <String>[
  '8A715648427E7AB282E4663FDF931373', // Craig's moto g play - 2023 (Android)
  'e8ff905da6280ea4d94e113a103328e4', // Craig's iPhone 12 mini (iOS)
];
final List<String> _adMobTestDeviceIds = <String>[
  ..._bakedInTestDeviceIds,
  ...const String.fromEnvironment('ADMOB_TEST_DEVICE_IDS')
      .split(',')
      .map((id) => id.trim())
      .where((id) => id.isNotEmpty),
];

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

  if (_adMobTestDeviceIds.isNotEmpty) {
    MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(testDeviceIds: _adMobTestDeviceIds),
    );
    debugPrint(
      'AdMob: registered ${_adMobTestDeviceIds.length} test device(s); '
      'they will receive test ads instead of live ads.',
    );
  }
  await MobileAds.instance.initialize();
  AdService.instance.preload();
  AdService.instance.startActivityPacing();

  int defaultCats = await dbHelper.queryLaunchSetup();

  if (defaultCats == 6) {
    routeToGo = '/setup';
  }
  runApp(HomeScreen());
}
