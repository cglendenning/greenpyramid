import 'package:flutter/foundation.dart' show debugPrint;

import 'ai_guard.dart';
import 'council_client.dart';
import 'db.dart';

/// D-168: see [NewsfeedService.generateArticleOnDemand].
enum OnDemandArticleOutcome { generated, notEntitled, dailyCapReached, failed }

/// D-170: the newsfeed, narrowed. Owner: "I only want #3 and #4. Get rid
/// of both #1 and #2" — #1 and #2 being streak-milestone and essence-
/// change cards (D-150/D-154/D-165's original free tier), #3 and #4
/// being the five static sample cards (D-168) and the AI-written article
/// (D-155/D-168). The stated reason wasn't a data-accuracy complaint —
/// the owner found the jargon itself ("essence card," "streak card")
/// opaque, and once it was explained plainly, decided they simply don't
/// want that content in the feed at all. `_generateStreakItems`,
/// `_generateEssenceItems`, `humanElapsed`, and the `NewNewsfeedItem`
/// notification-return machinery that existed only to support them are
/// deleted outright, not left dormant — nothing calls them and nothing
/// should.
class NewsfeedService {
  NewsfeedService({DatabaseHelper? db, CouncilClient? client})
      : _db = db ?? DatabaseHelper.instance,
        _client = client ?? CouncilClient.instance;

  static final NewsfeedService instance = NewsfeedService();

  final DatabaseHelper _db;
  final CouncilClient _client;

  // D-168: five fixed, hand-written cards seeded exactly once, the very
  // first time the newsfeed has nothing else in it yet — replaces
  // D-154's two generic "welcome" cards entirely. Each shows what a
  // real AI-written analysis card looks like (same shape as the actual
  // entitled-only article: a trend-shaped headline, an analytical body)
  // but built from illustrative, non-personal content, never the
  // account's own data — the whole point is to preview the format
  // itself, not fabricate a claim about the user's real trends. Text is
  // deliberately written in the abstract ("your categories," "a real
  // analysis would...") so nothing here could be mistaken for a genuine
  // finding. The SAMPLE label, and the subscribe pitch beneath each
  // body, are rendered by NewsfeedScreen itself (type == 'sample'), not
  // stored here — identical on all five, so there's nothing to
  // duplicate-store per card.
  static const _sampleCopy = [
    (
      'Your Foundational Habits Are Carrying The Rest',
      "In a real analysis, we'd look at which of your six categories is "
          "quietly doing the most work. Often it's a foundational value — "
          "the ones at the base of your pyramid — showing the highest and "
          "steadiest completion rate, while values higher up ride on that "
          "consistency. An analysis like this would name exactly which "
          "category that is for you, and what it's protecting.",
    ),
    (
      'One Category Is Quietly Slipping',
      "Real analysis doesn't just celebrate what's working — it flags "
          "what's fading before it becomes a pattern you can't see from "
          "inside it. This kind of card would name your most-missed "
          "category over the last 30 days, and the exact week it started "
          "slipping, so you can catch it early instead of after the fact.",
    ),
    (
      'Your Longest Streak Is Now Your Identity',
      "Once a streak crosses a certain length, it stops being effort and "
          "starts being who you are. A real analysis would tell you "
          "exactly which of your habits has crossed that line for you — "
          "and how long you've actually been the kind of person who does "
          "it, whether you've noticed or not.",
    ),
    (
      'Two Values Are Moving Together',
      "Sometimes progress in one category quietly drives progress in "
          "another — showing up for one value making the next one easier. "
          "A real analysis compares your categories against each other "
          "and calls out pairs like this: which one is pulling the other "
          "up, and where that link might break if you let it.",
    ),
    (
      'This Week vs. Last Week: The Real Story',
      "A single day doesn't tell you much. A real analysis compares "
          "this week's completion against last week's, across every "
          "category, and tells you plainly whether you're actually "
          "building momentum or just staying level — the kind of honest "
          "comparison that's hard to make for yourself in the moment.",
    ),
  ];

