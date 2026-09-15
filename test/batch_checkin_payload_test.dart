import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/main.dart';

/// D-099 Phase 5 / D-066 amendment Phase 6: pushTapPayloadFrom is the
/// one pure piece of the foreground-tap wiring — deciding what a real
/// FCM push's foreground-shown local notification should carry as its
/// own payload, keyed off the push's `data.type`. Pure, so it's testable
/// without a live FCM message or notification plugin.
void main() {
  test(
      'D-099: a batch_checkin message re-encodes its data as the '
      'structured payload', () {
    final result = pushTapPayloadFrom(
        {'type': 'batch_checkin', 'date': '2026-09-09', 'habits': '[]'});
    expect(result, isNotNull);
    expect(result, contains('"type":"batch_checkin"'));
    expect(result, contains('"habits":"[]"'));
  });

  test(
      'D-149-AC-04: a tailored message keeps account and inbox identity '
      'in its structured foreground payload — '
      'notification already uses', () {
    final tailored = jsonDecode(pushTapPayloadFrom({
      'type': 'tailored',
      'accountUid': 'uid',
      'messageKey': 'tailored:2026-09-15:09:00',
    })!) as Map<String, dynamic>;
    expect(tailored['type'], 'tailored');
    expect(tailored['accountUid'], 'uid');
    expect(tailored['messageKey'], 'tailored:2026-09-15:09:00');
  });

  test(
      'any other message type produces no payload — this is a '
      'deliberate allowlist, not a general passthrough', () {
    expect(pushTapPayloadFrom({'type': 'something_else'}), isNull);
  });

  test('a message with no type at all produces no payload', () {
    expect(pushTapPayloadFrom({}), isNull);
  });
}
