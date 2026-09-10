import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/main.dart';

/// D-124 Phase 5: batchCheckinPayloadFrom is the one pure piece of the
/// foreground-tap wiring — deciding whether an FCM message's `data`
/// should become a structured local-notification payload at all. Pure,
/// so it's testable without a live FCM message or notification plugin.
void main() {
  test('D-124: a batch_checkin message re-encodes its data as the '
      'structured payload', () {
    final result = batchCheckinPayloadFrom(
        {'type': 'batch_checkin', 'date': '2026-09-09', 'habits': '[]'});
    expect(result, isNotNull);
    expect(result, contains('"type":"batch_checkin"'));
    expect(result, contains('"habits":"[]"'));
  });

  test('D-124: any other message type produces no payload — this is '
      'scoped to batch_checkin only, not a general passthrough', () {
    expect(batchCheckinPayloadFrom({'type': 'something_else'}), isNull);
  });

  test('D-124: a message with no type at all produces no payload', () {
    expect(batchCheckinPayloadFrom({}), isNull);
  });
}
