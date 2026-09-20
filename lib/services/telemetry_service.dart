import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// D-165: non-content product telemetry. Failures are deliberately swallowed
/// so analytics can never block tracking or expose an error to the user.
class TelemetryService {
  TelemetryService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth,
        _firestore = firestore;

  static final TelemetryService instance = TelemetryService();
  final FirebaseAuth? _auth;
  final FirebaseFirestore? _firestore;
  final String sessionId = DateTime.now().microsecondsSinceEpoch.toString();
  Future<PackageInfo>? _appInfo;

  Future<void> screenOpened(String screenKey) => event(
        'screen_open',
        screenKey: screenKey,
      );

  Future<void> event(String eventName, {String? screenKey}) async {
    try {
      const allowedEvents = {
        'screen_open',
        'screen_duration',
        'setup_begin',
        'account_link',
        'setup_complete',
        'trial_started',
        'subscription_started',
        'checkin_complete',
        'council_request_outcome',
        'notification_outcome',
      };
      if (!allowedEvents.contains(eventName)) return;
      final auth = _auth ?? FirebaseAuth.instance;
      final firestore = _firestore ?? FirebaseFirestore.instance;
      final uid = auth.currentUser?.uid;
      if (uid == null || eventName.isEmpty) return;
      final uidHash = sha256.convert(utf8.encode(uid)).toString();
      final eventId = sha256
          .convert(utf8.encode(
              '$sessionId:${DateTime.now().microsecondsSinceEpoch}:$eventName'))
          .toString()
          .substring(0, 32);
      final appInfo = await (_appInfo ??= PackageInfo.fromPlatform());
      await firestore.collection('users').doc(uid).collection('telemetry').add({
        'eventName': eventName.substring(0, eventName.length.clamp(0, 64)),
        'eventId': eventId,
        if (screenKey != null && screenKey.isNotEmpty)
          'screenKey': screenKey.substring(0, screenKey.length.clamp(0, 96)),
        'uidHash': uidHash,
        'sessionId': sessionId,
        'platform': Platform.isIOS
            ? 'ios'
            : Platform.isAndroid
                ? 'android'
                : 'other',
        'appVersion': '${appInfo.version}+${appInfo.buildNumber}',
        'occurredAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // D-165: telemetry is best-effort and never user-blocking.
    }
  }
}

class TelemetryNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _record(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) _record(newRoute);
  }

  /// D-181: only a full page counts as a screen.
  ///
  /// Every route used to be recorded, and the fallback for an unnamed one was
  /// its Dart type — so the dashboard's largest row by far was
  /// `MaterialPageRoute<dynamic>`, every unnamed push in the app added
  /// together, and its second largest was `_PopupMenuRoute<String?>`, which
  /// is the hamburger menu opening. Dialogs, bottom sheets and popup menus
  /// are not screens and answering "which screens get the most attention"
  /// does not want them counted as such. Every page route now carries an
  /// explicit name, so the type fallback should no longer be reachable; it
  /// stays because a route arriving unnamed is worth seeing in the dashboard
  /// rather than silently dropping.
  void _record(Route<dynamic> route) {
    if (route is! PageRoute) return;
    final key = route.settings.name ?? route.runtimeType.toString();
    unawaited(TelemetryService.instance.screenOpened(key));
  }
}
