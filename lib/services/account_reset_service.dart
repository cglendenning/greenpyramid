import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// D-098: whenever local storage shows no real pyramid but this
/// (Keychain-persisted) anonymous account already has *any* prior
/// server-side data, that combination can only follow a genuine app
/// deletion and reinstall — local storage is wiped by the OS on deletion,
/// but the Firebase anonymous credential survives independently in
/// Keychain and reconnects to the same account on relaunch. There is no
/// OS-level "the app was deleted" signal to observe directly; this is the
/// closest available proxy, and it cannot false-positive on a force-quit
/// or crash, since neither of those ever wipes local storage — only a
/// real uninstall does.
///
/// [wipeIfReinstalled] deletes every document under the account and the
/// Firebase Auth identity itself, so the next sign-in is a genuinely new
/// anonymous account with zero history — not a data reset under the same
/// UID. Owns its own anonymous-only safety check internally (never
/// trusts a caller to have already verified this) — a linked (non-
/// anonymous) account must never be touched by this, ever; those restore
/// instead (D-096).
class AccountResetService {
  AccountResetService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  static final AccountResetService instance = AccountResetService();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  // IV-D's enumerated subcollections (D-075/D-096) — kept in sync with
  // what SyncService actually writes, since this must delete everything
  // that exists, not everything that theoretically could.
  static const _subcollections = [
    'profile',
    'councilSessions',
    'essenceVersions',
    'domainFindings',
    'recentActivity',
    'tasks',
  ];

  /// Returns true if a wipe actually happened. False means either this
  /// account isn't anonymous (never touched), or it is but has no prior
  /// data at all (a genuinely new account — nothing to do).
  Future<bool> wipeIfReinstalled() async {
    final current = _auth.currentUser;
    if (current == null || !current.isAnonymous) return false;

    final uid = current.uid;
    if (!await _hasAnyData(uid)) return false;

    final userDoc = _firestore.collection('users').doc(uid);
    for (final name in _subcollections) {
      await _deleteCollection(userDoc.collection(name));
    }
    await userDoc.delete();

    try {
      await current.delete();
    } catch (e, st) {
      // The data is already gone regardless of whether this succeeds.
      // Signing out still hands the next signInSilently() a fresh
      // identity — this only risks leaving one orphaned, empty Auth
      // record behind, never re-exposing the deleted data.
      debugPrint('AccountResetService: Auth identity deletion failed, '
          'signing out instead: $e\n$st');
      await _auth.signOut();
    }
    return true;
  }

  Future<bool> _hasAnyData(String uid) async {
    final userDoc = _firestore.collection('users').doc(uid);
    final rootSnap = await userDoc.get();
    if (rootSnap.exists && (rootSnap.data()?.isNotEmpty ?? false)) return true;
    for (final name in _subcollections) {
      final snap = await userDoc.collection(name).limit(1).get();
      if (snap.docs.isNotEmpty) return true;
    }
    return false;
  }

  Future<void> _deleteCollection(
      CollectionReference<Map<String, dynamic>> col) async {
    final snap = await col.get();
    if (snap.docs.isEmpty) return;
    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
