import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D-048/D-049/D-068/D-025 step 7: structural checks for R9's domain map
/// and calendar context, matching this repo's convention for screens gated
/// behind a live account (council_entry_point_test.dart) — the screens
/// themselves need Firebase/a real calendar to exercise meaningfully.
void main() {
  test('D-068: the domain map uses exactly the four user-facing labels, in '
      "P-6's internal order (biological/psychological/relational/"
      'environmental -> Body/Mind/People/Place)', () {
    final source = File('lib/screens/domain_map_screen.dart').readAsStringSync();
    expect(source, contains("'biological', 'psychological', 'relational', 'environmental'"));
    expect(source, contains("'Body', 'Mind', 'People', 'Place'"));
  });

  test('D-049: a new user with no findings sees a real empty state, not an '
      'empty framework', () {
    final source = File('lib/screens/domain_map_screen.dart').readAsStringSync();
    expect(source, contains('Nothing here yet'));
  });

  test('D-049: domain state is derived from accumulated findings, never '
      'asked of the user directly — no TextField or questionnaire input '
      'exists on this screen', () {
    final source = File('lib/screens/domain_map_screen.dart').readAsStringSync();
    expect(source, isNot(contains('TextField')));
    expect(source, contains('queryDomainFindingsByDomain'));
  });

  test('D-049/D-016: the domain map is a paid capability — Settings gates '
      'it through the same entitlement check as the Council', () {
    final source = File('lib/screens/settings.dart').readAsStringSync();
    final domainMapIdx = source.indexOf("'Your domain map'");
    final ensureEntitledIdx = source.lastIndexOf('ensureEntitled(', domainMapIdx);
    expect(domainMapIdx, greaterThan(-1));
    expect(ensureEntitledIdx, greaterThan(-1));
  });

  test('D-025 step 7: calendar access is opt-in, wired into Settings, '
      'never requested from main.dart', () {
    final settings = File('lib/screens/settings.dart').readAsStringSync();
    expect(settings, contains('CalendarAccessSwitch'));
    final main = File('lib/main.dart').readAsStringSync();
    expect(main, isNot(contains('requestPermission()')));
  });

  test('D-025 step 7: iOS and Android both declare the calendar usage '
      'strings the plugin requires', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('NSCalendarsUsageDescription'));
    expect(plist, contains('NSCalendarsFullAccessUsageDescription'));
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('android.permission.READ_CALENDAR'));
  });

  test('D-037 (amended): the notification job pulls domain findings and '
      'calendar context into the same prompt-building call as everything '
      'else D-037 already enumerated', () {
    final source = File('functions/index.js').readAsStringSync();
    final buildIdx = source.indexOf('buildNotificationPrompt({');
    final block = source.substring(buildIdx, buildIdx + 400);
    expect(block, contains('domainFindings'));
    expect(block, contains('calendarContext'));
  });
}
