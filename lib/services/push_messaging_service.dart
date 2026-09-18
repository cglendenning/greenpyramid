import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:timezone/timezone.dart' as tz;

import 'lapsed_notification_pool.dart';
import 'notification.dart';
import 'council_client.dart';

enum NotificationFallbackAction {
  /// Push is authorized and a token is registered — rely on it; cancel any
  /// local fallback so the account is never double-notified (D-149).
  relyOnPush,

  /// D-021: the account is lapsed — static pool, local, tap opens the
  /// paywall. Independent of push authorization.
  lapsedStatic,

  /// D-149: push denied, unavailable, or the token failed to register —
  /// schedule local notifications from the most recent server-generated
  /// content, or a static line if none exists yet.
  localFallback,
}

/// Pure decision logic, factored out so it's testable without touching the
/// (unmockable) FirebaseMessaging plugin — matches this repo's convention
/// of extracting a pure function rather than leaving a live-plugin service
/// untested at the unit level (see notification_schedule.js on the backend
/// for the same pattern).
NotificationFallbackAction decideNotificationFallback({
  required String? entitlement,
  required bool pushAuthorized,
  required bool hasToken,
}) {
  if (entitlement == 'lapsed') return NotificationFallbackAction.lapsedStatic;
  if (pushAuthorized && hasToken) return NotificationFallbackAction.relyOnPush;
  return NotificationFallbackAction.localFallback;
}

/// D-149/D-149: registers the FCM token for server-generated tailored
/// notifications, and keeps a local fallback in sync for whenever push
/// isn't available — permission denied, token registration failed, or the
/// account is lapsed (D-021's static pool instead). Called once after
/// D-050's permission screen, and again on each app open so the fallback
/// content and token both stay current.
class PushMessagingService {
  PushMessagingService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseMessaging? messaging,
    LocalNotificationService? local,
    CouncilClient? client,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _messaging = messaging ?? FirebaseMessaging.instance,
        _local = local ?? LocalNotificationService(),
        _client = client ?? CouncilClient.instance;

  static final PushMessagingService instance = PushMessagingService();

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final FirebaseMessaging _messaging;
  final LocalNotificationService _local;
  final CouncilClient _client;
  static const _uuid = Uuid();
  static const _installationKey = 'd149.installation_id';
  static const _revisionKey = 'd149.installation_revision';
  static const _tokenKey = 'd149.installation_token';

  static const _fallbackIds = {0: 100, 1: 101, 2: 102};
  static const _fallbackSlots = [(9, 0), (14, 0), (19, 0)];
  static const _defaultFallbackTitle = 'Your next step matters';
  static const _defaultFallbackBody =
      'The Council of Advisors is here whenever you\'re ready.';
  bool _tokenRefreshListenerStarted = false;

  DocumentReference<Map<String, dynamic>>? _profileDoc(String? uid) {
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('profile').doc('main');
  }

  Future<void> syncNotificationState() async {
    final uid = _auth.currentUser?.uid;
    final doc = _profileDoc(uid);
    if (doc == null) return;
    final prefs = await SharedPreferences.getInstance();
    final installationId = prefs.getString(_installationKey) ?? _uuid.v4();
    await prefs.setString(_installationKey, installationId);
    _startTokenRefreshListener();

    bool pushAuthorized = false;
    String? token;
    try {
      final settings = await _messaging.getNotificationSettings();
      pushAuthorized =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;
      if (pushAuthorized) {
        token = await _getTokenWithRetry();
        if (token != null) {
          await _registerInstallationToken(
            installationId: installationId,
            token: token,
            prefs: prefs,
          );
        }
      }
    } catch (e) {
      debugPrint('PushMessagingService: could not read messaging state: $e');
    }

    Map<String, dynamic>? data;
    try {
      data = (await doc.get()).data();
    } catch (e) {
      debugPrint('PushMessagingService: could not read profile: $e');
    }

    final action = decideNotificationFallback(
      entitlement: data?['entitlement'] as String?,
      pushAuthorized: pushAuthorized,
      hasToken: token != null,
    );

    switch (action) {
      case NotificationFallbackAction.relyOnPush:
        await _cancelFallback();
      case NotificationFallbackAction.lapsedStatic:
        await _scheduleLapsedPool();
      case NotificationFallbackAction.localFallback:
        await _scheduleFallback(
          title: (data?['lastNotificationTitle'] as String?) ??
              _defaultFallbackTitle,
          body: (data?['lastNotificationBody'] as String?) ??
              _defaultFallbackBody,
        );
    }
  }

