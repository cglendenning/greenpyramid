import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:life_ops/screens/batch_checkin_screen.dart';
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
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'firebase_options.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/widgets.dart';
import 'package:life_ops/widgets/pyramid_painting.dart';
import 'package:life_ops/services/push_messaging_service.dart';
import 'package:life_ops/services/subscription_service.dart';
import 'package:life_ops/services/entitlement_service.dart';
import 'package:life_ops/services/council_service.dart';

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

/// D-124 Phase 5: re-encodes an FCM message's `data` map as the
/// structured JSON payload `LocalNotificationService.onSelectNotification`
/// recognizes, so tapping a foreground-shown local notification for a
/// batch-checkin push routes the same way tapping the real push does.
/// Null for every other push type — this is deliberately scoped to
/// batch-checkin only, not a general-purpose payload passthrough.
String? batchCheckinPayloadFrom(Map<String, dynamic> data) {
  if (data['type'] != 'batch_checkin') return null;
  return jsonEncode(data);
}

/// D-124 Phase 5: opens [BatchCheckinScreen] from a real batch-checkin
/// push's habit list — shared by the backgrounded-tap
/// (`onMessageOpenedApp`) and terminated-launch (`getInitialMessage`)
/// paths. A message of any other type is silently ignored.
void handleBatchCheckinTap(RemoteMessage message) {
  if (message.data['type'] != 'batch_checkin') return;
  final habitsJson = message.data['habits'];
  if (habitsJson == null) return;
  try {
    final habits = (jsonDecode(habitsJson) as List).cast<Map<String, dynamic>>();
    navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => BatchCheckinScreen(habits: habits)));
  } catch (e, st) {
    debugPrint('Failed to open BatchCheckinScreen from a push: $e\n$st');
  }
}

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

  // D-070: configuring RevenueCat doesn't depend on the app's own account
  // (it's re-tied to the Firebase uid via login() in _bootstrapAccountSync)
  // and must never block first frame — started here, awaited nowhere.
  unawaited(SubscriptionService.initialize());

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

  // D-036: a push arriving while the app is foregrounded isn't
  // auto-displayed by the OS on most platforms — show it via the same
  // local-notification channel. Registered unconditionally; it simply
  // never fires for an account with no FCM token registered.
  //
  // D-124 Phase 5: a batch-checkin push's `data` carries the habit list
  // this app needs to open the right screen — threaded through as this
  // local notification's own payload, in the structured JSON shape
  // LocalNotificationService.onSelectNotification recognizes, so tapping
  // this foreground-shown notification opens BatchCheckinScreen the same
  // way tapping the real push does in the backgrounded/terminated cases
  // below.
  try {
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
      LocalNotificationService().showImmediateNotification(
        title: notification.title ?? 'Green Pyramid',
        body: notification.body ?? '',
        payload: batchCheckinPayloadFrom(message.data),
      );
    });
  } catch (e, st) {
    debugPrint('Failed to register foreground FCM listener: $e\n$st');
  }

  // D-124 Phase 5 / D-083 amendment: real pushes previously had zero
  // tap-routing capability — no data payload was ever sent, and no
  // onMessageOpenedApp/getInitialMessage handlers existed at all. The
  // batch-checkin push is the first to carry a `data` payload
  // (functions/index.js's batchCheckinJob), so these are the first
  // handlers that can act on one: a tap while backgrounded fires
  // onMessageOpenedApp; a tap that launches the app from terminated
  // fires getInitialMessage instead — both are needed to cover every
  // app state a tap can happen from.
  try {
    FirebaseMessaging.onMessageOpenedApp.listen(handleBatchCheckinTap);
  } catch (e, st) {
    debugPrint('Failed to register onMessageOpenedApp listener: $e\n$st');
  }
  try {
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) handleBatchCheckinTap(initialMessage);
  } catch (e, st) {
    debugPrint('Failed to read initial FCM message: $e\n$st');
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

  try {
    await SubscriptionService.login(uid);
  } catch (e, st) {
    debugPrint('Failed to log in to RevenueCat: $e\n$st');
  }

  // D-057: pulls the server-authoritative entitlement into the local cache
  // on every launch — a subscription confirmed via the RevenueCat webhook
  // never touches this device directly, so this is how it reaches the
  // local gate CouncilCategoryPicker reads.
  final hasServerEntitlement = await EntitlementService.instance.pullFromServer(uid);

  // D-071/D-116: a completed account with no real server entitlement gets
  // its trial grant (re)requested here, on every launch until it succeeds.
  // Checked against [hasServerEntitlement], never the local cache (D-116)
  // — found live: `requestTrialAfterSetup()`'s original call can fail
  // (D-059's DeviceCheck reliability issue) and is never otherwise
  // retried, silently leaving the account permanently ungated while the
  // local cache still reads whatever it read before that failure, masking
  // the very condition this retry exists to catch. Which grant to retry
  // depends on how this account reached completion: one that has a real
  // `setup`-typed Council session (D-082) went through the new flow and
  // gets D-058's normal request retried; one that doesn't is the D-034
  // migration cohort (old flow, no Council setup, so no device-bound
  // trial was ever requested) and gets D-071's one-time 30-day grant.
  if (setupComplete && !hasServerEntitlement) {
    final wentThroughCouncilSetup =
        await CouncilService.instance.hasEverCreatedSetupSession();
    if (wentThroughCouncilSetup) {
      await EntitlementService.instance.requestTrialAfterSetup();
    } else {
      await EntitlementService.instance.requestMigrationTrial();
    }
  }

  // D-036/D-039: keeps the FCM token and local fallback current on every
  // launch. Only for accounts that have already been through D-065's
  // permission screen — a brand-new install reaches this for the first
  // time from PushPermissionScreen, right after setup completes, not here.
  if (setupComplete) {
    try {
      await PushMessagingService.instance.syncNotificationState();
    } catch (e, st) {
      debugPrint('Failed to sync notification state: $e\n$st');
    }
  }
}
