import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/services/billing_service.dart';

void main() {
  BillingService buildService(FakeFirebaseFirestore firestore) {
    final auth = MockFirebaseAuth(
        signedIn: true, mockUser: MockUser(uid: 'u1', isAnonymous: true));
    return BillingService(firestore: firestore, auth: auth);
  }

  group('D-061: spend status is read from the same document the backend '
      'writes to', () {
    test('D-061: no profile doc yet — reports zero spend at the default cap',
        () async {
      final svc = buildService(FakeFirebaseFirestore());
      final status = await svc.getSpendStatus(now: DateTime(2026, 3, 1));
      expect(status?.totalSpendUsd, 0);
      expect(status?.spendCapUsd, BillingService.defaultSpendCapUsd);
      expect(status?.atLimit, isFalse);
    });

    test('D-061: reflects the current month\'s recorded spend', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore
          .collection('users')
          .doc('u1')
          .collection('profile')
          .doc('main')
          .set({'totalSpendUsd': 3.5, 'spendMonthKey': '2026-03'});
      final svc = buildService(firestore);

      final status = await svc.getSpendStatus(now: DateTime(2026, 3, 15));
      expect(status?.totalSpendUsd, 3.5);
    });

    test('D-061: a prior month\'s spend is treated as stale, not carried '
        'forward', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore
          .collection('users')
          .doc('u1')
          .collection('profile')
          .doc('main')
          .set({'totalSpendUsd': 5.0, 'spendMonthKey': '2026-02'});
      final svc = buildService(firestore);

      final status = await svc.getSpendStatus(now: DateTime(2026, 3, 1));
      expect(status?.totalSpendUsd, 0);
    });

    test('D-061: a per-account spendCapUsd override is reflected', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore
          .collection('users')
          .doc('u1')
          .collection('profile')
          .doc('main')
          .set({'spendCapUsd': 10.0, 'spendMonthKey': '2026-03', 'totalSpendUsd': 8.0});
      final svc = buildService(firestore);

      final status = await svc.getSpendStatus(now: DateTime(2026, 3, 1));
      expect(status?.spendCapUsd, 10.0);
      expect(status?.atLimit, isFalse);
    });

    test('D-061: atLimit is true once spend reaches the cap', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore
          .collection('users')
          .doc('u1')
          .collection('profile')
          .doc('main')
          .set({'totalSpendUsd': 5.0, 'spendMonthKey': '2026-03'});
      final svc = buildService(firestore);

      final status = await svc.getSpendStatus(now: DateTime(2026, 3, 1));
      expect(status?.atLimit, isTrue);
    });

    test('D-061: reports outstanding server reservations and available allowance', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('u1').collection('profile').doc('main').set({
        'totalSpendUsd': 3.0,
        'spendCapUsd': 5.0,
        'spendMonthKey': '2026-03',
        'spendReservations': {
          'r1': {'amountUsd': 1.25},
          'r2': {'amountUsd': 0.5},
        },
      });
      final status = await buildService(firestore).getSpendStatus(now: DateTime(2026, 3, 15));
      expect(status?.reservedSpendUsd, 1.75);
      expect(status?.availableSpendUsd, 0.25);
    });
  });
}
