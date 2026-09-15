import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BillingStatus {
  final double totalSpendUsd;
  final double spendCapUsd;
  final double reservedSpendUsd;
  const BillingStatus(
      {required this.totalSpendUsd,
      required this.spendCapUsd,
      this.reservedSpendUsd = 0});

  double get availableSpendUsd =>
      (spendCapUsd - totalSpendUsd - reservedSpendUsd)
          .clamp(0, double.infinity);
  bool get atLimit => availableSpendUsd <= 0;
}

/// D-061: read-only visibility into what an account has spent this month —
/// "the app needs to have the ability to see what has been spent for a
/// given user." The backend (functions/lib/billing.js) is the enforcement
/// authority; this is informational display only, read directly from the
/// same Firestore document the backend writes to.
class BillingService {
  BillingService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  static final BillingService instance = BillingService();

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  // Must match DEFAULT_SPEND_CAP_USD in functions/lib/billing.js (D-061) —
  // the two can't share a literal constant across Dart and JS.
  static const double defaultSpendCapUsd = 5.0;

  static String _monthKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  Future<BillingStatus?> getSpendStatus({DateTime? now}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final doc = await _db
        .collection('users')
        .doc(uid)
        .collection('profile')
        .doc('main')
        .get();
    final data = doc.data();

    final capUsd =
        (data?['spendCapUsd'] as num?)?.toDouble() ?? defaultSpendCapUsd;
    final storedMonth = data?['spendMonthKey'] as String?;
    // A record from a prior month is stale — the backend resets lazily on
    // the next recordCost, so a month boundary can pass with no write yet.
    final spend = storedMonth == _monthKey(now ?? DateTime.now())
        ? (data?['totalSpendUsd'] as num?)?.toDouble() ?? 0
        : 0.0;
    final reservations = storedMonth == _monthKey(now ?? DateTime.now())
        ? (data?['spendReservations'] as Map<String, dynamic>?)
        : null;
    final reserved = reservations?.values
            .map((value) => (value is Map
                ? (value['amountUsd'] as num?)?.toDouble() ?? 0
                : 0.0))
            .fold<double>(0, (sum, amount) => sum + amount) ??
        0.0;

    return BillingStatus(
        totalSpendUsd: spend, spendCapUsd: capUsd, reservedSpendUsd: reserved);
  }
}
