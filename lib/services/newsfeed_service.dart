import 'package:flutter/foundation.dart' show debugPrint;

import 'ai_guard.dart';
import 'council_client.dart';
import 'db.dart';

/// D-154: one genuinely new item this generation pass created — never
/// returned for a duplicate (dedupeKey already existed) or for the
/// seeded welcome cards, since neither is something worth firing a local
/// notification for. Callers that care about notifying (tasklist.dart,
/// editpyramid.dart — the two places real milestones/essence changes are
/// actually created) use this; NewsfeedScreen's own call ignores it,
/// since the user is already looking at the feed.
typedef NewNewsfeedItem = ({String title, String body, String dedupeKey});

/// D-168: see [NewsfeedService.generateArticleOnDemand].
enum OnDemandArticleOutcome { generated, notEntitled, dailyCapReached, failed }

/// D-165: a human-scaled, bucketed phrase for how long ago something
/// happened — "3 days", "6 weeks", "4 months", "2 years" — never an exact
/// day count, which would read clinical rather than like a real sentence
/// a person would actually say. Pure and top-level so it's directly
/// testable without a live database.
String humanElapsed(Duration d) {
  final days = d.inDays;
  if (days < 1) return 'Less than a day';
  if (days < 14) return days == 1 ? '1 day' : '$days days';
  if (days < 60) {
    final weeks = (days / 7).round();
    return weeks <= 1 ? '1 week' : '$weeks weeks';
  }
  if (days < 365) {
    final months = (days / 30).round();
    return months <= 1 ? '1 month' : '$months months';
  }
  final years = (days / 365).round();
  return years <= 1 ? '1 year' : '$years years';
}

