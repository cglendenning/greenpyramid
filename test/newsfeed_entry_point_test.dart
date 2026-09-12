import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D-150: the hamburger menu carries a "Your Newsfeed" entry point.
/// Structural (source-text) rather than a widget test, matching
/// council_entry_point_test.dart's own convention for this menu — the
/// screen itself is a live-DatabaseHelper StatefulWidget the same way
/// tasklist.dart and editpyramid.dart are (see profile_wiring_test.dart's
/// comment on this class of screen).
void main() {
  test('D-150: the hamburger menu has a "Your Newsfeed" entry that routes '
      'to NewsfeedScreen', () {
    final source = File('lib/screens/homescreen.dart').readAsStringSync();

    expect(source, contains("value: 'newsfeed'"));
    expect(source, contains('Your Newsfeed'));

    final navStart = source.indexOf('navigateToNewsfeed(BuildContext');
    expect(navStart, greaterThan(-1));
    final navEnd = source.indexOf('\n  }', navStart);
    expect(source.substring(navStart, navEnd), contains('NewsfeedScreen'));
  });

  test('D-150: unlike the Council, the newsfeed entry point carries no '
      'entitlement/paywall gate — it never leaves the device, so there is '
      'nothing to meter', () {
    final source = File('lib/screens/homescreen.dart').readAsStringSync();
    final navStart = source.indexOf('void navigateToNewsfeed(BuildContext');
    final navEnd = source.indexOf('\n  }', navStart);
    final navBody = source.substring(navStart, navEnd);
    expect(navBody, isNot(contains('PaywallScreen')));
    expect(navBody, isNot(contains('columnEntitlement')));
  });
}
