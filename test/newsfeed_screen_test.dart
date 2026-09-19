import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D-122: NewsfeedScreen owns live DatabaseHelper/NewsfeedService/
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

  test(
      'D-122: loading generates new items before rendering the feed — '
      'the owner\'s ask ("a newsfeed that is generated from the users own '
      'personal information") means the feed must actually be populated '
      'from current data, not left to whatever was generated on some '
      'earlier visit', () {
    expect(source, contains('_service.seedSampleCardsIfNeeded()'));
  });

  test(
      'D-122: an empty feed shows a real empty-state message, not a '
      'blank screen', () {
    expect(source, contains('Nothing here yet'));
  });

  test(
      'D-122: scrolling loads another page as the user nears the bottom '
      '— "they can scroll back as far as they want in their newsfeed" '
      'means history must not be capped to one fixed window', () {
    expect(source, contains('_onScroll'));
    expect(source, contains('_loadMore'));
    expect(source, contains('maxScrollExtent'));
  });

  test(
      'D-122: each page uses NewsfeedService.getFeed with an increasing '
      'offset, not a single fixed query', () {
    expect(source, contains('_service.getFeed(limit: _pageSize, offset: 0)'));
    expect(source,
        contains('_service.getFeed(limit: _pageSize, offset: _items.length)'));
  });

  test(
      'D-122: the pagination spinner appears only while another page is '
      'actively loading, not merely because older history exists', () {
    expect(
        source, contains('itemCount: _items.length + (_loadingMore ? 1 : 0)'));
  });

  group(
      'D-133: the sample card\'s subscribe link refreshes entitlement '
      'state on return from the paywall — found live: subscribing and '
      'landing back on this screen still showed the subscribe pitch and '
      'hid the generate button, because entitlement state was only ever '
      'loaded once, in initState', () {
    test(
        'the subscribe link awaits the paywall push, then reloads '
        'entitlement state', () {
      expect(source,
          contains('await Navigator.of(context).push(MaterialPageRoute('));
      expect(source, contains('await onReturnFromPaywall?.call();'));
    });

    test(
        'the screen wires its own _loadEntitlementState into each card '
        'as that callback', () {
      expect(source, contains('onReturnFromPaywall: _loadEntitlementState'));
    });
  });

  group(
      'D-142: entitlement state is pulled from the server before the '
      'local cache is read — found live: the local account_state cache '
      'can sit stale (a successful purchase whose optimistic local write '
      'never landed) while Firestore already has the true value, and '
      'nothing but a cold app launch or a 402 refusal elsewhere ever '
      'otherwise refreshed it', () {
    test(
        '_loadEntitlementState calls EntitlementService.pullFromServer '
        'before reading the local account_state row', () {
      final start = source.indexOf('Future<void> _loadEntitlementState()');
      final end = source.indexOf('\n  }', start);
      final body = source.substring(start, end);
      final pullIdx =
          body.indexOf('EntitlementService.instance.pullFromServer');
      final readIdx = body.indexOf('_db.getAccountState()');
      expect(pullIdx, greaterThan(-1));
      expect(readIdx, greaterThan(pullIdx),
          reason: 'the server pull must happen before the local read it is '
              'meant to freshen');
    });

    test(
        'the Newsfeed uses the shared revalidating entitlement gate rather '
        'than trusting the raw cached subscribed string', () {
      final start = source.indexOf('Future<void> _loadEntitlementState()');
      final end = source.indexOf('\n  @override', start);
      final body = source.substring(start, end);
      expect(body, contains('EntitlementService.instance.isEntitled()'));
    });

    test(
        'the final Generate tap rechecks entitlement before the AI request, '
        'so revocation while the screen is open cannot authorize generation',
        () {
      final start = source.indexOf('Future<void> _onGenerateTapped()');
      final end = source.indexOf('\n  void _showSnack', start);
      final body = source.substring(start, end);
      final gateIdx = body.indexOf('EntitlementService.instance.isEntitled()');
      final generateIdx = body.indexOf('generateArticleOnDemand');
      expect(gateIdx, greaterThan(-1));
      expect(generateIdx, greaterThan(gateIdx));
    });
  });

  group(
      'D-137: a sample card\'s subscribe pitch disappears once the '
      'account is entitled — owner: "I want that whole text block to '
      'not appear when I am subscribed"', () {
    test(
        'the subscribe-pitch block is gated on both isSample and '
        '!entitled', () {
      expect(source, contains('if (isSample && !entitled) ...['));
    });

    test('the screen threads its own live _entitled state into each card', () {
      expect(source, contains('entitled: _entitled'));
    });

    test(
        'the SAMPLE eyebrow label is unconditional on entitlement — the '
        'card stays illustrative content either way, only the pitch to '
        'subscribe is what stops making sense', () {
      final labelIdx = source.indexOf("'SAMPLE',");
      final gateIdx = source.lastIndexOf('if (isSample)', labelIdx);
      expect(gateIdx, greaterThan(-1));
      expect(source.substring(gateIdx, labelIdx), isNot(contains('!entitled')));
    });
  });

  group(
      'D-133: the "Generate new analysis" control has no decorative '
      'icon and no visible countdown', () {
    test(
        'never uses the auto_awesome ("AI sparkle") icon — owner: "do '
        'not use the little stars, indicating artificial intelligence '
        'icon... create a rule to never use that thing ever"', () {
      expect(source, isNot(contains('auto_awesome')));
    });

    test('the button label never states how many generations remain', () {
      expect(source, isNot(contains('left today')));
    });

    test(
        'the cap is enforced purely by disabling the button, not by '
        'swapping in an explanatory label', () {
      expect(source,
          contains('disabled = _generating || _onDemandRemaining <= 0'));
      expect(
          source, contains('onPressed: disabled ? null : _onGenerateTapped'));
    });
  });
}