/// D-150: a personal newsfeed generated entirely from the user's own data
/// already on-device — never sent anywhere, never fetched from a server.
/// Owner: "create a newsfeed that is generated from the users own personal
/// information and that way it creates the stickiness ... it's news about
/// their own universe that has some useful benefit to them ... they can
/// scroll back as far as they want in their newsfeed and see previous
/// items that have cropped up." Scoped for a first version to the two item
/// types computable deterministically from data already in SQLite, with no
/// new AI/network cost: streak milestones and essence changes. Richer,
/// Council-authored reflections are an intentional fast-follow (D-150's
/// spec section names it explicitly), not attempted here.
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

  // Fired once per category the first time its current streak reaches
  // each of these lengths. Kept short and round — "you did something 3
  // days in a row" already reads as a real milestone; nothing here claims
  // otherwise by picking an oddly precise number.
  static const List<int> streakMilestones = [3, 7, 14, 30, 60, 100, 200, 365];

  /// Scans current state and inserts any newly-earned newsfeed items,
  /// returning only the genuinely new ones (never a duplicate, never a
  /// seeded welcome card) for a caller that wants to notify about them.
  /// Idempotent and safe to call repeatedly — each item's dedupeKey is
  /// unique, so an already-recorded milestone or essence version is
  /// silently skipped, never duplicated or returned twice.
  Future<List<NewNewsfeedItem>> generateNewItems() async {
    final categories = await _db.queryPyramidSummary();
    final newItems = <NewNewsfeedItem>[];
    for (final category in categories) {
      final id = category['id'] as int;
      final name = category['name'] as String;
      newItems.addAll(
          await _generateStreakItems(categoryId: id, categoryName: name));
    }
    newItems.addAll(await _generateEssenceItems(categories: categories));

    // D-168: seed the five sample cards the first time the newsfeed has
    // nothing else in it yet — checks the first sample card's own
    // existence directly (the same self-limiting pattern D-158
    // established for the welcome cards this replaces), so it survives
    // a targeted migration wipe on an account that already has real
    // content, not just a genuinely empty table.
    if (!await _db.newsfeedItemExists('sample-1')) {
      await _seedSampleCards();
    }

    return newItems;
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

  // D-154: rewritten from a single flat sentence per milestone to a
  // punchier, per-milestone headline ("more like a post on x.com" — the
  // owner's own words) plus a short reflective body. Each entry is
  // (headline, body) — headline stays short and declarative like a real
  // post; body is a sentence or two of reflection, not a full essay,
  // since the card itself (not the copy alone) is what needed to feel
  // more substantial.
  static final Map<int, (String, String)> _streakCopy = {
    3: (
      '3 days on {cat}.',
      "Three days straight — the hardest part, the start, is already behind you."
    ),
    7: (
      'One week of {cat}. Done.',
      'Seven days in a row. A full week where you showed up for what you said mattered.'
    ),
    14: (
      'Two weeks straight on {cat}.',
      "Fourteen days. This isn't a burst of motivation anymore — it's becoming who you are."
    ),
    30: (
      '30 days on {cat}.',
      'A full month, every day. That\'s not a habit forming — that\'s a habit formed.'
    ),
    60: (
      '60 days straight. {cat}.',
      'Two months without a gap. Most people never get here.'
    ),
    100: (
      '100 days on {cat}.',
      'Triple digits. A hundred days of choosing this, one at a time.'
    ),
    200: (
      '200 days straight on {cat}.',
      'Two hundred days in. This is just what you do now.'
    ),
    365: (
      'One year on {cat}.',
      'Three hundred sixty-five days, built on a single, repeated choice.'
    ),
  };

  Future<List<NewNewsfeedItem>> _generateStreakItems({
    required int categoryId,
    required String categoryName,
  }) async {
    final newItems = <NewNewsfeedItem>[];
    final streak = await _db.getCurrentStreak(categoryName);
    for (final milestone in streakMilestones) {
      if (streak < milestone) break;
      final copy = _streakCopy[milestone]!;
      final title = copy.$1.replaceAll('{cat}', categoryName);
      final body = copy.$2;
      final dedupeKey = 'streak-$categoryId-$milestone';
      final inserted = await _db.insertNewsfeedItem(
        type: 'streak',
        title: title,
        body: body,
        categoryId: categoryId,
        dedupeKey: dedupeKey,
      );
      if (inserted) {
        newItems.add((title: title, body: body, dedupeKey: dedupeKey));
      }
    }
    return newItems;
  }

  // D-165: found live — every essence version, first or fifth, produced
  // the exact same flat "{cat}, redefined." + "Here's what {cat} means to
  // you now" template, regardless of what actually happened. Owner:
  // "these cards need to read like a post that has real news based off
  // of what actually exists in the users data" — a value's FIRST
  // definition and a later REDEFINITION are genuinely different events,
  // and a redefinition's own real "news" is that something changed after
  // holding for a specific amount of time. Both facts already exist in
  // the essence history itself — no new AI call needed to surface them,
  // consistent with D-150's original scoping of this tier as zero-cost.
  Future<List<NewNewsfeedItem>> _generateEssenceItems({
    required List<Map<String, dynamic>> categories,
  }) async {
    final newItems = <NewNewsfeedItem>[];
    final namesById = {
      for (final c in categories) c['id'] as int: c['name'] as String,
    };
    final essences = await _db.queryAllCategoryEssences();
    final byCategoryId = <int, List<Map<String, dynamic>>>{};
    for (final row in essences) {
      final categoryId = row[DatabaseHelper.columnEssenceCategoryId] as int;
      (byCategoryId[categoryId] ??= []).add(row);
    }

    for (final rows in byCategoryId.values) {
      // Oldest first, so index 0 is genuinely the category's first-ever
      // essence and each later row's "previous version" is unambiguous.
      rows.sort((a, b) => (a[DatabaseHelper.columnEssenceCreated] as String)
          .compareTo(b[DatabaseHelper.columnEssenceCreated] as String));

      for (var i = 0; i < rows.length; i++) {
        final row = rows[i];
        final essenceId = row[DatabaseHelper.columnEssenceId] as int;
        final categoryId = row[DatabaseHelper.columnEssenceCategoryId] as int;
        final text = row[DatabaseHelper.columnEssenceText] as String;
        final categoryName = namesById[categoryId];
        if (categoryName == null) continue; // category since renamed/removed

        final String title;
        final String body;
        final thisCreated =
            DateTime.parse(row[DatabaseHelper.columnEssenceCreated] as String);
        // The essence text itself is the owner's own words and stays
        // verbatim, never rewritten — only the framing around it changes.
        if (i == 0) {
          title = '$categoryName, defined.';
          body = "You just turned $categoryName from a name into "
              "something real. Here's what it means to you:\n\n$text";
        } else {
          final previousCreated = DateTime.parse(
              rows[i - 1][DatabaseHelper.columnEssenceCreated] as String);
          final elapsed = humanElapsed(thisCreated.difference(previousCreated));
          title = '$categoryName, redefined.';
          body = "$elapsed after the last time, you've changed how you "
              "see $categoryName. Here's what it means to you "
              "now:\n\n$text";
        }

        final dedupeKey = 'essence-$essenceId';
        // D-169: found live — a full newsfeed regeneration (D-168's own
        // backfill) stamped every card with the moment it was
        // *regenerated*, not the essence's own real creation date, so a
        // genuinely days-old essence rendered as "You just turned..."
        // dated today. createdAt now carries the essence row's own real
        // [columnEssenceCreated] through, so the card's date always
        // reflects when the change actually happened, regardless of
        // when the cache last rebuilt.
        final inserted = await _db.insertNewsfeedItem(
          type: 'essence',
          title: title,
          body: body,
          categoryId: categoryId,
          dedupeKey: dedupeKey,
          createdAt: thisCreated,
        );
        if (inserted) {
          newItems.add((title: title, body: body, dedupeKey: dedupeKey));
        }
      }
    }
    return newItems;
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
