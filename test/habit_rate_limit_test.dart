import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/services/ai_guard.dart';
import 'package:life_ops/services/council_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AiGuard.instance.resetForTest();
  });

  test(
      'D-146: the local guard marks its per-minute refusal as perMinute, so '
      'setup can wait it out', () async {
    final now = DateTime(2026, 10, 29, 4, 37);
    for (var i = 0; i < AiGuard.maxCallsPerMinute; i++) {
      await AiGuard.instance.acquire(at: now);
    }
    await expectLater(
      AiGuard.instance.acquire(at: now),
      throwsA(isA<AiBudgetException>()
          .having((e) => e.perMinute, 'perMinute', isTrue)),
    );
    // The window clears after a minute.
    await AiGuard.instance.acquire(at: now.add(const Duration(seconds: 61)));
  });

  test('D-146: the daily cap is not a per-minute refusal', () async {
    final today = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'ai_guard_day': '${today.year}-${today.month}-${today.day}',
      'ai_guard_count': AiGuard.maxCallsPerDay,
    });
    await expectLater(
      AiGuard.instance.acquire(at: today),
      throwsA(isA<AiBudgetException>()
          .having((e) => e.perMinute, 'perMinute', isFalse)),
    );
  });

  test(
      'D-146: a server 429 is a CouncilClientException carrying its scope, '
      'with an honest message for each scope', () {
    final minute = RateLimitedException('minute');
    final day = RateLimitedException('day');
    expect(minute, isA<CouncilClientException>());
    expect(minute.scope, 'minute');
    expect(minute.message, contains('minute'));
    expect(day.message, contains('tomorrow'));
  });

  group('D-148: habit proposals recover from rate limits', () {
    final source = File('lib/screens/setup_screen.dart').readAsStringSync();
    final client =
        File('lib/services/council_client.dart').readAsStringSync();

    test('the client maps a 429 to RateLimitedException with its scope', () {
      final start = client.indexOf('if (resp.statusCode == 429)');
      expect(start, greaterThan(-1));
      final body = client.substring(start, client.indexOf('throw', start) + 40);
      expect(body, contains("data['scope']"));
      expect(body, contains('RateLimitedException(scope)'));
    });

    test('every habit proposal goes through the paced path', () {
      final start = source.indexOf('Future<void> _loadAllHabits()');
      final body = source.substring(start, source.indexOf('\n  }', start));
      expect(body, contains('_proposeHabitsPaced('));
      expect(body, isNot(contains('_setup.proposeHabits(')));
    });

    test('a per-minute refusal waits out the window once, then retries', () {
      final start = source.indexOf('Future<List<String>> _proposeHabitsPaced(');
      final body = source.substring(
          start, source.indexOf('Future<void> _loadAllHabits()', start));
      expect(body, contains("e.scope == 'minute'"));
      expect(body, contains('e.perMinute'));
      expect(body, contains('Future<void>.delayed(_rateLimitWindow)'));
      expect(body, contains('rethrow'));
      // One attempt, then exactly one retry after the wait.
      expect(body, contains('return await propose();'));
      expect(RegExp(r'return propose\(\);').allMatches(body).length, 1);
    });

    test('the blocked habit screen offers Retry, not only start-over', () {
      final start = source.indexOf('Widget _buildHabits()');
      final body = source.substring(start, source.indexOf('return SingleChildScrollView', start));
      expect(body, contains('onPressed: _busy ? null : _retryCurrentPhase'));
      expect(body, contains("Text('Retry'"));
    });
  });
}
