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

/// D-044/D-148/D-045/D-055: requests and caches the server-authoritative
/// trial/subscription state. `functions/lib/device_trial.js` and
/// `functions/lib/entitlement.js` are the actual source of truth — this
/// class only asks for a grant and mirrors the answer into the local
/// account_state cache. It never decides entitlement on-device.
class EntitlementService {
  EntitlementService(
      {DatabaseHelper? db, FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _db = db ?? DatabaseHelper.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _authOverride = auth;

  static final EntitlementService instance = EntitlementService();

  static const String _baseUrl =
      'https://us-central1-life-ops.cloudfunctions.net/api';

  final DatabaseHelper _db;
  final FirebaseFirestore _firestore;
  final FirebaseAuth? _authOverride;

  // Resolved lazily, not in the constructor: FirebaseAuth.instance throws
  // in a unit test with no Firebase app initialized, and many existing
  // tests construct this service without ever needing auth at all (e.g.
  // pullFromServer's own tests) — same lazy-getter fix already applied
  // to AccountLinkService's SyncService dependency (D-147) for the
  // identical reason.
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  Future<Map<String, String>> _headers() async {
    final appCheckToken = await FirebaseAppCheck.instance.getToken();
    final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (appCheckToken == null || idToken == null) {
      throw StateError(
          'EntitlementService: not ready (missing App Check or ID token)');
    }
    return {
      'Content-Type': 'application/json',
      'X-Firebase-AppCheck': appCheckToken,
      'Authorization': 'Bearer $idToken',
    };
  }

  Future<Map<String, dynamic>> _post(
      String path, Map<String, dynamic> body) async {
    final headers = await _headers();
    final resp = await http
        .post(Uri.parse('$_baseUrl/$path'),
            headers: headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 20));
    if (resp.statusCode != 200) {
      throw StateError(
          'EntitlementService: $path backend ${resp.statusCode}: ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  /// D-045: SHA-256 of ANDROID_ID — the raw identifier never leaves the
  /// device or reaches this app's own storage, only its hash.
  Future<String?> _androidIdHash() async {
    final id = await const AndroidId().getId();
    if (id == null) return null;
    return sha256.convert(utf8.encode(id)).toString();
  }

  /// D-045: whether THIS build's iOS code signing is Apple's "development"
  /// DeviceCheck environment — not whether Dart itself is compiled in debug
  /// mode. Release/OTA artifacts use Apple's distribution provisioning profile
  /// and the production DeviceCheck endpoint. A development-signed artifact is
  /// not a valid release fallback because its attestation environment differs.
  static const bool _isDeviceCheckDevelopmentEnvironment = false;

  /// D-148: called once, right at setup completion — the clock starts at
  /// the pyramid reveal, not at install. Never throws past this point, only
  /// logs: a network hiccup here must not block the completion screen, and
  /// the account simply stays pre_trial until the next opportunity.
  Future<void> requestTrialAfterSetup() async {
    try {
      final body = <String, dynamic>{
        'isDevelopmentBuild': _isDeviceCheckDevelopmentEnvironment,
      };
      if (Platform.isAndroid) {
        final hash = await _androidIdHash();
        if (hash == null) {
          debugPrint(
              'EntitlementService: no ANDROID_ID available, skipping trial request.');
          return;
        }
        body['platform'] = 'android';
        body['androidIdHash'] = hash;
      } else if (Platform.isIOS) {
        final supported = await DeviceCheck.instance.isSupported();
        if (!supported) {
          debugPrint(
              'EntitlementService: DeviceCheck unsupported, skipping trial request.');
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

  /// D-055: the one-time 30-day grant for existing (pre-R8) users. Callers
  /// only invoke this when the pulled server entitlement is still
  /// 'pre_trial' on a setup-complete account (main.dart's bootstrap) — the
  /// backend re-checks this itself anyway, so a spurious call is harmless.
  Future<void> requestMigrationTrial() async {
    try {
      await _applyServerResult(
          await _post('requestTrial', {'isMigration': true}));
    } catch (e, st) {
      debugPrint('EntitlementService.requestMigrationTrial failed: $e\n$st');
    }
  }

  /// Pulls the current server-authoritative entitlement into the local
  /// cache. Called on every launch: a subscription confirmed via the
  /// RevenueCat webhook never touches this device directly, so this is how
  /// it reaches the local gate that CouncilCategoryPicker reads.
  ///
  /// D-091: returns whether a real server entitlement was found and
  /// applied — `main.dart`'s bootstrap uses this, not the local cache, to
  /// decide whether a trial grant needs retrying. The local cache is
  /// exactly the wrong signal for that decision: it never changes when
  /// the server has nothing (this method's own `entitlement == null`
  /// early return, by design — a doc that hasn't synced yet shouldn't
  /// erase a device's last-known state), so a device whose original
  /// requestTrialAfterSetup() call failed keeps reading whatever it read
  /// before that failure, forever, and a retry-on-pre_trial check against
  /// that cache never fires.
  Future<bool> pullFromServer(String uid) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .collection('profile')
          .doc('main')
          .get();
      final data = doc.data();
      final entitlement = data?['entitlement'] as String?;
      if (entitlement == null) return false;
      final local = await _db.getAccountState();
      final localEntitlement =
          local[DatabaseHelper.columnEntitlement] as String?;
      // D-142/D-054: a successful RevenueCat purchase is written locally
      // before its webhook reaches Firestore. Do not let that in-flight
      // webhook gap downgrade the confirmed paid state when a screen opens
      // and refreshes the server copy. A later server lapsed state remains
      // authoritative and is still applied below.
      final preserveConfirmedSubscription = localEntitlement == 'subscribed' &&
          (entitlement == 'pre_trial' || entitlement == 'trialing');
      if (preserveConfirmedSubscription) {
        debugPrint(
            'EntitlementService: preserving confirmed local subscription '
            'while the RevenueCat webhook catches up.');
        return true;
      }
      await _db.setAccountEntitlement(
        entitlement: entitlement,
        trialStartedAt:
            (data?['trialStartedAt'] as Timestamp?)?.toDate().toIso8601String(),
        trialExpiresAt:
            (data?['trialExpiresAt'] as Timestamp?)?.toDate().toIso8601String(),
        lifetimeAccess: data?['lifetimeAccess'] == true,
      );
      return true;
    } catch (e, st) {
      debugPrint('EntitlementService.pullFromServer failed: $e\n$st');
      return false;
    }
  }

  /// Optimistic local write immediately after a purchase/restore confirms —
  /// mirrors Kansei's markSubscribed pattern, so the app reflects the new
  /// state instantly rather than waiting for the RevenueCat webhook to land
  /// in Firestore and get pulled back down on the next launch.
  Future<void> markSubscribedLocally() =>
      _db.setAccountEntitlement(entitlement: 'subscribed');

  /// D-167: redeems an admin-issued, single-use lifetime gift through the
  /// authenticated cloud service. The response grants the normal subscribed
  /// capability plus a separate lifetime flag; no RevenueCat purchase is
  /// created or modified.
  Future<void> redeemLifetimeCode(String code) async {
    await _applyServerResult(
        await _post('redeemLifetimeCode', {'code': code.trim()}));
  }

  /// D-168: removes only the lifetime gift. The cloud service preserves any
  /// independently active Apple/RevenueCat entitlement.
  Future<void> revokeLifetimeAccess() async {
    await _applyServerResult(await _post('revokeLifetimeAccess', {}));
  }

  /// D-142 (amended): the single shared gate (`ensureEntitled`, and
  /// through it every screen that calls it) now self-heals against
  /// Firestore before trusting the local cache — found live, the local
  /// `account_state.entitlement` column is otherwise refreshed only at
  /// cold app launch or by a purchase's own optimistic local write
  /// (`markSubscribedLocally`), which can be skipped entirely if the
  /// purchase flow hiccups partway through. A failed or empty pull is a
  /// silent no-op ([pullFromServer]'s own designed behavior) — this
  /// never blocks or fails a gate check just because the network is
  /// down, it only ever has a chance to *improve* on what's cached.
  Future<bool> isEntitled() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await pullFromServer(uid);
    }
    final entitlement = await currentLocalEntitlement();
    return entitlement == 'trialing' || entitlement == 'subscribed';
  }

  /// D-090: the raw local entitlement string — 'trialing', 'subscribed',
  /// 'lapsed', or 'pre_trial' — for a caller that needs to *display* the
  /// account's state (the settings screen's subscription panel copy),
  /// not gate a feature on it. [isEntitled] remains the gate; keeping the
  /// raw DB column read here, not in `lib/screens/`, is what lets D-013's
  /// "the tracker never checks entitlement" test scan screen files for
  /// `columnEntitlement` and mean it.
  Future<String?> currentLocalEntitlement() async {
    final account = await _db.getAccountState();
    return account[DatabaseHelper.columnEntitlement] as String?;
  }

  Future<bool> currentLocalLifetimeAccess() async {
    final account = await _db.getAccountState();
    return account[DatabaseHelper.columnLifetimeAccess] == 1;
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
      lifetimeAccess: result.containsKey('lifetimeAccess')
          ? result['lifetimeAccess'] == true
          : null,
    );
  }
}
