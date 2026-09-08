import 'dart:convert';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'model_output_guard.dart';

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

/// D-016: thrown when the backend refuses a non-setup AI call because the
/// account is neither trialing nor subscribed. The client-side gate (e.g.
/// CouncilCategoryPicker) is expected to catch this case before ever
/// reaching the network — this is the server-authoritative backstop for
/// when a local cache is stale.
class EntitlementRequiredException implements Exception {
  final String entitlement;
  EntitlementRequiredException({required this.entitlement});
  @override
  String toString() => 'Entitlement required (currently: $entitlement)';
}

class AdvisorTurnResult {
  final String reply;
  final int inputTokens;
  final int outputTokens;
  // D-090: only meaningful for a solo setup turn (isSetup: true) — false,
  // unused, for every other caller's free-text reply.
  final bool readyToBuild;
  const AdvisorTurnResult({
    required this.reply,
    required this.inputTokens,
    required this.outputTokens,
    this.readyToBuild = false,
  });
}

class CategoryProposal {
  final int position;
  final String name;
  // D-051: a short resonant line, distinct from the name — null on a
  // category the user has hand-renamed (AiGuard.sanitizeField input has
  // no description of its own to carry over).
  final String? description;
  const CategoryProposal(
      {required this.position, required this.name, this.description});
}

/// D-048: one impediment surfaced during a category conversation, already
/// classified into one of the four domains.
class DomainFinding {
  final String domain;
  final String note;
  const DomainFinding({required this.domain, required this.note});
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
      if (data['error'] == 'entitlement_required') {
        throw EntitlementRequiredException(
            entitlement: data['entitlement'] as String? ?? 'pre_trial');
      }
      throw SpendLimitException(
        totalSpendUsd: (data['totalSpendUsd'] as num?)?.toDouble() ?? 0,
        spendCapUsd: (data['spendCapUsd'] as num?)?.toDouble() ?? 0,
      );
    }
    if (resp.statusCode == 409) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      throw SetupCallLimitException(
          count: (data['count'] as num?)?.toInt() ?? 0);
    }
    if (resp.statusCode != 200) {
      debugPrint(
          'CouncilClient: $path backend ${resp.statusCode}: ${resp.body}');
      throw CouncilClientException('The servers seem busy. Please try again.');
    }
    try {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('CouncilClient: $path bad response shape: $e');
      throw CouncilClientException(
          'Got an unexpected response. Please try again.');
    }
  }

  /// [advisorKey] is one of mira/kenji/noa/eli. [categoryContext] carries
  /// the category's name, tier, and any prior essence (D-028) — the
  /// category-scoped replacement for Kansei's goal context. [sliderValue]
  /// defaults to 0.5 and has no UI control yet (D-073). [isSetup]/
  /// [sessionId] route this turn against D-072's free call-count bound
  /// instead of D-087's spend cap (D-017) — billing only.
  ///
  /// D-097: [soloSetup] is a separate signal from [isSetup] — it alone
  /// selects D-090's solo-Mira forced-tool prompt on the backend. Found
  /// live: these were the same flag until now, and every call within a
  /// setup-typed session (including essence-deepening's four-advisor
  /// rotation, D-009 step 3) is billed free — so `isSetup` was `true` for
  /// those calls too, silently routing them through the solo-Mira
  /// pyramid-building logic instead of the category-scoped one, ignoring
  /// whichever advisor was actually meant to speak.
  /// D-093: [existingCategories], setup-only, switches Mira's turn from
  /// gathering material for a fresh pyramid to refining one already
  /// proposed — "not quite right" adjusts what's there, never discards it.
  /// D-095: [pyramidContext], general-chat-only (D-091), grounds the
  /// advisors in the user's actual pyramid instead of a placeholder.
  Future<AdvisorTurnResult> boardAdvisorTurn({
    required String advisorKey,
    required Map<String, dynamic> categoryContext,
    required List<Map<String, String>> conversationHistory,
    double sliderValue = 0.5,
    bool isSetup = false,
    bool soloSetup = false,
    String? sessionId,
    List<Map<String, String>>? existingCategories,
    List<Map<String, String?>>? pyramidContext,
  }) async {
    final data = await _post('boardAdvisorTurn', {
      'advisorKey': advisorKey,
      'sliderValue': sliderValue,
      'categoryContext': categoryContext,
      'conversationHistory': conversationHistory,
      'isSetup': isSetup,
      'soloSetup': soloSetup,
      if (sessionId != null) 'sessionId': sessionId,
      if (existingCategories != null) 'existingCategories': existingCategories,
      if (pyramidContext != null) 'pyramidContext': pyramidContext,
    });
    final usage = data['usage'] as Map<String, dynamic>? ?? const {};
    return AdvisorTurnResult(
      reply: (data['reply'] as String? ?? '').trim(),
      inputTokens: (usage['inputTokens'] as num?)?.toInt() ?? 0,
      outputTokens: (usage['outputTokens'] as num?)?.toInt() ?? 0,
      readyToBuild: data['readyToBuild'] as bool? ?? false,
    );
  }

  /// D-051: derives the six pyramid categories, already tiered by position,
  /// from the setup transcript so far. D-093: [existingCategories], when
  /// given, requests a refinement of that proposal instead of a fresh
  /// derivation.
  Future<List<CategoryProposal>> deriveCategories({
    required String sessionId,
    required List<Map<String, String>> transcript,
    List<CategoryProposal>? existingCategories,
  }) async {
    final data = await _post('deriveCategories', {
      'sessionId': sessionId,
      'transcript': transcript,
      if (existingCategories != null)
        'existingCategories': existingCategories
            .map((c) => {
                  'position': c.position,
                  'name': c.name,
                  'description': c.description ?? '',
                })
            .toList(),
    });
    final list = data['categories'] as List<dynamic>? ?? const [];
    final categories = list
        .map((c) => CategoryProposal(
              position: (c['position'] as num).toInt(),
              name: c['name'] as String,
              description: c['description'] as String?,
            ))
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    for (final c in categories) {
      if (looksLikePlaceholder(c.name) ||
          (c.description != null && looksLikePlaceholder(c.description!))) {
        throw CouncilClientException(
            'The Council needs a bit more to go on — try adding a little '
            'more detail and try again.');
      }
    }
    return categories;
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
    final habits = (data['habits'] as List<dynamic>? ?? const [])
        .map((h) => h as String)
        .toList();
    if (habits.any(looksLikePlaceholder)) {
      throw CouncilClientException(
          'The Council needs a bit more to go on — try adding a little '
          'more detail and try again.');
    }
    return habits;
  }

  /// D-048: derives domain findings from one category's conversation, at
  /// the moment its essence is accepted. Runs from both setup (free,
  /// [isSetup] true) and D-061's paid re-clarification — the backend gates
  /// accordingly, same as [boardAdvisorTurn].
  Future<List<DomainFinding>> deriveDomainFindings({
    required String sessionId,
    required String categoryName,
    String? essence,
    required List<Map<String, String>> transcript,
    bool isSetup = false,
  }) async {
    final data = await _post('deriveDomainFindings', {
      'sessionId': sessionId,
      'categoryName': categoryName,
      if (essence != null) 'essence': essence,
      'transcript': transcript,
      'isSetup': isSetup,
    });
    return (data['findings'] as List<dynamic>? ?? const [])
        .map((f) => DomainFinding(
              domain: f['domain'] as String,
              note: f['note'] as String,
            ))
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
