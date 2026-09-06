import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'lapsed_notification_pool.dart';
import 'notification.dart';

enum NotificationFallbackAction {
  /// Push is authorized and a token is registered — rely on it; cancel any
  /// local fallback so the account is never double-notified (D-038).
  relyOnPush,

  /// D-023: the account is lapsed — static pool, local, tap opens the
  /// paywall. Independent of push authorization.
  lapsedStatic,

  /// D-038: push denied, unavailable, or the token failed to register —
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

/// D-036/D-038: registers the FCM token for server-generated tailored
/// notifications, and keeps a local fallback in sync for whenever push
/// isn't available — permission denied, token registration failed, or the
/// account is lapsed (D-023's static pool instead). Called once after
/// D-065's permission screen, and again on each app open so the fallback
/// content and token both stay current.
class PushMessagingService {
  PushMessagingService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseMessaging? messaging,
    LocalNotificationService? local,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _messaging = messaging ?? FirebaseMessaging.instance,
        _local = local ?? LocalNotificationService();

  static final PushMessagingService instance = PushMessagingService();

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final FirebaseMessaging _messaging;
  final LocalNotificationService _local;

  static const _fallbackIds = {0: 100, 1: 101, 2: 102};
  static const _fallbackSlots = [(9, 0), (12, 0), (20, 0)];
  static const _defaultFallbackBody =
      'The Council is here whenever you\'re ready.';

  DocumentReference<Map<String, dynamic>>? _profileDoc(String? uid) {
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('profile').doc('main');
  }

  Future<void> syncNotificationState() async {
    final uid = _auth.currentUser?.uid;
    final doc = _profileDoc(uid);
    if (doc == null) return;

    bool pushAuthorized = false;
    String? token;
    try {
      final settings = await _messaging.getNotificationSettings();
      pushAuthorized = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (pushAuthorized) {
        token = await _messaging.getToken();
        if (token != null) {
          await doc.set({'fcmToken': token}, SetOptions(merge: true));
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
          body: (data?['lastNotificationBody'] as String?) ?? _defaultFallbackBody,
        );
    }
  }

  Future<void> _cancelFallback() async {
    for (final id in _fallbackIds.values) {
      await _local.cancelDailyNotification(id);
    }
  }

  Future<void> _scheduleFallback({required String body}) async {
    for (final entry in _fallbackIds.entries) {
      final (hour, minute) = _fallbackSlots[entry.key];
      await _local.cancelDailyNotification(entry.value);
      await _local.scheduleDailyNotification(
        id: entry.value,
        title: 'Green Pyramid',
        body: body,
        hour: hour,
        minute: minute,
        payload: '/',
      );
    }
  }

  Future<void> _scheduleLapsedPool() async {
    final dayIndex = DateTime.now().difference(DateTime(2026, 1, 1)).inDays;
    for (final entry in _fallbackIds.entries) {
      final (hour, minute) = _fallbackSlots[entry.key];
      final body = LapsedNotificationPool.forSlot(slotIndex: entry.key, dayIndex: dayIndex);
      await _local.cancelDailyNotification(entry.value);
      await _local.scheduleDailyNotification(
        id: entry.value,
        title: 'Green Pyramid',
        body: body,
        hour: hour,
        minute: minute,
        payload: '/paywall',
      );
    }
  }
}
