import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite/sqflite.dart';
import '../models/board_session.dart';
import 'db.dart';

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
    await cloud
        .collection('users')
        .doc(uid)
        .collection('councilSessions')
        .doc(sessionId)
        .delete();
  }

  Future<void> publish(String uid, String sessionId) async {
    final payload = await load(uid);
    if (payload == null || payload['session']['sessionId'] != sessionId) return;
    await cloud
        .collection('users')
        .doc(uid)
        .collection('councilSessions')
        .doc(sessionId)
        .set({'setupDraft': payload}, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> recover(String uid, String sessionId) async {
    final doc = await cloud
        .collection('users')
        .doc(uid)
        .collection('councilSessions')
        .doc(sessionId)
        .get();
    final payload = doc.data()?['setupDraft'];
    if (payload == null) return null;
    final result = Map<String, dynamic>.from(payload as Map);
    final database = await db.database;
    await database.insert('setup_drafts',
        {'uid': uid, 'session_id': sessionId, 'payload': jsonEncode(result)},
        conflictAlgorithm: ConflictAlgorithm.replace);
    return result;
  }

  Future<Map<String, dynamic>?> recoverCompletion(String uid) async {
    final root = await cloud.collection('users').doc(uid).get();
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