  /// D-170: the newsfeed's only remaining "ambient" content — seeds the
  /// five sample cards the first time the newsfeed has nothing else in
  /// it yet. Idempotent and safe to call repeatedly (checks the first
  /// sample card's own existence directly, the same self-limiting
  /// pattern D-158 originally established for the welcome cards this
  /// replaced). Streak and essence generation used to run here too —
  /// removed outright, not merely stopped, per the owner's explicit "I
  /// don't want essence cards AT ALL... get rid of both #1 and #2."
  Future<void> seedSampleCardsIfNeeded() async {
    if (!await _db.newsfeedItemExists('sample-1')) {
      await _seedSampleCards();
    }
  }

  // D-168: unlike D-158's welcome cards, these are seeded at "now" with
  // no artificial backdating — the owner's own choice, since these carry
  // a real subscribe pitch and should age naturally alongside real
  // content rather than being deliberately buried. Spaced one second
  // apart from each other purely so they sort in a stable, deterministic
  // order (oldest-drafted first) rather than relying on insert order
  // alone.
  Future<void> _seedSampleCards() async {
    final now = DateTime.now();
    for (var i = 0; i < _sampleCopy.length; i++) {
      final (title, body) = _sampleCopy[i];
      await _db.insertNewsfeedItem(
        type: 'sample',
        title: title,
        body: body,
        dedupeKey: 'sample-${i + 1}',
        createdAt: now.subtract(Duration(seconds: _sampleCopy.length - i)),
      );
    }
  }

  /// One page of the feed, newest first — [offset] pages back through
  /// history so the screen can scroll back as far as it exists (the
  /// owner's own ask), not just show a fixed recent window.
  Future<List<Map<String, dynamic>>> getFeed({
    int limit = 20,
    int offset = 0,
  }) {
    return _db.queryNewsfeedItems(limit: limit, offset: offset);
  }

  /// D-154: how far back a specific item sits in the feed's own
  /// newest-first order — how a notification tap knows how much of the
  /// feed to load before it can scroll straight to that item.
  Future<int?> getItemPosition(String dedupeKey) =>
      _db.getNewsfeedItemPosition(dedupeKey);

  /// D-155: a Claude-written "news article" analyzing consistency trends
  /// across the whole pyramid — owner: "I want you to produce something
  /// through AI that maps to the headline and make it like an analysis
  /// shaped as a news article ... if there is a trend that has emerged
  /// where one particular domain is very consistent than maybe the
  /// headline is something like increased consistency drives growth."
  /// At most one per calendar day (the owner's own chosen cadence), and
  /// only for an entitled account (matching the Council/Profile-analysis
  /// precedent — this is a genuine, non-free AI call). Both the daily
  /// cap and the entitlement check happen *before* gathering stats or
  /// calling the AI, so a day that already has its article, or an
  /// unentitled account, never does that work just to have it discarded.
  /// Best-effort: any failure (budget, spend cap, network) is swallowed
  /// — this is a background enhancement, never something the user should
  /// see an error about, the same "advisory, never required" discipline
  /// D-048's domain-finding capture already established.
  Future<void> generateArticleIfDue() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final dedupeKey = 'article-$today';
    if (await _db.newsfeedItemExists(dedupeKey)) return;

    final account = await _db.getAccountState();
    final entitlement = account[DatabaseHelper.columnEntitlement] as String?;
    final entitled = entitlement == 'trialing' || entitlement == 'subscribed';
    if (!entitled) return;

