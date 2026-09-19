import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite/sqflite.dart';
import '../models/board_session.dart';
import 'db.dart';
import 'timeouts.dart';

/// D-001-AC-01: account-isolated restart recovery, independent of connectivity.
class SetupDraftStore {
  SetupDraftStore({DatabaseHelper? db, FirebaseFirestore? cloud})
      : db = db ?? DatabaseHelper.instance,
        _cloudOverride = cloud;
  final DatabaseHelper db;
  final FirebaseFirestore? _cloudOverride;
  FirebaseFirestore get cloud => _cloudOverride ?? FirebaseFirestore.instance;

  static Future<void> createTable(Database db) => db.execute('''
    CREATE TABLE IF NOT EXISTS setup_drafts (
      uid TEXT PRIMARY KEY, session_id TEXT NOT NULL, payload TEXT NOT NULL
    )
  ''');

  Future<Map<String, dynamic>?> load(String uid) async {
    final database = await db.database;
    final rows = await database
        .query('setup_drafts', where: 'uid = ?', whereArgs: [uid]);
    if (rows.isEmpty) return null;
    return jsonDecode(rows.single['payload'] as String) as Map<String, dynamic>;
  }

  Future<void> save(
      String uid, BoardSession session, Map<String, dynamic> state) async {
    final payload = {
      'version': 1,
      'session': encodeSession(session),
      'state': state
    };
    final database = await db.database;
    await database.insert(
        'setup_drafts',
        {
          'uid': uid,
          'session_id': session.sessionId,
          'payload': jsonEncode(payload)
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Deletes only the selected in-flight setup session from local and cloud
  /// storage. Completed account data is never touched by this operation.
  Future<void> delete(String uid, String sessionId) async {
    final database = await db.database;
    await database.delete('setup_drafts', where: 'uid = ?', whereArgs: [uid]);
    await withRemoteDeadline(
      cloud
          .collection('users')
          .doc(uid)
          .collection('councilSessions')
          .doc(sessionId)
          .delete(),
      timeout: remoteWriteTimeout,
    );
  }

  Future<void> publish(String uid, String sessionId) async {
    final payload = await load(uid);
    if (payload == null || payload['session']['sessionId'] != sessionId) return;
    await withRemoteDeadline(
      cloud
          .collection('users')
          .doc(uid)
          .collection('councilSessions')
          .doc(sessionId)
          .set({'setupDraft': payload}, SetOptions(merge: true)),
      timeout: remoteWriteTimeout,
    );
  }

  /// Copies an in-flight setup draft to the account selected by a provider
  /// sign-in that collided with an existing Firebase account.
  ///
  /// This is deliberately copy-only: the anonymous source draft is never
  /// deleted, so a failed or interrupted account switch cannot destroy the
  /// user's work. The destination receives both the resumable local payload
  /// and a complete Council session document, because [CouncilService]
  /// discovers active sessions from the latter before [recover] hydrates the
  /// draft state.
  ///
  /// A completed destination account is left untouched. A destination draft
  /// is replaced only when this source draft is further along, preventing a
  /// retry from regressing an already recovered setup.
  Future<bool> transferForAccountSwitch({
    required String fromUid,
    required String toUid,
  }) async {
    if (fromUid == toUid) return false;
    final source = await load(fromUid);
    if (source == null) return false;

    final destinationRoot = cloud.collection('users').doc(toUid);
    final snapshots = await Future.wait([
      destinationRoot.get(),
      destinationRoot.collection('profile').doc('main').get(),
    ]);
    final root = snapshots[0].data();
    final profile = snapshots[1].data();
    final destinationComplete = root?['setupComplete'] == true ||
        root?['setupCompletionId'] != null ||
        profile?['setupComplete'] == true ||
        profile?['setupCompletedAt'] != null;
    if (destinationComplete) return false;

    final session = Map<String, dynamic>.from(
        (source['session'] as Map).cast<String, dynamic>());
    final sessionId = session['sessionId'] as String?;
    if (sessionId == null || sessionId.isEmpty) return false;

    final existing = await load(toUid);
    if (existing == null || progressOf(source) > progressOf(existing)) {
      final database = await db.database;
      await database.insert(
        'setup_drafts',
        {
          'uid': toUid,
          'session_id': sessionId,
          'payload': jsonEncode(source),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    final messages = ((session['messages'] as List?) ?? const []).map((raw) {
      final message =
          Map<String, dynamic>.from((raw as Map).cast<String, dynamic>());
      return {
        'advisorKey': message['advisorKey'],
        'text': message['text'],
        'timestamp':
            Timestamp.fromDate(DateTime.parse(message['timestamp'] as String)),
      };
    }).toList();
    final sessionData = <String, dynamic>{
      'type': 'setup',
      'createdAt':
          Timestamp.fromDate(DateTime.parse(session['createdAt'] as String)),
      'lastUpdatedAt': Timestamp.fromDate(
          DateTime.parse(session['lastUpdatedAt'] as String)),
      'messages': messages,
      'rotationOrder': session['rotationOrder'],
      'sliderSettings': session['sliderSettings'],
      'isComplete': false,
      'totalInputTokens': session['totalInputTokens'] ?? 0,
      'totalOutputTokens': session['totalOutputTokens'] ?? 0,
      'setupDraft': source,
      'recoveredFromAnonymousUid': fromUid,
      'recoveredAt': FieldValue.serverTimestamp(),
    };
    await withRemoteDeadline(
      destinationRoot.collection('councilSessions').doc(sessionId).set(
            sessionData,
            SetOptions(merge: true),
          ),
      timeout: remoteWriteTimeout,
    );
    return true;
  }

  /// A monotonic comparison used when local and cloud recovery race. It is
  /// intentionally coarse: any later setup phase outranks an earlier one,
  /// with the materialized proposal counts and transcript breaking ties.
  static int progressOf(Map<String, dynamic> payload) {
    final state = (payload['state'] as Map?)?.cast<String, dynamic>() ?? {};
    final session = (payload['session'] as Map?)?.cast<String, dynamic>() ?? {};
    final messages = (session['messages'] as List?)?.length ?? 0;
    final categories = (state['categories'] as List?)?.length ?? 0;
    final foundational = (state['foundational'] as List?)?.length ?? 0;
    final habits = (state['habits'] as Map?)?.length ?? 0;
    final phase = state['phase'] as String?;
    const phases = [
      'opening',
      'openingRound',
      'openingVision',
      'tierIntro',
      'categories',
      'refining',
      'essenceIntro',
      'essences',
      'habits',
      'closing',
      'reveal',
      'permission',
      'finished',
    ];
    final phaseScore = phase == null ? -1 : phases.indexOf(phase);
    return phaseScore * 100000 +
        categories * 1000 +
        foundational * 100 +
        habits * 10 +
        messages;
  }

  Future<Map<String, dynamic>?> recover(String uid, String sessionId) async {
    final result = await loadRemote(uid, sessionId);
    if (result == null) return null;
    final database = await db.database;
    await database.insert('setup_drafts',
        {'uid': uid, 'session_id': sessionId, 'payload': jsonEncode(result)},
        conflictAlgorithm: ConflictAlgorithm.replace);
    return result;
  }

  Future<Map<String, dynamic>?> loadRemote(String uid, String sessionId) async {
    final doc = await withRemoteDeadline(
      cloud
          .collection('users')
          .doc(uid)
          .collection('councilSessions')
          .doc(sessionId)
          .get(),
    );
    final payload = doc.data()?['setupDraft'];
    if (payload == null) return null;
    return Map<String, dynamic>.from(payload as Map);
  }

  Future<Map<String, dynamic>?> recoverCompletion(String uid) async {
    final root =
        await withRemoteDeadline(cloud.collection('users').doc(uid).get());
    final id = root.data()?['setupCompletionId'] as String?;
    return id == null ? null : recover(uid, id);
  }

  static Map<String, dynamic> encodeSession(BoardSession s) => {
        'sessionId': s.sessionId,
        'createdAt': s.createdAt.toIso8601String(),
        'lastUpdatedAt': s.lastUpdatedAt.toIso8601String(),
        'rotationOrder': s.rotationOrder,
        'messages': s.messages
            .map((m) => {
                  'advisorKey': m.advisorKey,
                  'text': m.text,
                  'timestamp': m.timestamp.toIso8601String()
                })
            .toList(),
        'sliderSettings': s.sliderSettings,
        'isComplete': s.isComplete,
        'totalInputTokens': s.totalInputTokens,
        'totalOutputTokens': s.totalOutputTokens,
      };

  static BoardSession decodeSession(Map<String, dynamic> s) => BoardSession(
        sessionId: s['sessionId'],
        type: BoardSessionType.setup,
        categoryId: null,
        createdAt: DateTime.parse(s['createdAt']),
        lastUpdatedAt: DateTime.parse(s['lastUpdatedAt']),
        rotationOrder: (s['rotationOrder'] as List).cast<String>(),
        messages: (s['messages'] as List)
            .map((m) => BoardMessage(
                advisorKey: m['advisorKey'],
                text: m['text'],
                timestamp: DateTime.parse(m['timestamp'])))
            .toList(),
        sliderSettings: (s['sliderSettings'] as Map)
            .map((k, v) => MapEntry(k as String, (v as num).toDouble())),
        isComplete: s['isComplete'],
        totalInputTokens: s['totalInputTokens'],
        totalOutputTokens: s['totalOutputTokens'],
      );
}
