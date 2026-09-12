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

  group('D-170: seedSampleCardsIfNeeded never produces streak or essence '
      'cards — owner: "I only want #3 and #4. Get rid of both #1 and #2," '
      '#1/#2 being streak-milestone and essence-change cards', () {
    test('a category with streak/essence-worthy history still produces '
        'only the five sample cards — nothing streak- or essence-typed',
        () async {
      await seedCategory(1, 'Craft');
      for (var day = 1; day <= 3; day++) {
        await logDay('Craft', '2026-09-0$day', checked: true);
      }
      await db.insertCategoryEssence(categoryId: 1, essence: 'Made by hand.');

      await service.seedSampleCardsIfNeeded();

      final feed = await service.getFeed(limit: 50, offset: 0);
      expect(feed.map((i) => i['type']), everyElement('sample'));
      expect(feed.where((i) => i['type'] == 'streak'), isEmpty);
      expect(feed.where((i) => i['type'] == 'essence'), isEmpty);
    });

    test('calling it twice never duplicates the five sample cards',
        () async {
      await seedCategory(1, 'Craft');
      await service.seedSampleCardsIfNeeded();
      await service.seedSampleCardsIfNeeded();

      final feed = await service.getFeed(limit: 50, offset: 0);
      expect(feed.length, 5);
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

  group('D-168: the five sample cards seed once, at "now," with no '
      'artificial backdating — replaces D-158\'s welcome-card spacing '
      'mechanism entirely, since these carry a subscribe pitch and '
      "should age naturally alongside real content rather than being "
      'deliberately buried', () {
    test('all five sample cards exist, each keyed sample-1 through '
        'sample-5', () async {
      await seedCategory(1, 'Craft');
      await service.seedSampleCardsIfNeeded();

      final feed = await service.getFeed(limit: 50, offset: 0);
      final keys = feed.map((i) => i['dedupekey'] as String).toSet();
      expect(keys, containsAll(['sample-1', 'sample-2', 'sample-3', 'sample-4', 'sample-5']));
    });

    test('after a targeted wipe of only type=welcome rows (the retired '
        "D-158/D-154 card type, deleted by D-168's own migration), the "
        'sample cards seed correctly on an account that already has '
        'plenty of real content — not just on a genuinely empty table',
        () async {
      await seedCategory(1, 'Craft');
      await db.insertCategoryEssence(categoryId: 1, essence: 'One.');
      await db.insertCategoryEssence(categoryId: 1, essence: 'Two.');
      // Simulate an account that still had old welcome rows before the
      // D-168 migration ran.
      await db.insertNewsfeedItem(
          type: 'welcome', title: 'old', body: 'old', dedupeKey: 'welcome-1');
      await service.seedSampleCardsIfNeeded();

      final d = await db.database;
      await d.delete(DatabaseHelper.newsfeedItemTable,
          where: '${DatabaseHelper.columnNewsfeedType} = ?', whereArgs: ['welcome']);

      await service.seedSampleCardsIfNeeded();

      final feed = await service.getFeed(limit: 50, offset: 0);
      final keys = feed.map((i) => i['dedupekey'] as String).toSet();
      expect(keys, containsAll(['sample-1', 'sample-2', 'sample-3', 'sample-4', 'sample-5']));
      expect(keys, isNot(contains('welcome-1')));
    });
  });

  group('D-154: no emoji anywhere in generated copy — found live: "do not '
      'use emojis" in the copy used for each new item', () {
    bool containsEmoji(String s) =>
        s.runes.any((r) => r >= 0x1F300 && r <= 0x1FAFF);

    test('sample copy is emoji-free', () async {
      await seedCategory(1, 'Craft');
      await service.seedSampleCardsIfNeeded();
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

  group('D-168: on-demand article generation — owner: "I also want '
      'subscribed users to be able to generate a new news item on '
      'demand in addition to the news item that gets generated '
      'automatically once per day"', () {
    late _FakeCouncilClient fakeClient;
    late NewsfeedService articleService;

    setUp(() {
      fakeClient = _FakeCouncilClient();
      articleService = NewsfeedService(db: db, client: fakeClient);
    });

    Future<void> makeEntitled() => db.setAccountEntitlement(entitlement: 'trialing');

    test('an unentitled account is refused before any AI call — same '
        'gate as the automatic article', () async {
      await seedCategory(1, 'Craft');
      final outcome = await articleService.generateArticleOnDemand();
      expect(outcome, OnDemandArticleOutcome.notEntitled);
      expect(fakeClient.callCount, 0);
    });

    test('an entitled account can generate on demand, with its own '
        'distinct dedupeKey — never colliding with the automatic '
        "daily article's own key", () async {
      await makeEntitled();
      await seedCategory(1, 'Craft');

      final outcome = await articleService.generateArticleOnDemand();

      expect(outcome, OnDemandArticleOutcome.generated);
      expect(fakeClient.callCount, 1);
      final feed = await service.getFeed(limit: 50, offset: 0);
      final articles = feed.where((i) => i['type'] == 'article').toList();
      expect(articles.length, 1);
      final today = DateTime.now().toIso8601String().substring(0, 10);
      expect(articles.first['dedupekey'], 'article-$today-manual-1');
    });

    test('on-demand generation and the automatic daily article coexist '
        'as two separate cards, never colliding on dedupeKey', () async {
      await makeEntitled();
      await seedCategory(1, 'Craft');

      await articleService.generateArticleIfDue();
      await articleService.generateArticleOnDemand();

      expect(fakeClient.callCount, 2);
      final feed = await service.getFeed(limit: 50, offset: 0);
      expect(feed.where((i) => i['type'] == 'article').length, 2);
    });

    test('up to onDemandDailyCap generations succeed in one day, each '
        'with its own numbered dedupeKey', () async {
      await makeEntitled();
      await seedCategory(1, 'Craft');

      for (var i = 0; i < NewsfeedService.onDemandDailyCap; i++) {
        final outcome = await articleService.generateArticleOnDemand();
        expect(outcome, OnDemandArticleOutcome.generated);
      }

      expect(fakeClient.callCount, NewsfeedService.onDemandDailyCap);
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final feed = await service.getFeed(limit: 50, offset: 0);
      final keys = feed
          .where((i) => i['type'] == 'article')
          .map((i) => i['dedupekey'] as String)
          .toSet();
      for (var i = 1; i <= NewsfeedService.onDemandDailyCap; i++) {
        expect(keys, contains('article-$today-manual-$i'));
      }
    });

    test('a generation past onDemandDailyCap is refused, without ever '
        'calling the AI', () async {
      await makeEntitled();
      await seedCategory(1, 'Craft');
      for (var i = 0; i < NewsfeedService.onDemandDailyCap; i++) {
        await articleService.generateArticleOnDemand();
      }
      fakeClient.callCount = 0; // reset to isolate the next call

      final outcome = await articleService.generateArticleOnDemand();

      expect(outcome, OnDemandArticleOutcome.dailyCapReached);
      expect(fakeClient.callCount, 0);
    });

    test('a swallowed failure (spend cap, network) reports failed, not '
        'generated — the same best-effort swallow the automatic article '
        'already has', () async {
      await makeEntitled();
      await seedCategory(1, 'Craft');
      fakeClient.throwOnCall = SpendLimitException(totalSpendUsd: 5, spendCapUsd: 5);

      final outcome = await articleService.generateArticleOnDemand();

      expect(outcome, OnDemandArticleOutcome.failed);
    });

    test('onDemandArticlesRemainingToday reflects the cap minus what has '
        "already been generated today, and never goes below zero", () async {
      await makeEntitled();
      await seedCategory(1, 'Craft');
      expect(await articleService.onDemandArticlesRemainingToday(),
          NewsfeedService.onDemandDailyCap);

      await articleService.generateArticleOnDemand();
      expect(await articleService.onDemandArticlesRemainingToday(),
          NewsfeedService.onDemandDailyCap - 1);

      for (var i = 1; i < NewsfeedService.onDemandDailyCap; i++) {
        await articleService.generateArticleOnDemand();
      }
      expect(await articleService.onDemandArticlesRemainingToday(), 0);
    });
  });
}
