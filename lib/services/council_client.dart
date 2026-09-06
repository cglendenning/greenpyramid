import 'dart:convert';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Thrown when a Council backend call fails (network, App Check, or a
/// backend error). The message is user-presentable.
class CouncilClientException implements Exception {
  final String message;
  CouncilClientException(this.message);
  @override
  String toString() => message;
}

/// D-087: thrown when the account has reached its spend cap. Distinct from
/// [CouncilClientException] so the screen can present "you've reached your
/// limit" rather than a generic failure.
class SpendLimitException implements Exception {
  final double totalSpendUsd;
  final double spendCapUsd;
  SpendLimitException({required this.totalSpendUsd, required this.spendCapUsd});
  @override
  String toString() =>
      'Spend limit reached (\$${totalSpendUsd.toStringAsFixed(2)} of'
      ' \$${spendCapUsd.toStringAsFixed(2)})';
}

/// D-072: thrown once a setup session hits its 40-model-call bound. Setup
/// is meant to close gracefully on approach, not hit this — reaching it is
/// the backstop, not the expected path.
class SetupCallLimitException implements Exception {
  final int count;
  SetupCallLimitException({required this.count});
  @override
  String toString() => 'Setup call limit reached ($count calls)';
}

class AdvisorTurnResult {
  final String reply;
  final int inputTokens;
  final int outputTokens;
  const AdvisorTurnResult({
    required this.reply,
    required this.inputTokens,
    required this.outputTokens,
  });
}

class CategoryProposal {
  final int position;
  final String name;
  const CategoryProposal({required this.position, required this.name});
}

/// D-040/D-050: the transport for every Council backend call. Calls Green
/// Pyramid's own Cloud Function (not Kansei's), authenticated with both a
/// Firebase App Check token (proves the genuine app binary — same as
/// [AiProxy]) and a Firebase ID token (proves which account, so D-087's
/// spend cap and D-072's setup call count charge the right one). D-041's
/// model identifier lives entirely on the backend; this client never names
/// a model.
class CouncilClient {
  // Not private — tests subclass this and override the request methods
  // rather than mocking HTTP, since the real methods' only job is transport.
  CouncilClient();
  static final CouncilClient instance = CouncilClient();

  static const String _baseUrl =
      'https://us-central1-life-ops.cloudfunctions.net/api';

  Future<Map<String, String>> _headers() async {
    String? appCheckToken;
    try {
      appCheckToken = await FirebaseAppCheck.instance.getToken();
    } catch (e) {
      debugPrint('CouncilClient: App Check token acquisition failed: $e');
      throw CouncilClientException(
          'Could not verify the app. Please check your connection and try'
          ' again.');
    }
    if (appCheckToken == null) {
      throw CouncilClientException('App verification unavailable. Try again.');
    }
    final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (idToken == null) {
      throw CouncilClientException('Not signed in yet. Try again in a moment.');
    }
    return {
      'Content-Type': 'application/json',
      'X-Firebase-AppCheck': appCheckToken,
      'Authorization': 'Bearer $idToken',
    };
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final headers = await _headers();
    http.Response resp;
    try {
      resp = await http
          .post(Uri.parse('$_baseUrl/$path'),
              headers: headers, body: jsonEncode(body))
          .timeout(timeout);
    } catch (e) {
      debugPrint('CouncilClient: request to $path failed: $e');
      throw CouncilClientException('The servers seem busy. Please try again.');
    }

    if (resp.statusCode == 402) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      throw SpendLimitException(
        totalSpendUsd: (data['totalSpendUsd'] as num?)?.toDouble() ?? 0,
        spendCapUsd: (data['spendCapUsd'] as num?)?.toDouble() ?? 0,
      );
    }
    if (resp.statusCode == 409) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      throw SetupCallLimitException(count: (data['count'] as num?)?.toInt() ?? 0);
    }
    if (resp.statusCode != 200) {
      debugPrint('CouncilClient: $path backend ${resp.statusCode}: ${resp.body}');
      throw CouncilClientException('The servers seem busy. Please try again.');
    }
    try {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('CouncilClient: $path bad response shape: $e');
      throw CouncilClientException('Got an unexpected response. Please try again.');
    }
  }

  /// [advisorKey] is one of mira/kenji/noa/eli. [categoryContext] carries
  /// the category's name, tier, and any prior essence (D-028) — the
  /// category-scoped replacement for Kansei's goal context. [sliderValue]
  /// defaults to 0.5 and has no UI control yet (D-073). [isSetup]/
  /// [sessionId] route this turn against D-072's free call-count bound
  /// instead of D-087's spend cap (D-017).
  Future<AdvisorTurnResult> boardAdvisorTurn({
    required String advisorKey,
    required Map<String, dynamic> categoryContext,
    required List<Map<String, String>> conversationHistory,
    double sliderValue = 0.5,
    bool isSetup = false,
    String? sessionId,
  }) async {
    final data = await _post('boardAdvisorTurn', {
      'advisorKey': advisorKey,
      'sliderValue': sliderValue,
      'categoryContext': categoryContext,
      'conversationHistory': conversationHistory,
      'isSetup': isSetup,
      if (sessionId != null) 'sessionId': sessionId,
    });
    final usage = data['usage'] as Map<String, dynamic>? ?? const {};
    return AdvisorTurnResult(
      reply: (data['reply'] as String? ?? '').trim(),
      inputTokens: (usage['inputTokens'] as num?)?.toInt() ?? 0,
      outputTokens: (usage['outputTokens'] as num?)?.toInt() ?? 0,
    );
  }

  /// D-051: derives the six pyramid categories, already tiered by position,
  /// from the setup transcript so far.
  Future<List<CategoryProposal>> deriveCategories({
    required String sessionId,
    required List<Map<String, String>> transcript,
  }) async {
    final data = await _post('deriveCategories',
        {'sessionId': sessionId, 'transcript': transcript});
    final list = data['categories'] as List<dynamic>? ?? const [];
    return list
        .map((c) => CategoryProposal(
              position: (c['position'] as num).toInt(),
              name: c['name'] as String,
            ))
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));
  }

  /// D-052: proposes 3-5 habits for one category, conditioned on its
  /// essence when one exists (D-010).
  Future<List<String>> deriveHabits({
    required String sessionId,
    required String categoryName,
    String? essence,
    List<String> existingHabits = const [],
  }) async {
    final data = await _post('deriveHabits', {
      'sessionId': sessionId,
      'categoryName': categoryName,
      if (essence != null) 'essence': essence,
      'existingHabits': existingHabits,
    });
    return (data['habits'] as List<dynamic>? ?? const [])
        .map((h) => h as String)
        .toList();
  }

  /// D-055: the closing synthesis — written once, at the end of setup.
  Future<String> deriveVisionStatement({
    required String sessionId,
    required List<Map<String, String>> essences,
    required List<Map<String, String>> transcript,
  }) async {
    final data = await _post('deriveVisionStatement', {
      'sessionId': sessionId,
      'essences': essences,
      'transcript': transcript,
    });
    return (data['vision'] as String? ?? '').trim();
  }
}
