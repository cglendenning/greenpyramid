import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:life_ops/screens/batch_checkin_screen.dart';
import 'package:life_ops/screens/paywall_screen.dart';
import 'package:life_ops/screens/homescreen.dart';
import 'package:life_ops/screens/general_council_screen.dart';
import 'package:life_ops/screens/database_recovery_screen.dart';
import 'package:life_ops/services/notification.dart';
import "package:timezone/data/latest.dart" as tz show initializeTimeZones;
import 'package:life_ops/services/db.dart';
import 'package:life_ops/services/auth_service.dart';
import 'package:life_ops/services/setup_draft_store.dart';
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
import 'package:life_ops/services/council_client.dart';

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
// D-001/D-148: an unfinished setup draft resumes directly in its persisted
// phase after a process restart. Fresh setup still starts at WelcomeScreen.
bool resumePendingSetup = false;
String payload = '';
bool populateGap = true;
DateTime installDate = DateTime.now();
bool interventionShown = false;

/// D-099 Phase 5 / D-066 amendment Phase 6 (2026-09-10): the payload a
/// foreground-shown local notification gets for a real FCM push, keyed
/// off the push's own `data.type` — batch-checkin needs the full habit
/// list re-encoded as the structured JSON payload
/// `LocalNotificationService.onSelectNotification` recognizes; a
/// tailored notifications retain their account and message identity so a
/// foreground-shown notification gets the same ownership check and inbox
/// acknowledgment as backgrounded and terminated pushes. Null for any
/// other/unknown type — this is a
/// deliberate allowlist, not a general-purpose passthrough.
String? pushTapPayloadFrom(Map<String, dynamic> data) {
  switch (data['type']) {
    case 'batch_checkin':
      return jsonEncode(data);
    case 'tailored':
      return jsonEncode(data);
    case 'intervention':
      return jsonEncode(data);
    default:
      return null;
  }
}

/// D-099 Phase 5 / D-066 amendment Phase 6: routes a tap on a real FCM
/// push, keyed off `data.type` — shared by the backgrounded-tap
/// (`onMessageOpenedApp`) and terminated-launch (`getInitialMessage`)
/// paths. `batch_checkin` opens [BatchCheckinScreen] directly from the
/// push's own habit list. `tailored` (D-149) routes through the exact
/// same `onNotificationClick` stream every local notification already
/// uses — `/` on that stream already means "switch to the pyramid tab,"
/// correctly, since `onNotificationListener`'s Phase-6 fix — rather than
/// duplicating that navigation here. A message of any other/unknown type
/// is silently ignored.
void handlePushTap(RemoteMessage message) {
  handlePushDataTap(message.data);
}

/// Handles both FCM data and the equivalent structured local-notification
/// payload. Every account-scoped notification enters here before it can
/// navigate or mark an inbox item read.
void handlePushDataTap(Map<String, dynamic> data) {
  final accountUid = data['accountUid'];
  if (accountUid is! String ||
      accountUid.isEmpty ||
      FirebaseAuth.instance.currentUser?.uid != accountUid) {
    // D-149-AC-04: a stale or cross-account payload must not open content.
    return;
  }
  final messageKey = data['messageKey'];
  if (messageKey is String) {
    unawaited(CouncilClient.instance
        .markInboxRead(messageKey)
        .catchError((_) => <String, dynamic>{}));
  }
  switch (data['type']) {
    case 'batch_checkin':
      unawaited(openBatchCheckinFromPayload(data));
      break;
    case 'tailored':
      LocalNotificationService().onNotificationClick.add('/');
      break;
    case 'intervention':
      // D-149: the inbox is the durable record for every non-silent engine
      // result; the selected surface is retained in the payload for the
      // eventual destination without letting the client choose policy.
      if (data['surface'] == 'council') {
        navigatorKey.currentState?.push(
            MaterialPageRoute(builder: (_) => const GeneralCouncilScreen()));
      } else {
        LocalNotificationService().onNotificationClick.add('/');
      }
      break;
    case 'upgrade':
      navigatorKey.currentState?.push(MaterialPageRoute(
          builder: (_) => const PaywallScreen(reason: 'notification')));
  }
}

