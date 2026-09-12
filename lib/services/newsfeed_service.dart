import 'db.dart';

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

  // Fired once per category the first time its current streak reaches
  // each of these lengths. Kept short and round — "you did something 3
  // days in a row" already reads as a real milestone; nothing here claims
  // otherwise by picking an oddly precise number.
  static const List<int> streakMilestones = [3, 7, 14, 30, 60, 100, 200, 365];

  /// Scans current state and inserts any newly-earned newsfeed items.
  /// Idempotent and safe to call on every newsfeed-screen open — each
  /// item's dedupeKey is unique, so an already-recorded milestone or
  /// essence version is silently skipped, never duplicated.
  Future<void> generateNewItems() async {
    final categories = await _db.queryPyramidSummary();
    for (final category in categories) {
      final id = category['id'] as int;
      final name = category['name'] as String;
      await _generateStreakItems(categoryId: id, categoryName: name);
    }
    await _generateEssenceItems(categories: categories);
  }

  Future<void> _generateStreakItems({
    required int categoryId,
    required String categoryName,
  }) async {
    final streak = await _db.getCurrentStreak(categoryName);
    for (final milestone in streakMilestones) {
      if (streak < milestone) break;
      await _db.insertNewsfeedItem(
        type: 'streak',
        title: '$categoryName: $milestone-day streak',
        body: "You've kept up $categoryName $milestone days in a row. "
            "That's what living it looks like, not just planning it.",
        categoryId: categoryId,
        dedupeKey: 'streak-$categoryId-$milestone',
      );
    }
  }

  Future<void> _generateEssenceItems({
    required List<Map<String, dynamic>> categories,
  }) async {
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
      await _db.insertNewsfeedItem(
        type: 'essence',
        title: '$categoryName, redefined',
        body: text,
        categoryId: categoryId,
        dedupeKey: 'essence-$essenceId',
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
}
