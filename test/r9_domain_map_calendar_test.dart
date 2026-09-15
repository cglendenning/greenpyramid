import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D-145 step 7: structural checks for calendar access.
void main() {
  test(
      'D-145 step 7: calendar access is opt-in, wired into Settings, '
      'never requested from main.dart', () {
    final settings = File('lib/screens/settings.dart').readAsStringSync();
    expect(settings, contains('CalendarAccessSwitch'));
    final main = File('lib/main.dart').readAsStringSync();
    expect(main, isNot(contains('requestPermission()')));
  });

  test(
      'D-145 step 7: iOS and Android both declare the calendar usage '
      'strings the plugin requires', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('NSCalendarsUsageDescription'));
    expect(plist, contains('NSCalendarsFullAccessUsageDescription'));
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('android.permission.READ_CALENDAR'));
  });
}
