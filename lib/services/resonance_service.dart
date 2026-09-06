/// D-026: ported as-is, AI-free, from Kansei's `ResonanceService`
/// (`goal-executor/lib/services/resonance_service.dart`). Used to judge
/// whether a captured essence has actually landed (P-12) before accepting
/// it, rather than accepting the first thing the user types.
///
/// Only the scoring heuristic is ported — Kansei's resurfacing/cooldown
/// logic (`eligibleProbability`, `shouldSurface`, `select`) is a separate
/// feature (Rekindle) with no equivalent directive in this specification,
/// so it stays behind.
class ResonanceService {
  static const int minStatementLength = 40;

  // Deliberately no AI classification call here (P-2/D-026 cost-control
  // default) — a length + first-person-conviction heuristic is enough to
  // judge whether an essence has landed.
  static const _convictionMarkers = [
    'because', 'i want', 'i need', "matters to me", "don't want to",
    'proud', 'scared', 'afraid', 'promise', 'refuse',
  ];

  /// Heuristic 0–1 score for whether free text is a genuine,
  /// conviction-loaded statement, as opposed to logistics or a short reply.
  /// 0 means it doesn't qualify at all.
  static double score(String text) {
    final trimmed = text.trim();
    if (trimmed.length < minStatementLength) return 0.0;
    double s = (trimmed.length / 200).clamp(0.0, 1.0) * 0.6;
    final lower = trimmed.toLowerCase();
    final matches = _convictionMarkers.where((m) => lower.contains(m)).length;
    s += (matches * 0.15).clamp(0.0, 0.4);
    return s.clamp(0.0, 1.0);
  }

  static bool qualifies(String text) => score(text) > 0.0;
}
