import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/services/ai_guard.dart';
import 'package:life_ops/services/council_client.dart';
import 'package:life_ops/services/db.dart';
import 'package:life_ops/services/newsfeed_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _TempPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _TempPathProvider(this.dir);
  final String dir;
  @override
  Future<String?> getApplicationDocumentsPath() async => dir;
}

/// D-155: a fake standing in for the real network call — same
/// implements-plus-noSuchMethod pattern account_link_service_test.dart's
/// own fakes already use in this codebase.
class _FakeCouncilClient implements CouncilClient {
  int callCount = 0;
  List<Map<String, dynamic>>? lastCategories;
  Object? throwOnCall;
  ({String headline, String body}) response =
      (headline: 'Increased Consistency Drives Growth', body: 'Body text.');

  @override
  Future<({String body, String headline})> deriveNewsfeedArticle({
    required List<Map<String, dynamic>> categories,
  }) async {
    callCount++;
    lastCategories = categories;
    final toThrow = throwOnCall;
    if (toThrow != null) throw toThrow;
    return response;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// D-150: a personal newsfeed generated entirely from data already on the
/// device — found live, owner: "create a newsfeed that is generated from
/// the users own personal information ... they can scroll back as far as
/// they want in their newsfeed and see previous items that have cropped
/// up." Same in-memory-sqlite test harness r3_schema_test.dart already
/// established for a real, migration-backed table.
void main() {
  final db = DatabaseHelper.instance;
  final service = NewsfeedService.instance;
  late Directory tempDir;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('gp_newsfeed_test');
    PathProviderPlatform.instance = _TempPathProvider(tempDir.path);
    SharedPreferences.setMockInitialValues({});
    AiGuard.instance.resetForTest();
  });
  tearDown(() async {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> seedCategory(int id, String name) async {
    await db.insertCategory({
      DatabaseHelper.columnCategoryId: id,
      DatabaseHelper.columnCat: name,
      DatabaseHelper.columnPosition: id,
    });
  }

  Future<void> logDay(String category, String date, {required bool checked}) async {
    await db.insertTaskLog({
      DatabaseHelper.columnTLCategory: category,
      DatabaseHelper.columnTLTaskDescription: 'Run',
      DatabaseHelper.columnTLChecked: checked.toString(),
      DatabaseHelper.columnTLTaskDate: date,
    });
  }

  group('D-150: the newsfeed_item table', () {
    test('exists with its documented columns', () async {
      final d = await db.database;
      final info = await d.rawQuery(
          'PRAGMA table_info(${DatabaseHelper.newsfeedItemTable})');
      final cols = info.map((c) => c['name'] as String).toSet();
      expect(
          cols,
          containsAll([
            DatabaseHelper.columnNewsfeedType,
            DatabaseHelper.columnNewsfeedTitle,
            DatabaseHelper.columnNewsfeedBody,
            DatabaseHelper.columnNewsfeedCategoryId,
            DatabaseHelper.columnNewsfeedCreated,
            DatabaseHelper.columnNewsfeedDedupeKey,
          ]));
    });

    test('applyV12Schema is idempotent — re-running it does not error or '
        'duplicate anything', () async {
      final d = await db.database;
      await DatabaseHelper.applyV12Schema(d);
      await DatabaseHelper.applyV12Schema(d);
      await db.insertNewsfeedItem(
        type: 'streak',
        title: 't',
        body: 'b',
        dedupeKey: 'k1',
      );
      final rows = await d.query(DatabaseHelper.newsfeedItemTable);
      expect(rows.length, 1);
    });

    test('dedupeKey is unique — inserting the same key twice keeps only '
        'one row', () async {
      await db.insertNewsfeedItem(
          type: 'streak', title: 't1', body: 'b1', dedupeKey: 'dup');
      await db.insertNewsfeedItem(
          type: 'streak', title: 't2', body: 'b2', dedupeKey: 'dup');
      final d = await db.database;
      final rows = await d.query(DatabaseHelper.newsfeedItemTable,
          where: '${DatabaseHelper.columnNewsfeedDedupeKey} = ?', whereArgs: ['dup']);
      expect(rows.length, 1);
      expect(rows.first[DatabaseHelper.columnNewsfeedTitle], 't1',
          reason: 'the second, duplicate-key insert must be silently '
              'ignored, not overwrite the first');
    });
  });

  group('D-150: getCurrentStreak — the still-active run of consecutive '
      'checked days, ending on the most recent day with any activity', () {
    test('an unbroken run of checked days counts fully', () async {
      await logDay('Craft', '2026-09-01', checked: true);
      await logDay('Craft', '2026-09-02', checked: true);
      await logDay('Craft', '2026-09-03', checked: true);
      expect(await db.getCurrentStreak('Craft'), 3);
    });

    test('a gap (an unchecked day) resets the streak to only what follows '
        'it', () async {
      await logDay('Craft', '2026-09-01', checked: true);
      await logDay('Craft', '2026-09-02', checked: false);
      await logDay('Craft', '2026-09-03', checked: true);
      await logDay('Craft', '2026-09-04', checked: true);
      expect(await db.getCurrentStreak('Craft'), 2);
    });

    test('no logs at all is a zero streak, not an error', () async {
      expect(await db.getCurrentStreak('Nonexistent'), 0);
    });
  });

  group('D-150: NewsfeedService.generateNewItems', () {
    test('a streak milestone fires once a category reaches it, and never '
        'duplicates on a second scan', () async {
      await seedCategory(1, 'Craft');
      for (var day = 1; day <= 3; day++) {
        await logDay('Craft', '2026-09-0$day', checked: true);
      }
      await service.generateNewItems();
      await service.generateNewItems(); // must not duplicate

      final feed = await service.getFeed(limit: 50, offset: 0);
      final streakItems = feed.where((i) => i['type'] == 'streak').toList();
      expect(streakItems.length, 1,
          reason: 'only the 3-day milestone is reached, and only once');
      expect(streakItems.first['title'], contains('3 days on Craft'));
    });

    test('a category with no essence and no streak yet produces no real '
        '(streak/essence) items — only the two D-154 welcome cards seeded '
        'on this genuinely-empty first pass', () async {
      await seedCategory(1, 'Craft');
      final newItems = await service.generateNewItems();
      expect(newItems, isEmpty,
          reason: 'welcome cards are seeded directly, not returned as '
              '"new" notification-worthy items');
      final feed = await service.getFeed(limit: 50, offset: 0);
      expect(feed.map((i) => i['type']), everyElement('welcome'));
      expect(feed.length, 2);
    });

    test('an essence version produces a feed item keyed by its own row id '
        '— never duplicated on a second scan', () async {
      await seedCategory(1, 'Craft');
      await db.insertCategoryEssence(categoryId: 1, essence: 'Made by hand.');

      await service.generateNewItems();
      await service.generateNewItems();

      final feed = await service.getFeed(limit: 50, offset: 0);
      final essenceItems = feed.where((i) => i['type'] == 'essence').toList();
      expect(essenceItems.length, 1);
      expect(essenceItems.first['body'], contains('Made by hand.'),
          reason: 'the essence text itself must survive verbatim inside '
              "D-154's new lead-in copy");
    });

    test('a later, distinct essence version for the same category produces '
        'a second, separate feed item — versions are never collapsed',
        () async {
      await seedCategory(1, 'Craft');
      await db.insertCategoryEssence(categoryId: 1, essence: 'Made by hand.');
      await db.insertCategoryEssence(categoryId: 1, essence: 'Made with care.');

      await service.generateNewItems();

      final feed = await service.getFeed(limit: 50, offset: 0);
      final essenceItems = feed.where((i) => i['type'] == 'essence').toList();
      expect(essenceItems.length, 2);
    });
  });

  group('D-150: NewsfeedService.getFeed', () {
    test('pages newest-first, and offset moves back through history — the '
        "owner's own ask, to scroll back as far as it exists", () async {
      for (var i = 0; i < 5; i++) {
        await db.insertNewsfeedItem(
            type: 'streak', title: 'item $i', body: 'b', dedupeKey: 'k$i');
      }
      final firstPage = await service.getFeed(limit: 2, offset: 0);
      final secondPage = await service.getFeed(limit: 2, offset: 2);
      expect(firstPage.length, 2);
      expect(secondPage.length, 2);
      expect(firstPage.map((i) => i['dedupekey']),
          isNot(containsAll(secondPage.map((i) => i['dedupekey']))));
    });
  });

  group('D-154: generateNewItems returns only genuinely new items, for a '
      'caller that wants to fire a local notification about them', () {
    test('a newly-reached streak milestone is returned, with its own '
        'title/body/dedupeKey', () async {
      await seedCategory(1, 'Craft');
      for (var day = 1; day <= 3; day++) {
        await logDay('Craft', '2026-09-0$day', checked: true);
      }
      final newItems = await service.generateNewItems();
      final streakItems =
          newItems.where((i) => i.dedupeKey.startsWith('streak-')).toList();
      expect(streakItems.length, 1);
      expect(streakItems.first.title, contains('3 days on Craft'));
      expect(streakItems.first.dedupeKey, 'streak-1-3');
    });

    test('a repeat scan with nothing new returns an empty list, not the '
        'same items again', () async {
      await seedCategory(1, 'Craft');
      for (var day = 1; day <= 3; day++) {
        await logDay('Craft', '2026-09-0$day', checked: true);
      }
      await service.generateNewItems();
      final second = await service.generateNewItems();
      expect(second, isEmpty);
    });

    test('the seeded welcome cards are never returned as "new" — they are '
        "not real content worth a push notification", () async {
      await seedCategory(1, 'Craft');
      final newItems = await service.generateNewItems();
      expect(newItems, isEmpty);
    });
  });

  group('D-154: no emoji anywhere in generated copy — found live: "do not '
      'use emojis" in the copy used for each new item', () {
    bool containsEmoji(String s) =>
        s.runes.any((r) => r >= 0x1F300 && r <= 0x1FAFF);

    test('every streak-milestone title/body is emoji-free', () async {
      await seedCategory(1, 'Craft');
      for (var day = 1; day <= 365; day++) {
        final date = DateTime(2026, 1, 1).add(Duration(days: day));
        await logDay(
            'Craft', date.toIso8601String().substring(0, 10), checked: true);
      }
      final newItems = await service.generateNewItems();
      for (final item in newItems) {
        expect(containsEmoji(item.title), isFalse, reason: item.title);
        expect(containsEmoji(item.body), isFalse, reason: item.body);
      }
    });

    test('essence and welcome copy is emoji-free', () async {
      await seedCategory(1, 'Craft');
      await db.insertCategoryEssence(categoryId: 1, essence: 'Made by hand.');
      await service.generateNewItems();
      final feed = await service.getFeed(limit: 50, offset: 0);
      for (final item in feed) {
        expect(containsEmoji(item['title'] as String), isFalse);
        expect(containsEmoji(item['body'] as String), isFalse);
      }
    });
  });

  group('D-154: getItemPosition — how far back a specific item sits in '
      "the feed's own order, so a notification tap can load exactly that "
      'far without paging through unrelated history first', () {
    test('the newest item is at position 0; each older one increments',
        () async {
      await db.insertNewsfeedItem(
          type: 'streak', title: 't0', body: 'b', dedupeKey: 'k0');
      await db.insertNewsfeedItem(
          type: 'streak', title: 't1', body: 'b', dedupeKey: 'k1');
      await db.insertNewsfeedItem(
          type: 'streak', title: 't2', body: 'b', dedupeKey: 'k2');

      expect(await service.getItemPosition('k2'), 0);
      expect(await service.getItemPosition('k1'), 1);
      expect(await service.getItemPosition('k0'), 2);
    });

    test('a dedupeKey that does not exist returns null, not a crash',
        () async {
      expect(await service.getItemPosition('nonexistent'), isNull);
    });
  });

  group('D-155: the AI-written newsfeed article — owner: "I want you to '
      'produce something through AI that maps to the headline and make '
      'it like an analysis shaped as a news article"', () {
    late _FakeCouncilClient fakeClient;
    late NewsfeedService articleService;

    setUp(() {
      fakeClient = _FakeCouncilClient();
      articleService = NewsfeedService(db: db, client: fakeClient);
    });

    Future<void> makeEntitled() => db.setAccountEntitlement(entitlement: 'trialing');

    test('an unentitled account never calls the AI at all — D-016, same '
        'gate the Council and Profile analysis already use', () async {
      await seedCategory(1, 'Craft');
      await articleService.generateArticleIfDue();
      expect(fakeClient.callCount, 0);
      expect(await service.getFeed(limit: 50, offset: 0), isEmpty);
    });

    test('an entitled account gets one article per day, inserted with '
        "today's date in its dedupeKey", () async {
      await makeEntitled();
      await seedCategory(1, 'Craft');
      await articleService.generateArticleIfDue();

      expect(fakeClient.callCount, 1);
      final feed = await service.getFeed(limit: 50, offset: 0);
      final articles = feed.where((i) => i['type'] == 'article').toList();
      expect(articles.length, 1);
      expect(articles.first['title'], 'Increased Consistency Drives Growth');
      expect(articles.first['dedupekey'],
          startsWith('article-${DateTime.now().toIso8601String().substring(0, 10)}'));
    });

    test('a second call the same day never calls the AI again — the '
        'existence check happens before any stat-gathering or network '
        'call, not just at insert time', () async {
      await makeEntitled();
      await seedCategory(1, 'Craft');
      await articleService.generateArticleIfDue();
      await articleService.generateArticleIfDue();

      expect(fakeClient.callCount, 1);
      final feed = await service.getFeed(limit: 50, offset: 0);
      expect(feed.where((i) => i['type'] == 'article').length, 1);
    });

    test('a failure (spend cap, network, anything) is swallowed — this '
        'is a background enhancement, never something the user should '
        'see an error about', () async {
      await makeEntitled();
      await seedCategory(1, 'Craft');
      fakeClient.throwOnCall = SpendLimitException(totalSpendUsd: 5, spendCapUsd: 5);

      await articleService.generateArticleIfDue();

      final feed = await service.getFeed(limit: 50, offset: 0);
      expect(feed.where((i) => i['type'] == 'article'), isEmpty);
    });

    test('an empty headline or body from the AI is not inserted as a '
        'half-written article', () async {
      await makeEntitled();
      await seedCategory(1, 'Craft');
      fakeClient.response = (headline: '', body: 'Body text.');

      await articleService.generateArticleIfDue();

      final feed = await service.getFeed(limit: 50, offset: 0);
      expect(feed.where((i) => i['type'] == 'article'), isEmpty);
    });

    test('queryCategoryStats sends 7-day/30-day completion, streak, and '
        'essence per category — the exact comparison the news-article '
        'prompt needs to find a trend', () async {
      await makeEntitled();
      await seedCategory(1, 'Craft');
      await db.insertCategoryEssence(categoryId: 1, essence: 'Made by hand.');
      for (var day = 1; day <= 3; day++) {
        await logDay('Craft', '2026-09-0$day', checked: true);
      }

      await articleService.generateArticleIfDue();

      final sent = fakeClient.lastCategories!;
      expect(sent, hasLength(1));
      expect(sent.first['name'], 'Craft');
      expect(sent.first['essence'], 'Made by hand.');
      expect(sent.first.containsKey('pct7'), isTrue);
      expect(sent.first.containsKey('pct30'), isTrue);
      expect(sent.first['streak'], 3);
    });
  });
}
