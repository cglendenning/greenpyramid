import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/services/auth_service.dart';
import 'package:life_ops/services/notification_inbox_service.dart';

void main() {
  NotificationInboxService buildService(
    FakeFirebaseFirestore firestore, {
    String uid = 'u1',
  }) {
    final auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: uid, isAnonymous: true),
    );
    return NotificationInboxService(
      firestore: firestore,
      auth: AuthService(auth: auth),
    );
  }

  test('D-025/D-029: inbox reads are account-scoped and auth-gated', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc('u1').collection('inbox').add({
      'messageKey': 'owned',
      'title': 'For u1',
    });
    await firestore.collection('users').doc('u2').collection('inbox').add({
      'messageKey': 'other',
      'title': 'For u2',
    });

    final item = await buildService(firestore).findByMessageKey('owned');
    expect(item?['title'], 'For u1');
    expect(await buildService(firestore).findByMessageKey('other'), isNull);
  });

  test('D-025/D-149: inbox stream is newest-first for the authenticated uid',
      () async {
    final firestore = FakeFirebaseFirestore();
    final first = await firestore.collection('users').doc('u1').collection('inbox').add({
      'messageKey': 'older',
      'createdAt': DateTime(2026, 1, 1),
    });
    await firestore.collection('users').doc('u1').collection('inbox').add({
      'messageKey': 'newer',
      'createdAt': DateTime(2026, 1, 2),
    });
    final stream = await buildService(firestore).watchInbox();
    final snapshot = await stream!.first;
    expect(snapshot.docs.first.data()['messageKey'], 'newer');
    expect(snapshot.docs.last.id, first.id);
  });
}
