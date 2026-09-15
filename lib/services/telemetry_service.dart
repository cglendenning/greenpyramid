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
      final auth = _auth ?? FirebaseAuth.instance;
      final firestore = _firestore ?? FirebaseFirestore.instance;
      final uid = auth.currentUser?.uid;
      if (uid == null || eventName.isEmpty) return;
      final uidHash = sha256.convert(utf8.encode(uid)).toString();
      final appInfo = await (_appInfo ??= PackageInfo.fromPlatform());
      await firestore
          .collection('users')
          .doc(uid)
          .collection('telemetry')
          .add({
        'eventName': eventName.substring(0, eventName.length.clamp(0, 64)),
        if (screenKey != null && screenKey.isNotEmpty)
          'screenKey': screenKey.substring(0, screenKey.length.clamp(0, 96)),
        'uidHash': uidHash,
        'sessionId': sessionId,
        'platform': Platform.isIOS ? 'ios' : Platform.isAndroid ? 'android' : 'other',
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
    final key = route.settings.name ?? route.runtimeType.toString();
    unawaited(TelemetryService.instance.screenOpened(key));
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      final key = newRoute.settings.name ?? newRoute.runtimeType.toString();
      unawaited(TelemetryService.instance.screenOpened(key));
    }
  }
}
