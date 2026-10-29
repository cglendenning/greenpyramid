import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/services/auth_service.dart';
import 'package:life_ops/services/db.dart';
import 'package:life_ops/services/newsfeed_service.dart';
import 'package:life_ops/services/notification_inbox_service.dart';
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

/// An inbox whose cloud read always fails, standing in for an unreachable
/// or App Check-rejected Firestore.
class _FailingInbox implements NotificationInboxService {
  @override
  Future<List<Map<String, dynamic>>?> fetchArticles() async =>
      throw StateError('unreachable');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final db = DatabaseHelper.instance;
  late Directory tempDir;
  late FakeFirebaseFirestore firestore;

  NotificationInboxService inboxFor(String uid) => NotificationInboxService(
        firestore: firestore,
        auth: AuthService(
          auth: MockFirebaseAuth(
            signedIn: true,
            mockUser: MockUser(uid: uid, isAnonymous: false),
          ),
        ),
      );

  Future<void> persistArticle(
    String uid, {
    required String messageKey,
    required String title,
    required String body,
    required DateTime createdAt,
  }) =>
      firestore.collection('users').doc(uid).collection('inbox').add({
        'messageKey': messageKey,
        'type': 'article',
        'occurrenceDate': createdAt.toIso8601String().substring(0, 10),
        'title': title,
        'body': body,
        'read': false,
        'createdAt': createdAt,
      });

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('gp_article_history_test');
    PathProviderPlatform.instance = _TempPathProvider(tempDir.path);
    SharedPreferences.setMockInitialValues({});
    firestore = FakeFirebaseFirestore();
    for (final type in ['article', 'sample']) {
      await db.deleteNewsfeedItemsByType(type);
    }
  });
  tearDown(() async {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test(
      'D-122-AC-05: a reinstall restores real article history and removes '
      'the samples seeded into the empty cache', () async {
    final service = NewsfeedService(db: db, inbox: inboxFor('u1'));
    await service.seedSampleCardsIfNeeded();
    await persistArticle('u1',
        messageKey: 'article:a',
        title: 'Craft Leads the Week',
        body: 'Body A.',
        createdAt: DateTime(2026, 10, 20, 9));
    await persistArticle('u1',
        messageKey: 'article:b',
        title: 'Rest Is Catching Up',
        body: 'Body B.',
        createdAt: DateTime(2026, 10, 27, 9));

    expect(await service.restoreArticleHistory(), 2);

    final feed = await service.getFeed(limit: 50, offset: 0);
    expect(feed.map((i) => i['type']), everyElement('article'));
    expect(feed.map((i) => i['title']),
        ['Rest Is Catching Up', 'Craft Leads the Week']);
  });

  test(
      'D-122-AC-05: restored history never duplicates an article this '
      'device already generated, and restoring twice is a no-op', () async {
    final service = NewsfeedService(db: db, inbox: inboxFor('u1'));
    await db.insertNewsfeedItem(
      type: 'article',
      title: 'Craft Leads the Week',
      body: 'Body A.',
      dedupeKey: 'article-2026-10-20',
    );
    await persistArticle('u1',
        messageKey: 'article:a',
        title: 'Craft Leads the Week',
        body: 'Body A.',
        createdAt: DateTime(2026, 10, 20, 9));

    expect(await service.restoreArticleHistory(), 0);
    expect(await service.restoreArticleHistory(), 0);
    expect(await service.getFeed(limit: 50, offset: 0), hasLength(1));
  });

  test('D-122-AC-05: only the signed-in account\'s articles are restored',
      () async {
    await persistArticle('someone-else',
        messageKey: 'article:x',
        title: 'Not Yours',
        body: 'Body X.',
        createdAt: DateTime(2026, 10, 27, 9));
    final service = NewsfeedService(db: db, inbox: inboxFor('u1'));

    expect(await service.restoreArticleHistory(), 0);
    expect(await service.getFeed(limit: 50, offset: 0), isEmpty);
  });

  test(
      'D-122-AC-05: a failed cloud read restores nothing and keeps the '
      'samples in place', () async {
    final service = NewsfeedService(db: db, inbox: _FailingInbox());
    await service.seedSampleCardsIfNeeded();

    expect(await service.restoreArticleHistory(), 0);
    final feed = await service.getFeed(limit: 50, offset: 0);
    expect(feed, hasLength(5));
    expect(feed.map((i) => i['type']), everyElement('sample'));
  });

  test(
      'D-122-AC-05: persisted articles are kept out of the notification '
      'inbox list', () {
    expect(NotificationInboxService.isNotification({'type': 'article'}),
        isFalse);
    expect(NotificationInboxService.isNotification({'type': 'tailored'}),
        isTrue);
  });
}
