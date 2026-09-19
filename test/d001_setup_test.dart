import 'dart:io';
import 'dart:convert';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/models/board_session.dart';
import 'package:life_ops/screens/setup_screen.dart';
import 'package:life_ops/services/auth_service.dart';
import 'package:life_ops/services/council_client.dart';
import 'package:life_ops/services/council_service.dart';
import 'package:life_ops/services/db.dart';
import 'package:life_ops/services/entitlement_service.dart';
import 'package:life_ops/services/setup_draft_store.dart';
import 'package:life_ops/services/setup_service.dart';
import 'package:life_ops/services/sync_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Paths extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _Paths(this.path);
  final String path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

class _Auth extends AuthService {
  _Auth()
      : super(
            auth: MockFirebaseAuth(
                signedIn: true,
                mockUser: MockUser(uid: 'draft-user', isAnonymous: true)));
  bool linked = false;
  @override
  String get currentUid => 'draft-user';
  @override
  bool get isAnonymous => !linked;
  @override
  Future<String?> signInSilently() async => currentUid;
}

class _Trial extends EntitlementService {
  _Trial(this.events) : super(firestore: FakeFirebaseFirestore());
  final List<String> events;
  @override
  Future<void> requestTrialAfterSetup() async {
    events.add('trial');
  }
}

class _Client extends CouncilClient {
  List<Map<String, String>>? transcript;
  @override
  Future<List<CategoryProposal>> deriveCategories(
      {required String sessionId,
      required List<Map<String, String>> transcript,
      List<CategoryProposal>? existingCategories}) async {
    this.transcript = transcript;
    return categories;
  }
}

final categories = List.generate(
    6,
    (i) => CategoryProposal(
        position: i + 1,
        name: [
          'Health',
          'Family',
          'Craft',
          'Learning',
          'Friends',
          'Service'
        ][i],
        description: 'A meaningful part of my life.'));
Map<String, List<String>> habits() => {
      for (final c in categories) c.name: ['Practice ${c.name.toLowerCase()}']
    };
Map<String, dynamic> state(String phase) => {
      'phase': phase,
      'manual': true,
      'refining': false,
      'tierIntroShown': true,
      'categoriesEdited': true,
      'vision': 'I live with care.',
      'essenceIndex': 0,
      'essenceStepStartIndex': 0,
      'essenceAcknowledged': false,
      'categories': categories
          .map((c) => {
                'position': c.position,
                'name': c.name,
                'description': c.description
              })
          .toList(),
      'foundational': categories
          .take(3)
          .map((c) =>
              {'categoryId': c.position, 'categoryName': c.name, 'essence': ''})
          .toList(),
      'habits': habits(),
    };

class _MemoryDrafts extends SetupDraftStore {
  _MemoryDrafts(this.payload) : super(cloud: FakeFirebaseFirestore());
  Map<String, dynamic>? payload;
  @override
  Future<Map<String, dynamic>?> load(String uid) async => payload;
  @override
  Future<void> save(
      String uid, BoardSession session, Map<String, dynamic> state) async {
    payload = jsonDecode(jsonEncode(
        {'session': SetupDraftStore.encodeSession(session), 'state': state}));
  }

  @override
  Future<void> publish(String uid, String id) async {}

  @override
  Future<void> delete(String uid, String sessionId) async {
    payload = null;
  }
}

class _Setup extends SetupService {
  _Setup(
      {required super.council,
      required super.db,
      required super.auth,
      required super.drafts,
      required super.client,
      required super.sync});
  bool widgetMode = false;
  late BoardSession current;
  late _MemoryDrafts memory;
  @override
  SetupDraftStore get drafts => widgetMode ? memory : super.drafts;
  @override
  Future<BoardSession> startOrResumeSetup() =>
      widgetMode ? Future.value(current) : super.startOrResumeSetup();
  @override
  Future<Map<String, dynamic>?> loadDraft() =>
      widgetMode ? memory.load(auth.currentUid!) : super.loadDraft();
  @override
  Future<String?> firstName() =>
      widgetMode ? Future.value('Craig') : super.firstName();
  @override
  Future<String?> entitlementState() async => 'lapsed';
  @override
  Future<void> saveManualVision(String value) =>
      widgetMode ? Future.value() : super.saveManualVision(value);
  @override
  Future<void> materializeDraft(BoardSession session, List<CategoryProposal> cs,
      List<Map<String, dynamic>> es, Map<String, List<String>> hs) async {
    if (widgetMode) {
      events.addAll(['sync', 'trial']);
      return;
    }
    await super.materializeDraft(session, cs, es, hs);
  }

