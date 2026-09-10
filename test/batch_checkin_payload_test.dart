import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/main.dart';

/// D-124 Phase 5 / D-083 amendment Phase 6: pushTapPayloadFrom is the
/// one pure piece of the foreground-tap wiring — deciding what a real
/// FCM push's foreground-shown local notification should carry as its
/// own payload, keyed off the push's `data.type`. Pure, so it's testable
/// without a live FCM message or notification plugin.
void main() {
  test('D-124: a batch_checkin message re-encodes its data as the '
      'structured payload', () {
    final result = pushTapPayloadFrom(
        {'type': 'batch_checkin', 'date': '2026-09-09', 'habits': '[]'});
    expect(result, isNotNull);
    expect(result, contains('"type":"batch_checkin"'));
    expect(result, contains('"habits":"[]"'));
  });

  test('D-083 amendment: a tailored message gets the plain "/" payload — '
      'the same string every other "go to the pyramid tab" local '
      'notification already uses', () {
    expect(pushTapPayloadFrom({'type': 'tailored'}), '/');
  });

  test('any other message type produces no payload — this is a '
      'deliberate allowlist, not a general passthrough', () {
    expect(pushTapPayloadFrom({'type': 'something_else'}), isNull);
  });

  test('a message with no type at all produces no payload', () {
    expect(pushTapPayloadFrom({}), isNull);
  });
}
