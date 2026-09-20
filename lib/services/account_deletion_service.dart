import 'dart:convert';
import 'dart:io';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import 'db.dart';
import 'notification.dart';
import 'timeouts.dart';

/// Deletes the authenticated account through the server-owned boundary, then
/// removes the device's local copy and pending reminders.
class AccountDeletionService {
  AccountDeletionService({FirebaseAuth? auth, FirebaseAppCheck? appCheck})
      : _auth = auth ?? FirebaseAuth.instance,
        _appCheck = appCheck ?? FirebaseAppCheck.instance;

  static final AccountDeletionService instance = AccountDeletionService();

  static const _baseUrl = 'https://us-central1-life-ops.cloudfunctions.net/api';

  final FirebaseAuth _auth;
  final FirebaseAppCheck _appCheck;

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw const AccountDeletionException('not_signed_in');

    final appCheckToken = await _appCheck.getToken().timeout(remoteReadTimeout);
    final idToken = await user.getIdToken().timeout(remoteReadTimeout);
    if (appCheckToken == null || idToken == null) {
      throw const AccountDeletionException('authentication_unavailable');
    }

    final response = await http
        .post(
          Uri.parse('$_baseUrl/deleteAccount'),
          headers: {
            'Content-Type': 'application/json',
            'X-Firebase-AppCheck': appCheckToken,
            'Authorization': 'Bearer $idToken',
          },
          body: jsonEncode({'confirm': true}),
        )
        .timeout(remoteWriteTimeout);
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      final code =
          body is Map<String, dynamic> ? body['error'] as String? : null;
      throw AccountDeletionException(code ?? 'account_deletion_unavailable');
    }

    final db = DatabaseHelper.instance;
    final account = await db.getAccountState();
    final photoPath = account[DatabaseHelper.columnProfilePhotoPath] as String?;
    if (photoPath != null && photoPath.isNotEmpty) {
      try {
        final photo = File(photoPath);
        if (await photo.exists()) await photo.delete();
      } catch (_) {
        // The database and server are still erased even if an old local photo
        // is already inaccessible.
      }
    }
    await db.clearLocalDataForAccountDeletion();
    try {
      await LocalNotificationService().cancelAllPendingNotifications();
    } catch (_) {
      // Account data is already deleted. A notification-plugin failure cannot
      // turn a completed server deletion into a retry that risks confusion.
    }
    try {
      await GoogleSignIn.instance.initialize();
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Firebase is the account authority; native provider cleanup is best
      // effort and is retried naturally when the next account is linked.
    }
    await _auth.signOut();
  }
}

class AccountDeletionException implements Exception {
  const AccountDeletionException(this.code);
  final String code;

  @override
  String toString() => 'AccountDeletionException($code)';
}