  final events = <String>[];
  @override
  EntitlementService get entitlement => _Trial(events);
  @override
  Future<void> acknowledgeCompletion(BoardSession session) async {
    if (auth.isAnonymous) throw StateError('not linked');
    events.add('completion');
  }

  @override
  Future<void> syncAfterSetup() async {
    events.add('sync');
  }
}

void main() {
  final db = DatabaseHelper.instance;
  late Directory directory;
  late FakeFirebaseFirestore cloud;
  late _Auth auth;
  late _Setup setup;
  late SetupDraftStore drafts;
  late BoardSession session;
  late _Client client;
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('gp-d001-');
    PathProviderPlatform.instance = _Paths(directory.path);
    SharedPreferences.setMockInitialValues({});
    cloud = FakeFirebaseFirestore();
    auth = _Auth();
    client = _Client();
    drafts = SetupDraftStore(db: db, cloud: cloud);
    final firebaseAuth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: auth.currentUid, isAnonymous: true));
    setup = _Setup(
        council: CouncilService(
            firestore: cloud, auth: firebaseAuth, client: client, localDb: db),
        db: db,
        auth: auth,
        drafts: drafts,
        client: client,
        sync: SyncService(firestore: cloud, db: db));
    session = await setup.startOrResumeSetup();
    setup.current = session;
  });
  tearDown(() async {
    await (await db.database).close();
    await directory.delete(recursive: true);
  });
  Future<void> pump(WidgetTester tester,
      {Future<bool> Function()? link}) async {
    final seed = await tester.runAsync(() => drafts.load(auth.currentUid));
    setup.memory = _MemoryDrafts(seed);
    setup.widgetMode = true;
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!),
        initialRoute: '/flow',
        routes: {
          '/setup': (_) => const Scaffold(body: Text('Paused')),
          '/': (_) => const Scaffold(body: Text('Home')),
          '/flow': (_) => SetupScreen(
              setupService: setup,
              linkAccount: link,
              completionBuilder: (done) => Scaffold(
                  body: ElevatedButton(
                      onPressed: done, child: const Text('Pyramid complete'))),
              permissionBuilder: (done) => Scaffold(
                  body: ElevatedButton(
                      onPressed: done, child: const Text('Enter home'))))
        }));
    await tester.pumpAndSettle();
  }

  test('D-001-AC-01: local draft survives restart and is isolated by uid',
      () async {
    final saved = state('habits');
    saved['habits']['Health'] = ['Walk outdoors'];
    await drafts.save(auth.currentUid, session, saved);
    final recreated = SetupDraftStore(db: db, cloud: FakeFirebaseFirestore());
    expect(
        (await recreated.load(auth.currentUid))!['state']['habits']['Health'],
        ['Walk outdoors']);
    expect(await recreated.load('another-user'), isNull);
    expect((await setup.startOrResumeSetup()).sessionId, session.sessionId);
  });
  test('D-148: existing provider account receives the anonymous setup draft',
      () async {
    final sourceUid = 'anonymous-source';
    final destinationUid = 'existing-provider-account';
    final saved = state('closing')..['firstName'] = 'Craig';
    await drafts.save(sourceUid, session, saved);

    expect(
        await drafts.transferForAccountSwitch(
            fromUid: sourceUid, toUid: destinationUid),
        isTrue);
    expect((await drafts.load(sourceUid))!['state']['phase'], 'closing');
    expect((await drafts.load(destinationUid))!['state']['phase'], 'closing');

    final recovered = await cloud
        .collection('users')
        .doc(destinationUid)
        .collection('councilSessions')
        .doc(session.sessionId)
        .get();
    expect(recovered.data()!['type'], 'setup');
    expect(recovered.data()!['isComplete'], isFalse);
    expect(recovered.data()!['setupDraft']['state']['firstName'], 'Craig');
    expect(recovered.data()!['recoveredFromAnonymousUid'], sourceUid);
  });
  test('D-001-AC-01: acknowledged cloud draft restores after local loss',
      () async {
    await drafts.save(auth.currentUid, session, state('categories'));
    await drafts.publish(auth.currentUid, session.sessionId);
    await (await db.database).delete('setup_drafts');
    expect(await setup.drafts.load(auth.currentUid), isNull);
    await setup.startOrResumeSetup();
    expect(
        (await drafts.load(auth.currentUid))!['state']['phase'], 'categories');
  });
  testWidgets(
      'D-001-AC-01: resume displays saved habits without a pause control',
      (tester) async {
    final saved = state('habits');
    saved['habits']['Health'] = ['Walk outdoors'];
    await tester.runAsync(() => drafts.save(auth.currentUid, session, saved));
    await pump(tester);
    expect(find.text('Walk outdoors'), findsOneWidget);
    expect(find.text('Here is what I heard.'), findsNothing);
    expect(find.text('Pause setup'), findsNothing);
    expect((await setup.drafts.load(auth.currentUid))!['state']['phase'],
        'habits');
  });
  test('D-001-AC-02: category derivation receives the actual conversation',
      () async {
    await setup.council
        .appendUserMessage(session.sessionId, 'Time with my children matters.');
    final current =
        (await setup.council.getActiveSession(type: BoardSessionType.setup))!;
    await setup.proposeCategories(current);
    expect(client.transcript!.single,
        {'advisor': 'user', 'text': 'Time with my children matters.'});
  });
  testWidgets('D-001-AC-02: edits are retained before category acceptance',
      (tester) async {
    await tester.runAsync(
        () => drafts.save(auth.currentUid, session, state('categories')));
    await pump(tester);
    await tester.tap(find.text('Edit').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Fitness');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Fitness'), findsOneWidget);
    expect(
        (await setup.drafts.load(auth.currentUid))!['state']['categories'][0]
            ['name'],
        'Fitness');
    expect(
        (await tester.runAsync(() => db.queryCategories()))!
            .any((c) => c[DatabaseHelper.columnCat] == 'Fitness'),
        isFalse);
  });
  test(
      'D-001-AC-03: initial validation denies duplicate slots, labels, missing habits and invalid bounds',
      () {
    expect(SetupService.validateCategories(categories), isNull);
    expect(
        SetupService.validateCategories([
          categories.first,
          ...categories.skip(1).take(4),
          categories.first
        ]),
        isNotNull);
    final missing = habits()..remove('Health');
    expect(SetupService.validateHabits(categories, missing), isNotNull);
    final overlong = habits()..['Health'] = ['x' * 41];
    expect(SetupService.validateHabits(categories, overlong), isNotNull);
    final tooMany = habits()..['Health'] = ['A', 'B', 'C'];
    expect(SetupService.validateHabits(categories, tooMany), isNotNull);
  });
  test(
      'D-001: setup source exposes confirmed start over and no manual completion',
      () {
    final source = File('lib/screens/setup_screen.dart').readAsStringSync();
    expect(source, contains("const Text('Start over')"));
    expect(source, contains("title: const Text('Start over?')"));
    expect(source, contains('await _setup.drafts.delete(uid, sessionId)'));
    expect(source, contains('const WelcomeScreen()'));
    expect(source, isNot(contains("const Text('Complete manually')")));
  });
  testWidgets(
      'D-001-AC-03: empty explanations advance through all foundational phases',
      (tester) async {
    await tester.runAsync(
        () => drafts.save(auth.currentUid, session, state('essences')));
    await pump(tester);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text("That's it — save this"));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save explanation'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Build my pyramid'), findsOneWidget);
    expect(
        (await setup.drafts.load(auth.currentUid))!['state']['foundational']
            .every((f) => f['essence'] == ''),
        isTrue);
  });
  test('D-001-AC-01: materialization writes accepted data and is replayable',
      () async {
    final es = categories
        .take(3)
        .map((c) => {'categoryId': c.position, 'essence': ''})
        .toList();
    await setup.materializeDraft(session, categories, es, habits());
    await setup.materializeDraft(session, categories, es, habits());
    expect((await db.queryAllTasks()).length, 6);
    expect(
        (await db.queryCategories())
            .first[DatabaseHelper.columnCategoryDescription],
        'A meaningful part of my life.');
  });
  testWidgets(
      'D-001-AC-01: link precedes completion and trial, and materializes one habit per category',
      (tester) async {
    await tester
        .runAsync(() => drafts.save(auth.currentUid, session, state('habits')));
    await pump(tester, link: () async {
      setup.events.add('link');
      auth.linked = true;
      return false;
    });
    await tester.ensureVisible(find.text('Build my pyramid'));
    await tester.tap(find.text('Build my pyramid'));
    await tester.pumpAndSettle();
    expect(setup.events, ['link', 'completion', 'sync', 'trial']);
    expect((await setup.drafts.load(auth.currentUid))!['state']['phase'],
        'reveal');
    await tester.tap(find.text('Pyramid complete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enter home'));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
    expect((await setup.drafts.load(auth.currentUid))!['state']['phase'],
        'finished');
  });
}
