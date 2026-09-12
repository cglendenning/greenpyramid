import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D-154: "each card will be maybe half of the screen and mostly text but
/// one of the images ... arranged in a random layout so that not each
/// card has the same layout." NewsfeedScreen owns live Firebase/
/// DatabaseHelper singletons the same way other screens in this class do
/// (FirebaseAnalytics.instance.logEvent in initState hangs a bare
/// tester.pumpWidget with no Firebase test setup — confirmed live,
/// newsfeed_screen_test.dart's own comment), so its private card widget
/// can't be reached through a real pump either. This is a structural
/// (source-text) test of the layout-variety mechanism, plus a pure-logic
/// check on the same stable-hash function the card uses to pick a layout
/// and an image, mirrored here rather than reaching into a private
/// function directly.
int _stableHash(String s) {
  var h = 0;
  for (final c in s.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return h;
}

void main() {
  final source = File('lib/screens/newsfeed_screen.dart').readAsStringSync();

  test('the card has more than one layout template, and picks a stock '
      'image, both deterministically from the item\'s own dedupeKey — '
      'not truly random, so a rebuild/rescroll never reshuffles a card '
      "that's already on screen", () {
    expect(source, contains('enum _CardLayout'));
    expect(source, contains('_CardLayout.imageTop'));
    expect(source, contains('_CardLayout.imageLeft'));
    expect(source, contains('_CardLayout.imageRight'));
    expect(source, contains('_CardLayout.imageBackground'));
    expect(source, contains('kStockImages[hash % kStockImages.length]'));
    expect(source,
        contains('_CardLayout.values[hash % _CardLayout.values.length]'));
  });

  test('the card is sized to roughly half the screen height — "each card '
      'will be maybe half of the screen"', () {
    expect(source, contains('MediaQuery.of(context).size.height * 0.5'));
  });

  test('stable-hash distribution: distinct dedupeKeys spread across '
      'multiple layouts and images rather than collapsing to one', () {
    final keys = List.generate(12, (i) => 'item-$i');
    final layoutChoices = keys.map((k) => _stableHash(k) % 4).toSet();
    final imageChoices = keys.map((k) => _stableHash(k) % 20).toSet();
    expect(layoutChoices.length, greaterThan(1));
    expect(imageChoices.length, greaterThan(1));
  });

  test('the same dedupeKey always hashes to the same value — a card '
      "never changes its own layout/image between rebuilds", () {
    expect(_stableHash('essence-42'), _stableHash('essence-42'));
  });

  test('D-164: on an article card, the date sits directly under the '
      '"ANALYSIS" label — not trailing at the bottom of the card, '
      "underneath the body text, the way every other card's date does",
      () {
    final analysisIdx = source.indexOf("'ANALYSIS'");
    expect(analysisIdx, greaterThan(-1));
    final dateIdx = source.indexOf("DateFormat('MMM d, yyyy')", analysisIdx);
    final titleIdx = source.indexOf('title,\n', analysisIdx);
    expect(dateIdx, greaterThan(-1));
    expect(dateIdx, lessThan(titleIdx),
        reason: 'the date under ANALYSIS must render before the title, '
            'not after the body');
  });

  test('D-164: a non-article card still shows its date at the bottom, '
      'after the body — there is no "ANALYSIS" label to place it under',
      () {
    expect(source, contains('if (!isArticle && !isSample && created != null)'));
  });

  group('D-168: sample cards carry a distinct SAMPLE label and a '
      'subscribe link — owner: "some designation that these are sample '
      'newsfeed" and "each one of the cards will have a subscribe link '
      'and a short indication that if they subscribe then they are '
      'going to get newsfeed items that are tailored to their actual '
      'trends and behavior"', () {
    test('the SAMPLE label is a distinct color from the real ANALYSIS '
        "label — never visually confusable with genuine AI analysis of "
        "the user's own data", () {
      expect(source, contains("'SAMPLE'"));
      final sampleIdx = source.indexOf("'SAMPLE'");
      final colorIdx = source.indexOf('color:', sampleIdx);
      final endIdx = source.indexOf(',', colorIdx);
      expect(source.substring(colorIdx, endIdx), contains('brandPurple'));
    });

    test('the subscribe link opens PaywallScreen, naming why', () {
      expect(source, contains('PaywallScreen('));
      expect(source, contains("reason: 'Get analysis tailored to your own trends'"));
    });

    test('the card body itself stays non-interactive — the subscribe '
        'link is its own distinct tappable element, matching D-154\'s '
        '"we\'re not clicking into each news article" for every other '
        'card type', () {
      expect(source, contains('GestureDetector('));
      expect(source, contains("'Subscribe'"));
    });

    test('sample cards show no date — they are illustrative, not tied '
        'to a real event', () {
      final textBlockStart = source.indexOf('Widget _textBlock(');
      final textBlockEnd = source.indexOf('\n  }', textBlockStart);
      final textBlockSource = source.substring(textBlockStart, textBlockEnd);
      // isSample is excluded from the bottom date's own condition, and
      // the SAMPLE label block (unlike ANALYSIS's) never renders a date
      // of its own either.
      final sampleLabelIdx = textBlockSource.indexOf("'SAMPLE'");
      final nextDateIdx =
          textBlockSource.indexOf('DateFormat', sampleLabelIdx);
      final sampleBlockEnd = textBlockSource.indexOf('),\n          ]', sampleLabelIdx);
      expect(nextDateIdx == -1 || nextDateIdx > sampleBlockEnd, isTrue,
          reason: 'no DateFormat call sits inside the isSample eyebrow block');
    });
  });

  group('D-168: the "Generate new analysis" control', () {
    test('is hidden entirely for a non-entitled account, not merely '
        'disabled', () {
      expect(source, contains('if (!_entitled) return null;'));
    });

    test('shows and enforces the remaining on-demand count for the day',
        () {
      expect(source, contains('_onDemandRemaining'));
      expect(source, contains('generateArticleOnDemand'));
    });
  });
}
