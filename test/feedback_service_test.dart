import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/services/feedback_service.dart';

/// D-129: app feedback is a structured, category-first write to the user's
/// own Firestore tree — never a freeform mailto form, and never readable by
/// anyone but the account itself (client-side) or the Admin SDK (Craig, via
/// the Firebase console). Tested against a fake Firestore and a mocked
/// Firebase Auth user, no live project.
void main() {
  const uid = 'feedback-uid';

  FeedbackService buildService(FakeFirebaseFirestore firestore) {
    final auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: uid, isAnonymous: true),
    );
    return FeedbackService(firestore: firestore, auth: auth);
  }

  test(
      'D-129: submitting with only a category selected (no comment) writes '
      'a document — a category alone is a complete, valid submission',
      () async {
    final firestore = FakeFirebaseFirestore();
    final svc = buildService(firestore);

    await svc.submit(
      category: FeedbackCategory.bug,
      appVersion: '1.44.1',
      buildNumber: '45',
      platform: 'ios',
    );

    final docs = await firestore.collection('users').doc(uid).collection('feedback').get();
    expect(docs.docs, hasLength(1));
    final data = docs.docs.first.data();
    expect(data['category'], 'bug');
    expect(data['comment'], '');
    expect(data['appVersion'], '1.44.1');
    expect(data['buildNumber'], '45');
    expect(data['platform'], 'ios');
  });

  test(
      'D-129: category is always written as one of the fixed wire values, '
      'never arbitrary text — regression for "isn\'t freeform text either"',
      () async {
    final firestore = FakeFirebaseFirestore();
    final svc = buildService(firestore);

    for (final category in FeedbackCategory.values) {
      await svc.submit(
        category: category,
        appVersion: '1.44.1',
        buildNumber: '45',
        platform: 'android',
      );
    }

    final docs = await firestore.collection('users').doc(uid).collection('feedback').get();
    final writtenCategories = docs.docs.map((d) => d.data()['category']).toSet();
    expect(writtenCategories, {'bug', 'idea', 'confusing', 'love_it'});
  });

  test(
      'D-129: a comment past the 140-character cap is rejected even if a '
      'caller bypasses the TextField\'s own client-side limit', () async {
    final firestore = FakeFirebaseFirestore();
    final svc = buildService(firestore);

    expect(
      () => svc.submit(
        category: FeedbackCategory.idea,
        comment: 'x' * 141,
        appVersion: '1.44.1',
        buildNumber: '45',
        platform: 'ios',
      ),
      throwsArgumentError,
    );
    final docs = await firestore.collection('users').doc(uid).collection('feedback').get();
    expect(docs.docs, isEmpty, reason: 'the rejected submission must not be written');
  });

  test(
      'D-129: a submission writes only into the signed-in user\'s own tree '
      '(users/{uid}/feedback), never a shared top-level collection',
      () async {
    final firestore = FakeFirebaseFirestore();
    final svc = buildService(firestore);

    await svc.submit(
      category: FeedbackCategory.loveIt,
      comment: 'The pyramid view is great.',
      appVersion: '1.44.1',
      buildNumber: '45',
      platform: 'ios',
    );

    final topLevel = await firestore.collection('feedback').get();
    expect(topLevel.docs, isEmpty);
    final nested = await firestore.collection('users').doc(uid).collection('feedback').get();
    expect(nested.docs, hasLength(1));
  });
}
