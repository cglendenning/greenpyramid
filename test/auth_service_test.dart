import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/services/auth_service.dart';
import 'package:mock_exceptions/mock_exceptions.dart';

/// R4: silent account creation (D-032) and in-place credential linking
/// (D-033), tested against firebase_auth_mocks rather than a live project.
void main() {
  group('D-032: anonymous authentication on first launch', () {
    test('D-032: signInSilently creates an anonymous account and returns a uid',
        () async {
      final auth = AuthService(auth: MockFirebaseAuth());
      final uid = await auth.signInSilently();
      expect(uid, isNotNull);
      expect(auth.currentUid, uid);
    });

    test('D-032: signInSilently resumes the existing account rather than '
        'creating a second one', () async {
      final mockUser = MockUser(isAnonymous: true, uid: 'existing-uid');
      final auth =
          AuthService(auth: MockFirebaseAuth(signedIn: true, mockUser: mockUser));
      final uid = await auth.signInSilently();
      expect(uid, 'existing-uid');
    });

    test('D-032: a sign-in failure never throws, and leaves the app usable '
        'locally', () async {
      final mockAuth = MockFirebaseAuth();
      whenCalling(Invocation.method(#signInAnonymously, null))
          .on(mockAuth)
          .thenThrow(FirebaseAuthException(code: 'network-request-failed'));
      final auth = AuthService(auth: mockAuth);

      final uid = await auth.signInSilently();

      expect(uid, isNull);
      expect(auth.currentUid, isNull);
    });
  });

  group('D-033: a real credential is requested only when it buys something', () {
    test('D-033: linkWithCredential refuses to run without a signed-in '
        'anonymous user', () async {
      final auth = AuthService(auth: MockFirebaseAuth());
      await expectLater(
        auth.linkWithCredential(
            EmailAuthProvider.credential(email: 'a@b.com', password: 'x')),
        throwsA(isA<StateError>()),
      );
    });

    test('D-033: linking preserves the existing uid — no new account is '
        'created', () async {
      // firebase_auth_mocks 0.15.2's MockUser.linkWithCredential hardcodes
      // isAnonymous: false into an internal assertion that requires it match
      // the user's actual isAnonymous — so it always throws for an anonymous
      // MockUser, the exact case D-033 needs to exercise. A minimal
      // hand-rolled fake sidesteps that library defect.
      final user = _FakeAnonymousUser('preserved-uid');
      final auth = AuthService(auth: _FakeAuthWithCurrentUser(user));

      final linked = await auth.linkWithCredential(
          EmailAuthProvider.credential(email: 'a@b.com', password: 'x'));

      expect(linked?.uid, 'preserved-uid');
    });
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
