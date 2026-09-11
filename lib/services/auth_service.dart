import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // D-132: defaults to true (no signed-in user at all) — callers gating on
  // "is this a real account" should fail closed, not treat "unknown" as
  // "yes, real."
  bool get isAnonymous => _auth.currentUser?.isAnonymous ?? true;

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

  /// D-132: signs out of the current (real) Firebase account. Never
  /// leaves the app fully signed out — every screen that touches
  /// Firestore assumes at least an anonymous uid exists (D-032) — so the
  /// caller is expected to follow this with [signInSilently] to
  /// re-establish that baseline before showing anything else.
  Future<void> signOut() => _auth.signOut();

  static const _justSignedOutKey = 'justSignedOut';

  /// D-135: sign-out never touches local SQLite (the local pyramid stays
  /// exactly as it was), so `main.dart`'s launch routing — which only
  /// ever looks at local data — has no way to tell "an existing user who
  /// never linked an account" (D-132's home-screen gate is correct for
  /// them) apart from "a user who just deliberately signed out and
  /// hasn't chosen sign-in-or-rebuild yet" (found live: the latter landed
  /// on the home screen showing the wrong, setup-flavored account
  /// screen, because nothing told it a sign-out had just happened). This
  /// flag is the missing signal, persisted so it survives the app being
  /// killed between sign-out and the user's next choice — an in-session
  /// sign-out alone doesn't need it (the caller navigates directly), but
  /// a kill-and-relaunch in between does.
  Future<void> markJustSignedOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_justSignedOutKey, true);
  }

  /// Reads and clears the flag in one step — it only ever matters for
  /// the single next launch it's read on; leaving it set after that
  /// would incorrectly reroute a much later launch too, long after the
  /// user has since signed in or rebuilt normally.
  Future<bool> consumeJustSignedOutFlag() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getBool(_justSignedOutKey) ?? false;
    if (value) await prefs.remove(_justSignedOutKey);
    return value;
  }

  /// Called as soon as the sign-out is actually resolved (a successful
  /// sign-in, or "Set up again" completing) — in-session, before any
  /// relaunch ever reads the flag. Without this, signing back in
  /// normally and using the app for weeks would still leave a stale
  /// flag on disk, waiting to incorrectly reroute the next unrelated
  /// relaunch.
  Future<void> clearJustSignedOutFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_justSignedOutKey);
  }
}
