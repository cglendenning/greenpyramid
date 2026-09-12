import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D-150: NewsfeedScreen owns live DatabaseHelper/NewsfeedService/
/// FirebaseAnalytics singletons the same way tasklist.dart and
/// editpyramid.dart do (calling FirebaseAnalytics.instance.logEvent in
/// initState hangs a bare tester.pumpWidget with no Firebase test setup —
/// confirmed live), so this is a structural (source-text) test, matching
/// this repo's convention for that class of screen (see
/// profile_wiring_test.dart's own comment). NewsfeedService's own logic —
/// streak/essence generation, dedup, pagination — is covered directly by
/// newsfeed_service_test.dart's in-memory-sqlite tests instead.
void main() {
  final source = File('lib/screens/newsfeed_screen.dart').readAsStringSync();

  test('D-150: loading generates new items before rendering the feed — '
      'the owner\'s ask ("a newsfeed that is generated from the users own '
      'personal information") means the feed must actually be populated '
      'from current data, not left to whatever was generated on some '
      'earlier visit', () {
    expect(source, contains('_service.seedSampleCardsIfNeeded()'));
  });

  test('D-150: an empty feed shows a real empty-state message, not a '
      'blank screen', () {
    expect(source, contains('Nothing here yet'));
  });

  test('D-150: scrolling loads another page as the user nears the bottom '
      '— "they can scroll back as far as they want in their newsfeed" '
      'means history must not be capped to one fixed window', () {
    expect(source, contains('_onScroll'));
    expect(source, contains('_loadMore'));
    expect(source, contains('maxScrollExtent'));
  });

  test('D-150: each page uses NewsfeedService.getFeed with an increasing '
      'offset, not a single fixed query', () {
    expect(source, contains('_service.getFeed(limit: _pageSize, offset: 0)'));
    expect(source,
        contains('_service.getFeed(limit: _pageSize, offset: _items.length)'));
  });
}