    await _generateAndInsertArticle(dedupeKey: dedupeKey);
  }

  /// D-168: the shared generation+insert step behind both the automatic
  /// daily article and an on-demand one — identical AI call, identical
  /// best-effort swallow of any failure (spend cap, network, a malformed
  /// reply), the only difference between callers is which dedupeKey they
  /// pass and what pre-check (due-today vs entitlement-and-cap) gated
  /// reaching this point at all. Returns whether a real article was
  /// actually inserted.
  Future<bool> _generateAndInsertArticle({required String dedupeKey}) async {
    try {
      final categories = await queryCategoryStats();
      await AiGuard.instance.acquire();
      final article = await _client.deriveNewsfeedArticle(categories: categories);
      if (article.headline.isEmpty || article.body.isEmpty) return false;
      await _db.insertNewsfeedItem(
        type: 'article',
        title: article.headline,
        body: article.body,
        dedupeKey: dedupeKey,
      );
      return true;
    } catch (e) {
      debugPrint('NewsfeedService: article generation skipped: $e');
      return false;
    }
  }

  /// D-168: how many on-demand articles a subscriber may generate in one
  /// calendar day, on top of (never instead of) the one automatic daily
  /// article — owner: "I also want subscribed users to be able to
  /// generate a new news item on demand in addition to the news item
  /// that gets generated automatically once per day." A small fixed cap
  /// rather than unlimited, so a single subscriber tapping repeatedly
  /// can't run up unbounded AI spend in one sitting — still backstopped
  /// by the account-wide spend cap (D-087) regardless.
  static const int onDemandDailyCap = 3;

  static String _onDemandKeyPrefix(String today) => 'article-$today-manual-';

  /// D-168: the result of one on-demand generation attempt, specific
  /// enough for the UI to react correctly — a locked paywall prompt for
  /// [notEntitled], a "come back tomorrow" style message for
  /// [dailyCapReached], vs. [failed]'s generic best-effort miss (spend
  /// cap, network, a malformed reply — nothing actionable to tell the
  /// user beyond "try again").
  Future<OnDemandArticleOutcome> generateArticleOnDemand() async {
    final account = await _db.getAccountState();
    final entitlement = account[DatabaseHelper.columnEntitlement] as String?;
    final entitled = entitlement == 'trialing' || entitlement == 'subscribed';
    if (!entitled) return OnDemandArticleOutcome.notEntitled;

    final today = DateTime.now().toIso8601String().substring(0, 10);
    final prefix = _onDemandKeyPrefix(today);
    final usedToday = await _db.countNewsfeedItemsWithDedupeKeyPrefix(prefix);
    if (usedToday >= onDemandDailyCap) {
      return OnDemandArticleOutcome.dailyCapReached;
    }

    final dedupeKey = '$prefix${usedToday + 1}';
    final inserted = await _generateAndInsertArticle(dedupeKey: dedupeKey);
    return inserted ? OnDemandArticleOutcome.generated : OnDemandArticleOutcome.failed;
  }

  /// D-168: how many on-demand generations are left today — lets the UI
  /// show/disable the "Generate new analysis" button without attempting
  /// a generation just to find out it would be refused.
  Future<int> onDemandArticlesRemainingToday() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final usedToday = await _db
        .countNewsfeedItemsWithDedupeKeyPrefix(_onDemandKeyPrefix(today));
    return (onDemandDailyCap - usedToday).clamp(0, onDemandDailyCap);
  }

  /// D-155: 7-day and 30-day completion percentage, current streak, and
  /// essence per category — the exact data the news-article prompt
  /// compares to find a trend. Exposed (not private) so it's directly
  /// testable without needing a live AI call.
  Future<List<Map<String, dynamic>>> queryCategoryStats() async {
    final summary = await _db.queryPyramidSummary();
    final stats = <Map<String, dynamic>>[];
    for (final category in summary) {
      final name = category['name'] as String;
      stats.add({
        'name': name,
        'pct7': await _db.getCompletionPercentage(name, 6),
        'pct30': await _db.getCompletionPercentage(name, 29),
        'streak': await _db.getCurrentStreak(name),
        'essence': category['essence'],
      });
    }
    return stats;
  }
}
