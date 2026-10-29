import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D-122: NewsfeedScreen owns live Firebase singletons, so like
/// newsfeed_screen_test.dart this is a structural (source-text) test. The
/// cache-side deletion of samples is covered by newsfeed_service_test.dart.
void main() {
  final source = File('lib/screens/newsfeed_screen.dart').readAsStringSync();

  String body(String signature) {
    final start = source.indexOf(signature);
    expect(start, greaterThan(-1), reason: '$signature not found');
    final end = source.indexOf('\n  }\n', start);
    return source.substring(start, end);
  }

  test(
      'D-122: a background article that arrives while samples are on screen '
      'reloads the visible feed, so deleted samples leave the screen', () {
    final generate = body('Future<void> _generateArticleInBackground()');
    expect(generate, contains("i['type'] == 'sample'"));
    expect(generate, contains('_reloadVisibleFeed()'));
  });

  test(
      'D-122: an on-demand article that arrives while samples are on screen '
      'reloads the visible feed too', () {
    final start = source.indexOf('case OnDemandArticleOutcome.generated:');
    expect(start, greaterThan(-1));
    final generated = source.substring(
        start, source.indexOf('case OnDemandArticleOutcome.', start + 1));
    expect(generated, contains("i['type'] == 'sample'"));
    expect(generated, contains('_reloadVisibleFeed()'));
  });

  test('D-122-AC-05: restored history reloads the visible feed', () {
    final restore = body('Future<void> _restoreArticleHistoryInBackground()');
    expect(restore, contains('_reloadVisibleFeed()'));
  });
}
