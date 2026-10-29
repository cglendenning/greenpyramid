import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D-007: SetupScreen owns live Firebase singletons, so like
/// setup_essence_flow_test.dart this is a structural (source-text) test.
void main() {
  final source = File('lib/screens/setup_screen.dart').readAsStringSync();

  String method(String signature) {
    final start = source.indexOf(signature);
    expect(start, greaterThan(-1), reason: '$signature not found');
    return source.substring(start, source.indexOf('\n  }', start));
  }

  test(
      'D-007-AC-03: every explanation-exchange message gets a response — a reply '
      'that does not earn the one-time acknowledgment gets an advisor turn',
      () {
    final body = method('Future<void> _sendEssenceReply()');
    expect(body, contains('needsAdvisorReply = true'));
    expect(body, contains('if (needsAdvisorReply && mounted) await _replyInCurrentFoundational();'));
  });

  test(
      'D-007-AC-03: the follow-up turn is scoped to this category\'s exchange '
      'and spoken by this category\'s advisor', () {
    final body = method('Future<void> _replyInCurrentFoundational()');
    expect(body, contains('conversationHistoryOverride: _currentExchangeMessages'));
    expect(body, contains('session.rotationOrder[_essenceIndex'));
    expect(body, contains('_runAiCall('));
  });

  test(
      'D-007-AC-03: retrying after a failed follow-up re-sends that reply instead '
      'of re-asking the category\'s opening question', () {
    final start = source.indexOf('Future<void> _retryCurrentPhase()');
    final body = source.substring(start, source.indexOf('\n  }', start));
    expect(body, contains("exchange.last.advisorKey == 'user'"));
    expect(body, contains('_replyInCurrentFoundational()'));
  });
}
