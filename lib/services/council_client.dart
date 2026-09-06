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

/// D-040/D-050: the transport for one Council advisor turn. Calls Green
/// Pyramid's own Cloud Function (not Kansei's), authenticated with both a
/// Firebase App Check token (proves the genuine app binary — same as
/// [AiProxy]) and a Firebase ID token (proves which account, so the D-087
/// spend cap can be charged to the right one). D-041's model identifier
/// lives entirely on the backend; this client never names a model.
class CouncilClient {
  // Not private — tests subclass this and override [boardAdvisorTurn] rather
  // than mocking HTTP, since the real method's only job is transport.
  CouncilClient();
  static final CouncilClient instance = CouncilClient();

  static const String _baseUrl =
      'https://us-central1-life-ops.cloudfunctions.net/api';

  /// [advisorKey] is one of mira/kenji/noa/eli. [categoryContext] carries
  /// the category's name, tier, and any prior essence (D-028) — the
  /// category-scoped replacement for Kansei's goal context. [sliderValue]
  /// defaults to 0.5 and has no UI control yet (D-073).
  Future<AdvisorTurnResult> boardAdvisorTurn({
    required String advisorKey,
    required Map<String, dynamic> categoryContext,
    required List<Map<String, String>> conversationHistory,
    double sliderValue = 0.5,
    Duration timeout = const Duration(seconds: 30),
  }) async {
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

    http.Response resp;
    try {
      resp = await http
          .post(
            Uri.parse('$_baseUrl/boardAdvisorTurn'),
            headers: {
              'Content-Type': 'application/json',
              'X-Firebase-AppCheck': appCheckToken,
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode({
              'advisorKey': advisorKey,
              'sliderValue': sliderValue,
              'categoryContext': categoryContext,
              'conversationHistory': conversationHistory,
            }),
          )
          .timeout(timeout);
    } catch (e) {
      debugPrint('CouncilClient: request failed: $e');
      throw CouncilClientException('The servers seem busy. Please try again.');
    }

    if (resp.statusCode == 402) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      throw SpendLimitException(
        totalSpendUsd: (data['totalSpendUsd'] as num?)?.toDouble() ?? 0,
        spendCapUsd: (data['spendCapUsd'] as num?)?.toDouble() ?? 0,
      );
    }

    if (resp.statusCode != 200) {
      debugPrint('CouncilClient: backend ${resp.statusCode}: ${resp.body}');
      throw CouncilClientException('The servers seem busy. Please try again.');
    }

    try {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final usage = data['usage'] as Map<String, dynamic>? ?? const {};
      return AdvisorTurnResult(
        reply: (data['reply'] as String? ?? '').trim(),
        inputTokens: (usage['inputTokens'] as num?)?.toInt() ?? 0,
        outputTokens: (usage['outputTokens'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      debugPrint('CouncilClient: bad response shape: $e');
      throw CouncilClientException('Got an unexpected response. Please try again.');
    }
  }
}
