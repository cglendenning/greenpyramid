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
// D-135: set when the app launches right after a sign-out that was never
// resolved before the app was killed — routes to WelcomeScreen's resetup
// mode (same screen as fresh install, not the home screen's unrelated
// D-132 "link your account" gate) instead of `defaultCats`'s normal
// local-data check, which can't tell the two situations apart on its own.
bool routeToGoIsResetup = false;
String payload = '';
bool populateGap = true;
DateTime installDate = DateTime.now();
bool interventionShown = false;

/// D-124 Phase 5 / D-083 amendment Phase 6 (2026-09-10): the payload a
/// foreground-shown local notification gets for a real FCM push, keyed
/// off the push's own `data.type` — batch-checkin needs the full habit
/// list re-encoded as the structured JSON payload
/// `LocalNotificationService.onSelectNotification` recognizes; a
/// tailored notification (D-036) needs only the same plain `/` payload
/// every other "go to the pyramid tab" local notification already uses,
/// since `onNotificationListener` (homescreen.dart) already handles that
/// string correctly. Null for any other/unknown type — this is a
/// deliberate allowlist, not a general-purpose passthrough.
String? pushTapPayloadFrom(Map<String, dynamic> data) {
  switch (data['type']) {
    case 'batch_checkin':
      return jsonEncode(data);
    case 'tailored':
      return '/';
    default:
      return null;
  }
}

/// D-124 Phase 5 / D-083 amendment Phase 6: routes a tap on a real FCM
/// push, keyed off `data.type` — shared by the backgrounded-tap
/// (`onMessageOpenedApp`) and terminated-launch (`getInitialMessage`)
/// paths. `batch_checkin` opens [BatchCheckinScreen] directly from the
/// push's own habit list. `tailored` (D-036) routes through the exact
/// same `onNotificationClick` stream every local notification already
/// uses — `/` on that stream already means "switch to the pyramid tab,"
/// correctly, since `onNotificationListener`'s Phase-6 fix — rather than
/// duplicating that navigation here. A message of any other/unknown type
/// is silently ignored.
void handlePushTap(RemoteMessage message) {
  switch (message.data['type']) {
    case 'batch_checkin':
      final habitsJson = message.data['habits'];
      if (habitsJson == null) return;
      try {
        final habits =
            (jsonDecode(habitsJson) as List).cast<Map<String, dynamic>>();
        navigatorKey.currentState?.push(MaterialPageRoute(
            builder: (_) => BatchCheckinScreen(habits: habits)));
      } catch (e, st) {
        debugPrint('Failed to open BatchCheckinScreen from a push: $e\n$st');
      }
      break;
    case 'tailored':
      LocalNotificationService().onNotificationClick.add('/');
      break;
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
  // D-124 Phase 5 / D-083 amendment Phase 6: a real push's `data` carries
  // what this app needs to route a tap on it correctly — threaded
  // through as this local notification's own payload (pushTapPayloadFrom
  // dispatches on `data.type`), so tapping this foreground-shown
  // notification routes the same way tapping the real push does in the
  // backgrounded/terminated cases below.
  try {
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
      LocalNotificationService().showImmediateNotification(
        title: notification.title ?? 'Green Pyramid',
        body: notification.body ?? '',
        payload: pushTapPayloadFrom(message.data),
      );
    });
  } catch (e, st) {
    debugPrint('Failed to register foreground FCM listener: $e\n$st');
  }

  // D-124 Phase 5 / D-083 amendment Phase 6: real pushes previously had
  // zero tap-routing capability at all — no `data` payload was ever
  // sent, for any push type, and no onMessageOpenedApp/getInitialMessage
  // handlers existed. Both are needed to cover every app state a tap can
  // happen from: a tap while backgrounded fires onMessageOpenedApp; a
  // tap that launches the app from terminated fires getInitialMessage
  // instead. handlePushTap dispatches on `data.type`, covering both the
  // batch-checkin push (D-124) and the tailored notification (D-036,
  // fixed alongside this).
  try {
    FirebaseMessaging.onMessageOpenedApp.listen(handlePushTap);
  } catch (e, st) {
    debugPrint('Failed to register onMessageOpenedApp listener: $e\n$st');
  }
  try {
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) handlePushTap(initialMessage);
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

  // D-135: checked before the local-data check — sign-out never touches
  // local SQLite, so `defaultCats` alone can't distinguish "a genuine
  // existing anonymous pyramid owner" (D-132's home-screen gate is
  // correct for them) from "just signed out, hasn't chosen yet."
  final justSignedOut = await AuthService.instance.consumeJustSignedOutFlag();
  if (justSignedOut) {
    routeToGo = '/setup';
    routeToGoIsResetup = true;
  } else if (defaultCats == 6) {
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
