import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'D-140-AC-01: archived iOS Google configuration is internally consistent',
      () {
    final info = File('ios/Runner/Info.plist').readAsStringSync();
    final google =
        File('ios/Runner/GoogleService-Info.plist').readAsStringSync();
    final project =
        File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();

    final clientId = RegExp(r'<key>CLIENT_ID</key>\s*<string>([^<]+)</string>')
        .firstMatch(google)
        ?.group(1);
    final reversedClientId =
        RegExp(r'<key>REVERSED_CLIENT_ID</key>\s*<string>([^<]+)</string>')
            .firstMatch(google)
            ?.group(1);
    expect(clientId, isNotNull);
    expect(reversedClientId, isNotNull);
    expect(info, contains('<key>GIDClientID</key>'));
    expect(info, contains('<string>$clientId</string>'));
    expect(info, contains('<string>$reversedClientId</string>'));
    expect(project, contains('Runner/GoogleService-Info.plist'));
    expect(project,
        contains('PRODUCT_BUNDLE_IDENTIFIER = com.cglendenning.lifeops;'));
  });
}
