import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// D-030/D-032/D-033: identity, held separately from data sync
/// ([SyncService]) so habit check-off (D-031) never depends on this
/// succeeding.
///
/// [FirebaseAuth] is injectable so tests run against
/// `firebase_auth_mocks.MockFirebaseAuth` instead of a live project.
class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  static final AuthService instance = AuthService();

  final FirebaseAuth _auth;

  String? get currentUid => _auth.currentUser?.uid;

  Stream<User?> get userChanges => _auth.userChanges();

  /// D-032: silently create (or resume) an anonymous account. Never throws
  /// and never surfaces anything to the user — a failure is logged and the
  /// app continues in local-only mode; the caller is expected to retry this
  /// on the next launch, not to block on it now.
  Future<String?> signInSilently() async {
    try {
      final existing = _auth.currentUser;
      if (existing != null) return existing.uid;
      final credential = await _auth.signInAnonymously();
      return credential.user?.uid;
    } catch (e, st) {
      debugPrint(
          'AuthService: anonymous sign-in failed, will retry next launch: $e\n$st');
      return null;
    }
  }

  /// D-033: upgrade the anonymous account in place via Firebase account
  /// linking. Preserves the existing uid and every document under it — no
  /// data is created, copied, or lost. Throws on failure; callers (the
  /// subscribe flow, the add-a-device flow) decide how to surface that,
  /// since this method has no context for a user-facing message.
  Future<User?> linkWithCredential(AuthCredential credential) async {
    final current = _auth.currentUser;
    if (current == null || !current.isAnonymous) {
      throw StateError(
          'linkWithCredential requires a signed-in anonymous user');
    }
    final result = await current.linkWithCredential(credential);
    return result.user;
  }
}
