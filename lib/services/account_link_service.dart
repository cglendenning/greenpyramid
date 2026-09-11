import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'auth_service.dart';

/// D-130: thin wrapper around the two native sign-in SDKs, kept separate
/// from [AuthService] because AuthService is deliberately UI/SDK-agnostic
/// (see its own doc comment) — this is the only place that talks to
/// `sign_in_with_apple` and `google_sign_in` directly.
class AccountLinkService {
  AccountLinkService({FirebaseAuth? auth, AuthService? authService})
      : _auth = auth ?? FirebaseAuth.instance,
        _authService = authService ?? AuthService.instance;

  static final AccountLinkService instance = AccountLinkService();

  final FirebaseAuth _auth;
  final AuthService _authService;

  /// Links the current anonymous account to a real Apple ID in place —
  /// same uid, nothing lost (AuthService.linkWithCredential, D-033). Uses
  /// a hashed nonce (Apple's recommended flow) so the identity token
  /// can't be replayed.
  ///
  /// D-136: `signInSilently()` first, defensively — D-135's eager
  /// re-anonymization right after sign-out was removed, so `currentUser`
  /// can genuinely be null here (freshly signed out, not yet acted on).
  /// `linkWithCredential` requires an existing anonymous user; this
  /// creates one lazily, exactly when it's actually needed, rather than
  /// assuming one was already provisioned somewhere upstream.
  Future<User?> signInWithApple() async {
    await _authService.signInSilently();
    final rawNonce = _generateNonce();
    final hashedNonce = _sha256ofString(rawNonce);
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );
    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      rawNonce: rawNonce,
    );
    return linkWithCredentialOrSwitch(oauthCredential);
  }

  /// Same for Google — no nonce concept in google_sign_in's flow. See
  /// [signInWithApple]'s doc comment for why `signInSilently()` comes
  /// first.
  Future<User?> signInWithGoogle() async {
    await _authService.signInSilently();
    final googleUser = await GoogleSignIn.instance.authenticate();
    final idToken = googleUser.authentication.idToken;
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    return linkWithCredentialOrSwitch(credential);
  }

  /// D-130: if this exact credential is already linked to a *different*,
  /// non-anonymous account (most likely: the user set up on a second
  /// device with the same Apple/Google identity), Firebase refuses the
  /// link with `credential-already-in-use`. The right outcome isn't an
  /// error — it's signing them into their real existing account, the
  /// same "welcome back" treatment D-096 already gives a reinstall. The
  /// fresh anonymous account being abandoned here was never synced past
  /// setup completion under its own uid, so nothing under the existing
  /// account is touched by this switch.
  ///
  /// Public (not the native-SDK entry points above) so it can be
  /// exercised directly in tests with a synthetic credential — the real
  /// Apple/Google SDK calls can't run in a unit test.
  Future<User?> linkWithCredentialOrSwitch(AuthCredential credential) async {
    try {
      return await _authService.linkWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (e.code != 'credential-already-in-use') rethrow;
      final result = await _auth.signInWithCredential(credential);
      return result.user;
    }
  }

  /// D-132: signs out of both the native Google session and Firebase.
  /// Apple has no equivalent SDK-level session to clear — Sign in with
  /// Apple's own dialog always lets the user pick an identity, so there's
  /// nothing cached client-side to invalidate the way Google's silent
  /// re-auth would otherwise bypass. Google sign-out is best-effort: if it
  /// fails, Firebase sign-out (what actually matters — Firestore access
  /// checks the Firebase session, not Google's) still proceeds.
  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (e, st) {
      debugPrint('AccountLinkService: Google sign-out failed (non-fatal): $e\n$st');
    }
    await _authService.signOut();
  }
}

String _generateNonce([int length = 32]) {
  const charset =
      '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
  final random = Random.secure();
  return List.generate(length, (_) => charset[random.nextInt(charset.length)])
      .join();
}

String _sha256ofString(String input) => sha256.convert(utf8.encode(input)).toString();
