import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_service.dart';

typedef NotificationInboxSnapshot = QuerySnapshot<Map<String, dynamic>>;
typedef NotificationInboxStream = Stream<NotificationInboxSnapshot>;

/// D-025/D-029/D-149: owns the account-scoped notification inbox query.
/// Screens receive typed Firestore results but never construct cloud paths or
/// touch Firestore directly. Authentication is awaited before every first
/// cloud operation so a restored session cannot race an inbox read.
class NotificationInboxService {
  NotificationInboxService({
    FirebaseFirestore? firestore,
    AuthService? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? AuthService.instance;

  static final NotificationInboxService instance =
      NotificationInboxService();

  final FirebaseFirestore _firestore;
  final AuthService _auth;

  Future<CollectionReference<Map<String, dynamic>>?> _inbox() async {
    await _auth.signInSilently();
    final uid = _auth.currentUid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('inbox');
  }

  /// Returns the live, newest-first inbox stream for the authenticated uid.
  /// A null result means authentication could not be established; no cloud
  /// query is attempted in that case.
  Future<NotificationInboxStream?> watchInbox() async {
    final inbox = await _inbox();
    return inbox?.orderBy('createdAt', descending: true).snapshots();
  }

  /// D-122-AC-05: real newsfeed articles share the account inbox as their
  /// durable record but are read in the newsfeed, never listed as
  /// notifications.
  static bool isNotification(Map<String, dynamic> item) =>
      item['type'] != 'article';

  /// D-122-AC-05: the account's persisted newsfeed articles, each with its
  /// `createdAt` converted to a [DateTime] so callers never handle
  /// Firestore types. A null result means authentication could not be
  /// established; no cloud query is attempted in that case.
  Future<List<Map<String, dynamic>>?> fetchArticles() async {
    final inbox = await _inbox();
    if (inbox == null) return null;
    final snapshot = await inbox.where('type', isEqualTo: 'article').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      final created = data['createdAt'];
      return {
        ...data,
        'createdAt': created is Timestamp
            ? created.toDate()
            : created is DateTime
                ? created
                : null,
      };
    }).toList();
  }

  /// Loads the durable notification context for one account-bound message.
  Future<Map<String, dynamic>?> findByMessageKey(String messageKey) async {
    if (messageKey.isEmpty) return null;
    final inbox = await _inbox();
    if (inbox == null) return null;
    final snapshot = await inbox
        .where('messageKey', isEqualTo: messageKey)
        .limit(1)
        .get();
    return snapshot.docs.isEmpty ? null : snapshot.docs.first.data();
  }
}
