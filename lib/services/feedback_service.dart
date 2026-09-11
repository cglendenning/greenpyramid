import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// D-129: fixed, disclosed categories — never a freeform "subject" field.
/// A user only ever picks one of these; the [FeedbackCategory.wireValue]
/// strings are what actually gets written to Firestore.
enum FeedbackCategory { bug, idea, confusing, loveIt }

extension FeedbackCategoryLabel on FeedbackCategory {
  String get label => switch (this) {
        FeedbackCategory.bug => 'Report a bug',
        FeedbackCategory.idea => 'Suggest an idea',
        FeedbackCategory.confusing => "Something's confusing",
        FeedbackCategory.loveIt => "What's working",
      };

  String get wireValue => switch (this) {
        FeedbackCategory.bug => 'bug',
        FeedbackCategory.idea => 'idea',
        FeedbackCategory.confusing => 'confusing',
        FeedbackCategory.loveIt => 'love_it',
      };
}

/// D-129: writes a single feedback document to the signed-in user's own
/// Firestore tree (`users/{uid}/feedback/{id}`). This stays inside the
/// existing D-031/D-075 model — the same per-uid rule that already governs
/// every other synced collection covers this one too, so no rules change
/// was needed. It is a disclosed, user-initiated write (the user taps
/// "Send"), not passive collection, which is what keeps it consistent with
/// D-031's "used only to serve the user who produced it": the exception
/// here is the same one every app's support/feedback channel relies on —
/// an explicit, intentional submission, never background telemetry.
class FeedbackService {
  FeedbackService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  static final FeedbackService instance = FeedbackService();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// Enforced client-side (TextField maxLength) and re-checked here so a
  /// caller bypassing the UI can't silently write past the limit.
  static const maxCommentLength = 140;

  Future<void> submit({
    required FeedbackCategory category,
    String comment = '',
    required String appVersion,
    required String buildNumber,
    required String platform,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('No signed-in user to attribute feedback to.');
    }
    final trimmed = comment.trim();
    if (trimmed.length > maxCommentLength) {
      throw ArgumentError('Comment exceeds $maxCommentLength characters.');
    }
    await _firestore.collection('users').doc(uid).collection('feedback').add({
      'category': category.wireValue,
      'comment': trimmed,
      'appVersion': appVersion,
      'buildNumber': buildNumber,
      'platform': platform,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