Future<void> openBatchCheckinFromPayload(Map<String, dynamic> data) async {
  final rawIds = data['habitIds'] as String?;
  Set<String>? ids;
  if (rawIds != null) {
    try {
      final decoded = jsonDecode(rawIds);
      ids = decoded is List
          ? decoded.map((id) => id.toString()).toSet()
          : rawIds.split(',').where((id) => id.isNotEmpty).toSet();
    } catch (_) {
      ids = rawIds.split(',').where((id) => id.isNotEmpty).toSet();
    }
  }
  final resolvedIds = ids;
  if (resolvedIds == null || resolvedIds.isEmpty) return;
  try {
    final tasks = await DatabaseHelper.instance.queryAllTasks();
    final habits = tasks
        .where((task) => resolvedIds.contains(task['id']?.toString()))
        .map((task) => {
              'id': task['id']?.toString() ?? '',
              'category': task['category'],
              'description': task['taskdescription'],
              'scheduledtime': task['scheduledtime'],
            })
        .toList();
    if (habits.isEmpty) return; // deleted habits are harmless.
    final occurrenceDate =
        DateTime.tryParse(data['occurrenceDate'] as String? ?? '');
    navigatorKey.currentState?.push(MaterialPageRoute(
        builder: (_) => BatchCheckinScreen(
              habits: habits,
              occurrenceDate: occurrenceDate,
            )));
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
  // Capture a terminated-app notification tap before the initial route is
  // built. Structured payloads are queued by the service and dispatched once
  // HomeScreenWidget has a live navigator.
  await LocalNotificationService().intialize();
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

  // D-108/D-147: native Firebase auth restoration completes asynchronously.
  // Route and synchronize only after the initial state is known; otherwise a
  // restored linked account can be mistaken for signed-out and replaced by a
  // new anonymous identity.
  final restoredUser = await AuthService.instance.waitForRestoredUser();

  // D-054: configuring RevenueCat doesn't depend on the app's own account
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

  // D-149: a push arriving while the app is foregrounded isn't
  // auto-displayed by the OS on most platforms — show it via the same
  // local-notification channel. Registered unconditionally; it simply
  // never fires for an account with no FCM token registered.
  //
  // D-099 Phase 5 / D-066 amendment Phase 6: a real push's `data` carries
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

  // D-099 Phase 5 / D-066 amendment Phase 6: real pushes previously had
  // zero tap-routing capability at all — no `data` payload was ever
  // sent, for any push type, and no onMessageOpenedApp/getInitialMessage
  // handlers existed. Both are needed to cover every app state a tap can
  // happen from: a tap while backgrounded fires onMessageOpenedApp; a
  // tap that launches the app from terminated fires getInitialMessage
  // instead. handlePushTap dispatches on `data.type`, covering both the
  // batch-checkin push (D-099) and the tailored notification (D-149,
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

  // D-147: migration is best-effort. If the database cannot be opened or
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

  // D-025/D-147: a linked account with an empty local cache must hydrate from
  // Firestore before startup sync is allowed to reconcile anything. The
  // restore path is intentionally awaited before the first route is built.
  if (restoredUser != null && !restoredUser.isAnonymous && defaultCats == 6) {
    await SyncService.instance.restoreFromCloud(restoredUser.uid);
    defaultCats = await dbHelper.queryLaunchSetup();
  }

  // D-001: empty local categories do not invalidate anonymous credentials.
  // Pending setup must route to its draft even after categories were accepted.
  final pending = restoredUser?.uid;
  final draft = pending == null
      ? null
      : await SetupDraftStore(db: dbHelper).load(pending);
  resumePendingSetup = draft != null && draft['state']['phase'] != 'finished';
  if (restoredUser == null || defaultCats == 6 || resumePendingSetup) {
    routeToGo = '/setup';
  }
  runApp(HomeScreen());

  // D-029/D-027: silent account bootstrap, kicked off after the first frame
  // so it never gates app startup or changes the setup step count (D-005).
  // Not awaited — a failure here is retried on the next launch, never shown
  // to the user (D-029 acceptance criteria).
  unawaited(_bootstrapAccountSync(
      setupComplete: defaultCats != 6 &&
          (draft == null || draft['state']['phase'] == 'finished')));
}

/// D-029: create (or resume) the silent anonymous account, then run D-027's
/// migration / D-147's ongoing sync. Every step logs its own failure rather
/// than throwing past this function — one failed step must not stop the
/// others, and none of them may ever block habit check-off (D-026).
Future<void> _bootstrapAccountSync({required bool setupComplete}) async {
  // Startup must never create an anonymous identity. Begin/setup owns that
  // explicit action; here we only continue a session Firebase restored.
  final restoredUser = await AuthService.instance.waitForRestoredUser();
  if (restoredUser == null) return;
  final uid = restoredUser.uid;

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

  await SyncService.instance.syncAll(uid,
      setupComplete: setupComplete, protectCloudFromEmptyLocal: true);

  try {
    await SubscriptionService.login(uid);
  } catch (e, st) {
    debugPrint('Failed to log in to RevenueCat: $e\n$st');
  }

  // D-044: pulls the server-authoritative entitlement into the local cache
  // on every launch — a subscription confirmed via the RevenueCat webhook
  // never touches this device directly, so this is how it reaches the
  // local gate CouncilCategoryPicker reads.
  final hasServerEntitlement =
      await EntitlementService.instance.pullFromServer(uid);

  // D-055/D-091: a completed account with no real server entitlement gets
  // its trial grant (re)requested here, on every launch until it succeeds.
  // Checked against [hasServerEntitlement], never the local cache (D-091)
  // — found live: `requestTrialAfterSetup()`'s original call can fail
  // (D-045's DeviceCheck reliability issue) and is never otherwise
  // retried, silently leaving the account permanently ungated while the
  // local cache still reads whatever it read before that failure, masking
  // the very condition this retry exists to catch. Which grant to retry
  // depends on how this account reached completion: one that has a real
  // `setup`-typed Council session (D-148) went through the new flow and
  // gets D-148's normal request retried; one that doesn't is the D-027
  // migration cohort (old flow, no Council setup, so no device-bound
  // trial was ever requested) and gets D-055's one-time 30-day grant.
  if (setupComplete && !hasServerEntitlement) {
    final wentThroughCouncilSetup =
        await CouncilService.instance.hasEverCreatedSetupSession();
    if (wentThroughCouncilSetup) {
      await EntitlementService.instance.requestTrialAfterSetup();
    } else {
      await EntitlementService.instance.requestMigrationTrial();
    }
  }

  // D-149/D-149: keeps the FCM token and local fallback current on every
  // launch. Only for accounts that have already been through D-050's
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
