import 'db.dart';

/// D-154: one genuinely new item this generation pass created — never
/// returned for a duplicate (dedupeKey already existed) or for the
/// seeded welcome cards, since neither is something worth firing a local
/// notification for. Callers that care about notifying (tasklist.dart,
/// editpyramid.dart — the two places real milestones/essence changes are
/// actually created) use this; NewsfeedScreen's own call ignores it,
/// since the user is already looking at the feed.
typedef NewNewsfeedItem = ({String title, String body, String dedupeKey});

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
  NewsfeedService({DatabaseHelper? db}) : _db = db ?? DatabaseHelper.instance;

  static final NewsfeedService instance = NewsfeedService();

  final DatabaseHelper _db;

  // D-154: two fixed, hand-written cards seeded exactly once, the very
  // first time the newsfeed has nothing else in it yet — "on first
  // launch of the newsfeed, produce five of these cards." Real content
  // (essences already set during setup, plus whatever streaks/essence
  // edits follow) fills out the rest; these two are the only synthetic,
  // non-personal entries the newsfeed ever contains.
  static const _welcomeCopy = [
    (
      'Welcome to your newsfeed.',
      'This is where your own progress shows up over time — streaks you '
          'build, ways you redefine what matters to you. Nothing here comes '
          'from anywhere but your own pyramid.',
    ),
    (
      "Nothing here is generic.",
      'Every card that shows up from now on is about your own categories, '
          'your own habits, your own words. Keep showing up, and this feed '
          'fills in behind you.',
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

    // D-154: if the table is still empty even after everything real this
    // pass just generated, this is a genuine first-ever launch — seed the
    // two welcome cards. Self-limiting without a separate "was it empty
    // before this call" snapshot: once seeded, the table is never empty
    // again, so this branch can only ever fire once per install.
    if (await _db.countNewsfeedItems() == newItems.length) {
      await _seedWelcomeCards();
    }

    return newItems;
  }

  Future<void> _seedWelcomeCards() async {
    for (var i = 0; i < _welcomeCopy.length; i++) {
      final (title, body) = _welcomeCopy[i];
      await _db.insertNewsfeedItem(
        type: 'welcome',
        title: title,
        body: body,
        dedupeKey: 'welcome-${i + 1}',
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

  Future<List<NewNewsfeedItem>> _generateEssenceItems({
    required List<Map<String, dynamic>> categories,
  }) async {
    final newItems = <NewNewsfeedItem>[];
    final namesById = {
      for (final c in categories) c['id'] as int: c['name'] as String,
    };
    final essences = await _db.queryAllCategoryEssences();
    for (final row in essences) {
      final essenceId = row[DatabaseHelper.columnEssenceId] as int;
      final categoryId = row[DatabaseHelper.columnEssenceCategoryId] as int;
      final text = row[DatabaseHelper.columnEssenceText] as String;
      final categoryName = namesById[categoryId];
      if (categoryName == null) continue; // category since renamed/removed
      final title = '$categoryName, redefined.';
      // The lead-in is new copy; the essence text itself is the owner's
      // own words and stays verbatim, never rewritten.
      final body = "Here's what $categoryName means to you now:\n\n$text";
      final dedupeKey = 'essence-$essenceId';
      final inserted = await _db.insertNewsfeedItem(
        type: 'essence',
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
}
