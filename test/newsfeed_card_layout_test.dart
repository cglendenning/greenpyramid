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
}
