import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/services/calendar_service.dart';

/// D-025 step 7: no live calendar plugin is registered in this test
/// environment (no platform channel), so hasPermission/requestPermission
/// hit the plugin's MissingPluginException path — this is exactly the
/// defensive contract under test: a platform failure must never throw past
/// this class, since SyncService's whole batched write depends on it never
/// throwing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('hasPermission never throws — a platform-channel failure resolves '
      'to false', () async {
    final result = await CalendarService.instance.hasPermission();
    expect(result, isFalse);
  });

  test('requestPermission never throws — a platform-channel failure '
      'resolves to false', () async {
    final result = await CalendarService.instance.requestPermission();
    expect(result, isFalse);
  });

  test('summarizeToday returns null rather than throwing when permission '
      'cannot be determined', () async {
    final result = await CalendarService.instance.summarizeToday();
    expect(result, isNull);
  });
}
