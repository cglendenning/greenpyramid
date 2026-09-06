import 'dart:convert';

import 'package:firebase_app_check/firebase_app_check.dart';
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
/// Pyramid's own Cloud Function (not Kansei's), authenticated the same way
/// as [AiProxy] — a Firebase App Check token proving the request came from
/// the genuine app binary. D-041's model identifier lives entirely on the
/// backend; this client never names a model.
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

    http.Response resp;
    try {
      resp = await http
          .post(
            Uri.parse('$_baseUrl/boardAdvisorTurn'),
            headers: {
              'Content-Type': 'application/json',
              'X-Firebase-AppCheck': appCheckToken,
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