  /// D-050/D-149: Firebase Messaging owns the APNs/FCM registration as well
  /// as the local notification permission. Calling this only from the three
  /// explicit permission flows avoids a permission prompt on ordinary launch.
  Future<void> requestPermissionAndSync() async {
    try {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
    } catch (e) {
      debugPrint('PushMessagingService: FCM permission request failed: $e');
    }
    await syncNotificationState();
  }

  void _startTokenRefreshListener() {
    if (_tokenRefreshListenerStarted) return;
    _tokenRefreshListenerStarted = true;
    _messaging.onTokenRefresh.listen((token) async {
      final user = _auth.currentUser;
      if (user == null || token.isEmpty) return;
      final prefs = await SharedPreferences.getInstance();
      final installationId = prefs.getString(_installationKey) ?? _uuid.v4();
      await prefs.setString(_installationKey, installationId);
      await _registerInstallationToken(
        installationId: installationId,
        token: token,
        prefs: prefs,
      );
    }, onError: (Object error) {
      debugPrint('PushMessagingService: token refresh stream failed: $error');
    });
  }

  Future<String?> _getTokenWithRetry() async {
    // On iOS the APNs token may become available just after Firebase Auth and
    // the notification permission flow finish. The old one-shot getToken()
    // left the account with no installation permanently until a later app
    // launch, which is why the inbox could contain a check-in with no banner.
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final token = await _messaging.getToken();
        if (token != null && token.isNotEmpty) return token;
      } catch (e) {
        debugPrint('PushMessagingService: FCM token attempt failed: $e');
      }
      if (attempt < 2) {
        await Future<void>.delayed(Duration(seconds: attempt + 1));
      }
    }
    return null;
  }

  Future<bool> _registerInstallationToken({
    required String installationId,
    required String token,
    required SharedPreferences prefs,
  }) async {
    try {
      final result = await _client.registerInstallation(
        installationId: installationId,
        token: token,
        enabled: true,
        timezone: tz.local.name,
        expectedRevision: prefs.getInt(_revisionKey) ?? 0,
      );
      if (result['acknowledged'] == true) {
        await prefs.setInt(
            _revisionKey, (prefs.getInt(_revisionKey) ?? 0) + 1);
        await prefs.setString(_tokenKey, token);
        return true;
      }
    } catch (e) {
      debugPrint(
          'PushMessagingService: installation registration failed: $e');
    }
    return false;
  }

  /// D-149-AC-04: disable this installation before Firebase identity changes
  /// so the outgoing account cannot receive future notifications.
  Future<void> unregisterCurrentInstallation() async {
    if (_auth.currentUser == null) return;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token == null) return;
    try {
      await _client.registerInstallation(
        installationId: prefs.getString(_installationKey) ?? _uuid.v4(),
        token: token,
        enabled: false,
        timezone: tz.local.name,
        expectedRevision: prefs.getInt(_revisionKey) ?? 0,
      );
    } catch (e) {
      debugPrint('PushMessagingService: installation unregister failed: $e');
    }
  }

  Future<void> _cancelFallback() async {
    for (final id in _fallbackIds.values) {
      await _local.cancelDailyNotification(id);
    }
  }

  Future<void> _scheduleFallback(
      {required String title, required String body}) async {
    for (final entry in _fallbackIds.entries) {
      final (hour, minute) = _fallbackSlots[entry.key];
      await _local.cancelDailyNotification(entry.value);
      await _local.scheduleDailyNotification(
        id: entry.value,
        title: title,
        body: body,
        hour: hour,
        minute: minute,
        payload: jsonEncode({
          'type': 'intervention',
          'accountUid': _auth.currentUser?.uid,
          'messageKey': 'intervention:fallback:${entry.key}',
          'occurrenceDate': DateTime.now().toIso8601String().substring(0, 10),
        }),
      );
    }
  }

  Future<void> _scheduleLapsedPool() async {
    final dayIndex = DateTime.now().difference(DateTime(2026, 1, 1)).inDays;
    for (final entry in _fallbackIds.entries) {
      final (hour, minute) = _fallbackSlots[entry.key];
      final body = LapsedNotificationPool.forSlot(
          slotIndex: entry.key, dayIndex: dayIndex);
      await _local.cancelDailyNotification(entry.value);
      await _local.scheduleDailyNotification(
        id: entry.value,
        title: body,
        body: 'Open Green Pyramid to continue.',
        hour: hour,
        minute: minute,
        payload: jsonEncode({
          'type': 'upgrade',
          'accountUid': _auth.currentUser?.uid,
          'messageKey': 'upgrade:lapsed:${entry.key}',
          'occurrenceDate': DateTime.now().toIso8601String().substring(0, 10),
        }),
      );
    }
  }
}
