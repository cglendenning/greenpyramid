import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/services/account_link_service.dart';
import 'package:life_ops/services/auth_service.dart';
import 'package:mock_exceptions/mock_exceptions.dart';

/// D-130: AccountLinkService.linkWithCredentialOrSwitch is the one piece
/// of D-130 testable without a live device (the actual Apple/Google SDK
/// calls in signInWithApple/signInWithGoogle can't run in a unit test).
/// Tested against firebase_auth_mocks, not a live project — same pattern
/// as account_reset_service_test.dart and auth_service_test.dart.
///
/// Every MockUser below uses a distinct uid: firebase_auth_mocks' MockUser
/// mixes in Equatable, so two MockUsers with the same field values are
/// `==` to each other and mock_exceptions' whenCalling registry (keyed by
/// object identity-via-equality) would otherwise leak one test's stubbed
/// exception into another test using an equal-looking MockUser — found
/// live while writing this file.
void main() {
  test(
      'D-130: linking succeeds normally — same uid preserved, no account '
      'switch', () async {
    // firebase_auth_mocks 0.15.2's MockUser.linkWithCredential hardcodes
    // isAnonymous: false into an internal assertion that requires it match
    // the user's actual isAnonymous, so it always throws for a real
    // anonymous MockUser — the exact case being exercised here. Same
    // library defect and the same hand-rolled-fake workaround
    // auth_service_test.dart already uses for this.
    final user = _FakeAnonymousUser('preserved-uid');
    final authService = AuthService(auth: _FakeAuthWithCurrentUser(user));
    final linkService =
        AccountLinkService(auth: _FakeAuthWithCurrentUser(user), authService: authService);

    final credential = GoogleAuthProvider.credential(idToken: 'fake-id-token');
    final result = await linkService.linkWithCredentialOrSwitch(credential);

    expect(result?.uid, 'preserved-uid');
  });

  test(
      'D-130: credential-already-in-use signs into the existing account '
      'instead of throwing past the caller — the "welcome back" path, same '
      'treatment D-096 gives a reinstall', () async {
    final anonUser = MockUser(uid: 'anon-uid-already-in-use', isAnonymous: true);
    final authForLinking = MockFirebaseAuth(signedIn: true, mockUser: anonUser);
    whenCalling(Invocation.method(#linkWithCredential, null))
        .on(anonUser)
        .thenThrow(FirebaseAuthException(code: 'credential-already-in-use'));
    final authService = AuthService(auth: authForLinking);

    // A separate mock stands in for "the existing account's" FirebaseAuth
    // behavior — AccountLinkService's fallback signInWithCredential call
    // is what this test verifies, isolated from AuthService's own guard
    // (which requires an anonymous currentUser and would otherwise reject
    // a pre-switched non-anonymous mock before the throw path is reached).
    final existingUser = MockUser(uid: 'existing-uid-already-in-use', isAnonymous: false);
    final authForFallback = MockFirebaseAuth(signedIn: true, mockUser: existingUser);
    final linkService = AccountLinkService(auth: authForFallback, authService: authService);

    final credential = GoogleAuthProvider.credential(idToken: 'fake-id-token');
    final result = await linkService.linkWithCredentialOrSwitch(credential);

    expect(result?.uid, 'existing-uid-already-in-use');
  });

  test(
      'D-130: a FirebaseAuthException other than credential-already-in-use '
      'is rethrown, not swallowed', () async {
    final anonUser = MockUser(uid: 'anon-uid-other-error', isAnonymous: true);
    final auth = MockFirebaseAuth(signedIn: true, mockUser: anonUser);
    whenCalling(Invocation.method(#linkWithCredential, null))
        .on(anonUser)
        .thenThrow(FirebaseAuthException(code: 'network-request-failed'));
    final authService = AuthService(auth: auth);
    final linkService = AccountLinkService(auth: auth, authService: authService);

    final credential = GoogleAuthProvider.credential(idToken: 'fake-id-token');
    await expectLater(
      linkService.linkWithCredentialOrSwitch(credential),
      throwsA(isA<FirebaseAuthException>().having((e) => e.code, 'code', 'network-request-failed')),
    );
  });
}

class _FakeAnonymousUser implements User {
  _FakeAnonymousUser(this.uid);

  @override
  final String uid;

  @override
  bool get isAnonymous => true;

  @override
  Future<UserCredential> linkWithCredential(AuthCredential credential) async {
    return _FakeUserCredential(this);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUserCredential implements UserCredential {
  _FakeUserCredential(this.user);

  @override
  final User? user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuthWithCurrentUser implements FirebaseAuth {
  _FakeAuthWithCurrentUser(this._user);

  final User _user;

  @override
  User? get currentUser => _user;

  @override
  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    return _FakeUserCredential(_user);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
