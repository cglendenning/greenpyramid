import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('D-171: Analysis is gated before selection and before its snapshot loads', () {
    final home = File('lib/screens/homescreen.dart').readAsStringSync();
    final navStart = home.indexOf('onDestinationSelected:');
    final navEnd = home.indexOf('indicatorColor:', navStart);
    final nav = home.substring(navStart, navEnd);
    final gate = nav.indexOf('ensureEntitled(');
    final selection = nav.indexOf('currentScreenIndex = index');
    expect(gate, greaterThanOrEqualTo(0));
    expect(selection, greaterThan(gate));
    expect(nav, contains('See your personal Analysis journey'));

    final analysis = File('lib/screens/visualizations.dart').readAsStringSync();
    expect(analysis, contains('VisualizationService.instance.load()'));
    expect(analysis, isNot(contains('ensureEntitled(')));
  });

  test('D-172: protected surfaces use revocation-aware shared entitlement state', () {
    final entitlement = File('lib/services/entitlement_service.dart').readAsStringSync();
    expect(entitlement, contains('pullFromServer'));
    expect(entitlement, contains("entitlement: 'lapsed'"));
    expect(entitlement, contains('lifetime'));
    expect(entitlement, contains('withRemoteDeadline'));

    final newsfeed = File('lib/services/newsfeed_service.dart').readAsStringSync();
    expect(newsfeed, contains('deleteNewsfeedItemsByType(\'sample\')'));
    expect(newsfeed, contains('entitlement'));
  });
}
