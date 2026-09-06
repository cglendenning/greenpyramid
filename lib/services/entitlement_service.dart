import 'dart:convert';
import 'dart:io';

import 'package:android_id/android_id.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:device_check/device_check.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'db.dart';

/// D-057/D-058/D-059/D-071: requests and caches the server-authoritative
/// trial/subscription state. `functions/lib/device_trial.js` and
/// `functions/lib/entitlement.js` are the actual source of truth — this
/// class only asks for a grant and mirrors the answer into the local
/// account_state cache. It never decides entitlement on-device.
class EntitlementService {
  EntitlementService({DatabaseHelper? db, FirebaseFirestore? firestore})
      : _db = db ?? DatabaseHelper.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  static final EntitlementService instance = EntitlementService();

  static const String _baseUrl =
      'https://us-central1-life-ops.cloudfunctions.net/api';

  final DatabaseHelper _db;
  final FirebaseFirestore _firestore;

  Future<Map<String, String>> _headers() async {
    final appCheckToken = await FirebaseAppCheck.instance.getToken();
    final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (appCheckToken == null || idToken == null) {
      throw StateError('EntitlementService: not ready (missing App Check or ID token)');
    }
    return {
      'Content-Type': 'application/json',
      'X-Firebase-AppCheck': appCheckToken,
      'Authorization': 'Bearer $idToken',
    };
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final headers = await _headers();
    final resp = await http
        .post(Uri.parse('$_baseUrl/$path'), headers: headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 20));
    if (resp.statusCode != 200) {
      throw StateError('EntitlementService: $path backend ${resp.statusCode}: ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  /// D-059: SHA-256 of ANDROID_ID — the raw identifier never leaves the
  /// device or reaches this app's own storage, only its hash.
  Future<String?> _androidIdHash() async {
    final id = await const AndroidId().getId();
    if (id == null) return null;
    return sha256.convert(utf8.encode(id)).toString();
  }

  /// D-058: called once, right at setup completion — the clock starts at
  /// the pyramid reveal, not at install. Never throws past this point, only
  /// logs: a network hiccup here must not block the completion screen, and
  /// the account simply stays pre_trial until the next opportunity.
  Future<void> requestTrialAfterSetup() async {
    try {
      final body = <String, dynamic>{'isDevelopmentBuild': kDebugMode};
      if (Platform.isAndroid) {
        final hash = await _androidIdHash();
        if (hash == null) {
          debugPrint('EntitlementService: no ANDROID_ID available, skipping trial request.');
          return;
        }
        body['platform'] = 'android';
        body['androidIdHash'] = hash;
      } else if (Platform.isIOS) {
        final supported = await DeviceCheck.instance.isSupported();
        if (!supported) {
          debugPrint('EntitlementService: DeviceCheck unsupported, skipping trial request.');
          return;
        }
        final token = await DeviceCheck.instance.generateToken();
        body['platform'] = 'ios';
        body['deviceCheckToken'] = base64Encode(token);
      } else {
        return;
      }
      await _applyServerResult(await _post('requestTrial', body));
    } catch (e, st) {
      debugPrint('EntitlementService.requestTrialAfterSetup failed: $e\n$st');
    }
  }

  /// D-071: the one-time 30-day grant for existing (pre-R8) users. Callers
  /// only invoke this when the pulled server entitlement is still
  /// 'pre_trial' on a setup-complete account (main.dart's bootstrap) — the
  /// backend re-checks this itself anyway, so a spurious call is harmless.
  Future<void> requestMigrationTrial() async {
    try {
      await _applyServerResult(await _post('requestTrial', {'isMigration': true}));
    } catch (e, st) {
      debugPrint('EntitlementService.requestMigrationTrial failed: $e\n$st');
    }
  }

  /// Pulls the current server-authoritative entitlement into the local
  /// cache. Called on every launch: a subscription confirmed via the
  /// RevenueCat webhook never touches this device directly, so this is how
  /// it reaches the local gate that CouncilCategoryPicker reads.
  Future<void> pullFromServer(String uid) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .collection('profile')
          .doc('main')
          .get();
      final data = doc.data();
      final entitlement = data?['entitlement'] as String?;
      if (entitlement == null) return;
      await _db.setAccountEntitlement(
        entitlement: entitlement,
        trialStartedAt: (data?['trialStartedAt'] as Timestamp?)?.toDate().toIso8601String(),
        trialExpiresAt: (data?['trialExpiresAt'] as Timestamp?)?.toDate().toIso8601String(),
      );
    } catch (e, st) {
      debugPrint('EntitlementService.pullFromServer failed: $e\n$st');
    }
  }

  /// Optimistic local write immediately after a purchase/restore confirms —
  /// mirrors Kansei's markSubscribed pattern, so the app reflects the new
  /// state instantly rather than waiting for the RevenueCat webhook to land
  /// in Firestore and get pulled back down on the next launch.
  Future<void> markSubscribedLocally() => _db.setAccountEntitlement(entitlement: 'subscribed');

  Future<bool> isEntitled() async {
    final account = await _db.getAccountState();
    final entitlement = account[DatabaseHelper.columnEntitlement] as String?;
    return entitlement == 'trialing' || entitlement == 'subscribed';
  }

  Future<void> _applyServerResult(Map<String, dynamic> result) async {
    final entitlement = result['entitlement'] as String?;
    if (entitlement == null) return;
    final trialExpiresAt = result['trialExpiresAt'] != null
        ? DateTime.tryParse(result['trialExpiresAt'] as String)
        : null;
    await _db.setAccountEntitlement(
      entitlement: entitlement,
      trialExpiresAt: trialExpiresAt?.toIso8601String(),
    );
  }
}
