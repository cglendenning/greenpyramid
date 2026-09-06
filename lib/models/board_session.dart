import 'package:cloud_firestore/cloud_firestore.dart';

/// D-082: every Council session is typed. `setup` covers the whole pyramid
/// and exists at most once per account, ever; every session after setup is
/// `category`-typed and scoped to exactly one category (D-028).
enum BoardSessionType {
  setup,
  category;

  static BoardSessionType fromName(String? name) =>
      values.firstWhere((v) => v.name == name, orElse: () => category);
}

class BoardMessage {
  final String advisorKey;
  final String text;
  final DateTime timestamp;

  const BoardMessage({
    required this.advisorKey,
    required this.text,
    required this.timestamp,
  });

  factory BoardMessage.fromMap(Map<String, dynamic> m) => BoardMessage(
        advisorKey: m['advisorKey'] as String? ?? 'mira',
        text: m['text'] as String? ?? '',
        timestamp: m['timestamp'] is Timestamp
            ? (m['timestamp'] as Timestamp).toDate()
            : DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'advisorKey': advisorKey,
        'text': text,
        'timestamp': Timestamp.fromDate(timestamp),
      };
}

/// How the Council screen should resume when an active (incomplete) session
/// is loaded from Firestore. Kept in the model, ported from Kansei's
/// `BoardSession`, so the branching decision is unit-testable without
/// spinning up the widget.
enum BoardResumeAction {
  /// Session exists but no advisor has spoken yet — a prior session-create
  /// happened but its opening round failed (e.g. cold-start timeout). Retry
  /// the opening round so the user is never stranded on the empty state.
  retryOpeningRound,

  /// A complete round is on screen — offer to continue.
  showJoinIn,

  /// A round was interrupted mid-way — resume from the next advisor's turn.
  resumeMidRound,
}

/// D-082/D-028: a Council session, ported from Kansei's `BoardSession`
/// (II-K). `goalId` becomes `categoryId` (null for a `setup` session, which
/// is scoped to the whole pyramid rather than one category); a `type` field
/// resolves II-K mismatch 3. Rotation, resume, and history behavior are
/// otherwise unchanged from Kansei.
class BoardSession {
  final String sessionId;
  final BoardSessionType type;
  final int? categoryId;
  final DateTime createdAt;
  final DateTime lastUpdatedAt;
  final List<BoardMessage> messages;
  final List<String> rotationOrder;
  final Map<String, double> sliderSettings;
  final bool isComplete;
  final int totalInputTokens;
  final int totalOutputTokens;

  BoardSession({
    required this.sessionId,
    required this.type,
    required this.categoryId,
    required this.createdAt,
    required this.lastUpdatedAt,
    required this.messages,
    required this.rotationOrder,
    required this.sliderSettings,
    required this.isComplete,
    required this.totalInputTokens,
    required this.totalOutputTokens,
  }) : assert(
          (type == BoardSessionType.category) == (categoryId != null),
          'a category session requires a categoryId; a setup session must not carry one',
        );

  // Only advisor turns count toward round tracking — user messages are not counted.
  int get advisorMessageCount =>
      messages.where((m) => m.advisorKey != 'user').length;

  bool get isRoundComplete => advisorMessageCount % 4 == 0;
  String get nextAdvisorKey => rotationOrder[advisorMessageCount % 4];

  /// Decides how the Council screen should resume this session. An empty
  /// session (no advisor turns) must retry rather than fall through to a
  /// dead state with no button — see [BoardResumeAction.retryOpeningRound].
  BoardResumeAction get resumeAction {
    if (messages.isEmpty) return BoardResumeAction.retryOpeningRound;
    if (isRoundComplete) return BoardResumeAction.showJoinIn;
    return BoardResumeAction.resumeMidRound;
  }

  factory BoardSession.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return BoardSession(
      sessionId: doc.id,
      type: BoardSessionType.fromName(data['type'] as String?),
      categoryId: (data['categoryId'] as num?)?.toInt(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastUpdatedAt: (data['lastUpdatedAt'] as Timestamp).toDate(),
      messages: ((data['messages'] as List<dynamic>?) ?? [])
          .map((m) => BoardMessage.fromMap(m as Map<String, dynamic>))
          .toList(),
      rotationOrder: ((data['rotationOrder'] as List<dynamic>?) ??
              ['mira', 'kenji', 'noa', 'eli'])
          .cast<String>(),
      sliderSettings: ((data['sliderSettings'] as Map<String, dynamic>?) ?? {})
          .map((k, v) => MapEntry(k, (v as num).toDouble())),
      isComplete: data['isComplete'] as bool? ?? false,
      totalInputTokens: (data['totalInputTokens'] as num?)?.toInt() ?? 0,
      totalOutputTokens: (data['totalOutputTokens'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'type': type.name,
        if (categoryId != null) 'categoryId': categoryId,
        'createdAt': Timestamp.fromDate(createdAt),
        'lastUpdatedAt': Timestamp.fromDate(lastUpdatedAt),
        'messages': messages.map((m) => m.toMap()).toList(),
        'rotationOrder': rotationOrder,
        'sliderSettings': sliderSettings,
        'isComplete': isComplete,
        'totalInputTokens': totalInputTokens,
        'totalOutputTokens': totalOutputTokens,
      };

  BoardSession withMessage(BoardMessage msg) => BoardSession(
        sessionId: sessionId,
        type: type,
        categoryId: categoryId,
        createdAt: createdAt,
        lastUpdatedAt: DateTime.now(),
        messages: [...messages, msg],
        rotationOrder: rotationOrder,
        sliderSettings: sliderSettings,
        isComplete: isComplete,
        totalInputTokens: totalInputTokens,
        totalOutputTokens: totalOutputTokens,
      );
}
