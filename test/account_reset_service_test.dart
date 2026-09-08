import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/services/account_reset_service.dart';

/// D-098: whenever local storage shows no real pyramid but an anonymous
/// account already has prior server-side data, that combination can only
/// follow a genuine app deletion and reinstall (there is no OS-level
/// "app was deleted" signal — this is the closest available proxy, and it
/// cannot false-positive on a force-quit or crash, since neither wipes
/// local storage the way an actual uninstall does). The owner's explicit
/// decision: deleting the app means the whole anonymous account is gone,
/// never restored — tested here against a fake Firestore and a mocked
/// Firebase Auth user, no live project.
void main() {
  const uid = 'anon-uid';

  AccountResetService buildService(FakeFirebaseFirestore firestore, MockUser user) {
    final auth = MockFirebaseAuth(signedIn: true, mockUser: user);
    return AccountResetService(firestore: firestore, auth: auth);
  }

  test('wipeIfReinstalled returns false when the account is not anonymous '
      '— a linked account must never be touched by this, ever', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc(uid).collection('profile').doc('main')
        .set({'categories': []});
    final svc = buildService(firestore, MockUser(uid: uid, isAnonymous: false));

    expect(await svc.wipeIfReinstalled(), isFalse);
    expect((await firestore.collection('users').doc(uid).collection('profile').doc('main').get()).exists,
        isTrue,
        reason: 'data belonging to a non-anonymous account must survive untouched');
  });

  test('wipeIfReinstalled returns false when anonymous but no prior data '
      'exists at all — a genuinely new account, nothing to wipe', () async {
    final firestore = FakeFirebaseFirestore();
    final svc = buildService(firestore, MockUser(uid: uid, isAnonymous: true));
    expect(await svc.wipeIfReinstalled(), isFalse);
  });

  test('wipeIfReinstalled returns false when only an empty root user doc '
      'exists — an empty map is not "prior data"', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc(uid).set(<String, dynamic>{});
    final svc = buildService(firestore, MockUser(uid: uid, isAnonymous: true));
    expect(await svc.wipeIfReinstalled(), isFalse);
  });

  test(
      'wipeIfReinstalled deletes every enumerated subcollection and the '
      'root doc when an anonymous account has prior data — regression '
      'test for the owner\'s explicit decision: "the only activity that '
      'should delete all of that data is the act of deleting the '
      'application off of their phone"', () async {
    final firestore = FakeFirebaseFirestore();
    final userDoc = firestore.collection('users').doc(uid);
    await userDoc.set({'ttlAt': 'placeholder'});
    await userDoc.collection('profile').doc('main').set({'categories': [
      {'id': 1, 'cat': 'Health', 'position': 1}
    ]});
    await userDoc.collection('councilSessions').doc('s1').set({'type': 'setup'});
    await userDoc.collection('tasks').doc('t1').set({'taskdescription': 'Walk'});
    await userDoc.collection('essenceVersions').doc('e1').set({'essence': 'x'});
    await userDoc.collection('domainFindings').doc('d1').set({'domain': 'body'});
    await userDoc.collection('recentActivity').doc('a1').set({'checked': true});

    final svc = buildService(firestore, MockUser(uid: uid, isAnonymous: true));
    expect(await svc.wipeIfReinstalled(), isTrue);

    expect((await userDoc.get()).exists, isFalse);
    for (final name in [
      'profile', 'councilSessions', 'tasks', 'essenceVersions', 'domainFindings', 'recentActivity',
    ]) {
      final snap = await userDoc.collection(name).get();
      expect(snap.docs, isEmpty, reason: '$name must be fully deleted');
    }
  });

  test('wipeIfReinstalled returns false when there is no signed-in user '
      'at all', () async {
    final firestore = FakeFirebaseFirestore();
    final auth = MockFirebaseAuth(signedIn: false);
    final svc = AccountResetService(firestore: firestore, auth: auth);
    expect(await svc.wipeIfReinstalled(), isFalse);
  });
}
