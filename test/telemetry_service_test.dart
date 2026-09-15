import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // D-165-AC-01
  final source = File('lib/services/telemetry_service.dart').readAsStringSync();

  test('D-165 telemetry records bounded metadata and platform/version', () {
    expect(source, contains("'eventName'"));
    expect(source, contains("'eventId'"));
    expect(source, contains("'screenKey'"));
    expect(source, contains("'uidHash'"));
    expect(source, contains("'sessionId'"));
    expect(source, contains("'appVersion'"));
    expect(source, contains('Platform.isIOS'));
    expect(source, contains('FieldValue.serverTimestamp()'));
    expect(source, contains('allowedEvents'));
  });

  test('D-165 telemetry source never writes content-bearing fields', () {
    expect(source, isNot(contains("'message'")));
    expect(source, isNot(contains("'email'")));
    expect(source, isNot(contains("'phone'")));
    expect(source, isNot(contains("'photo'")));
  });
}
