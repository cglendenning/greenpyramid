import 'dart:convert';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// Thrown when the AI proxy call fails (network, auth/App Check, or a
// backend error). The message is user-presentable.
class AiProxyException implements Exception {
  final String message;
  AiProxyException(this.message);
  @override
  String toString() => message;
}

// The single transport for every OpenAI call in the app. Instead of talking
// to api.openai.com with a key baked into the binary, it POSTs to the Green
// Pyramid Cloud Function, attaching a Firebase App Check token that proves
// the request came from the genuine app binary. The real OpenAI key lives
// only in the backend's Secret Manager, so there is nothing in the app to
// extract. (The app has no user accounts, so App Check is the sole gate —
// no user identity is sent.)
class AiProxy {
  AiProxy._();
  static final AiProxy instance = AiProxy._();

  // Not a secret — just the backend address (the deployed Cloud Function).
  static const String _baseUrl =
      'https://us-central1-life-ops.cloudfunctions.net/api';

  // Sends a chat completion through the proxy and returns the assistant's
  // text. [messages] are plain {role, content} maps (role: system/user/
  // assistant). Throws [AiProxyException] on any failure.
  Future<String> chatText({
    required String model,
    required List<Map<String, String>> messages,
    int maxTokens = 400,
    double? temperature,
    double? topP,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    String? appCheckToken;
    try {
      appCheckToken = await FirebaseAppCheck.instance.getToken();
    } catch (e) {
      debugPrint('AiProxy: App Check token acquisition failed: $e');
      throw AiProxyException(
          'Could not verify the app. Please check your connection and try'
          ' again.');
    }
    if (appCheckToken == null) {
      throw AiProxyException('App verification unavailable. Try again.');
    }

    http.Response resp;
    try {
      resp = await http
          .post(
            Uri.parse('$_baseUrl/v1/chat/completions'),
            headers: {
              'Content-Type': 'application/json',
              'X-Firebase-AppCheck': appCheckToken,
            },
            body: jsonEncode({
              'model': model,
              'messages': messages,
              'max_tokens': maxTokens,
              if (temperature != null) 'temperature': temperature,
              if (topP != null) 'top_p': topP,
            }),
          )
          .timeout(timeout);
    } catch (e) {
      debugPrint('AiProxy: request failed: $e');
      throw AiProxyException('The servers seem busy. Please try again.');
    }

    if (resp.statusCode != 200) {
      debugPrint('AiProxy: backend ${resp.statusCode}: ${resp.body}');
      throw AiProxyException('The servers seem busy. Please try again.');
    }

    try {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final content =
          data['choices'][0]['message']['content'] as String?;
      return (content ?? '').trim();
    } catch (e) {
      debugPrint('AiProxy: bad response shape: $e');
      throw AiProxyException('Got an unexpected response. Please try again.');
    }
  }
}
