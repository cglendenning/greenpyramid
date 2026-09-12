import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D-154: "whenever a new notification is produced, the preview in the
/// notification will be a headline and when you tap the notification, it
/// will go directly to the newsfeed." tasklist.dart, editpyramid.dart,
/// notification.dart, and settings.dart all own live Firebase/DB/plugin
/// singletons the same way other screens in this class do (see
/// profile_wiring_test.dart's own comment), so this is a structural
/// (source-text) test — the actual generation logic is covered directly
/// by newsfeed_service_test.dart's in-memory-sqlite tests.
void main() {
  group('D-154: checking off a task, and redefining a category\'s essence, '
      'both fire a local notification for any genuinely new newsfeed '
      'item — the exact two moments a streak or essence change is '
      'actually created', () {
    test('tasklist.dart notifies after a checkbox change', () {
      final source = File('lib/screens/tasklist.dart').readAsStringSync();
      expect(source, contains('NewsfeedService.instance.generateNewItems()'));
      expect(source, contains('showNewsfeedItemNotification('));
    });

    test('editpyramid.dart notifies after a successful essence/name edit',
        () {
      final source = File('lib/screens/editpyramid.dart').readAsStringSync();
      expect(source, contains('NewsfeedService.instance.generateNewItems()'));
      expect(source, contains('showNewsfeedItemNotification('));
    });
  });

  group('D-154: tapping a newsfeed notification opens NewsfeedScreen '
      'scrolled to the specific item it was about', () {
    test('notification.dart routes a newsfeed_item structured payload to '
        "NewsfeedScreen's highlightDedupeKey", () {
      final source = File('lib/services/notification.dart').readAsStringSync();
      expect(source, contains("case 'newsfeed_item':"));
      expect(source, contains('NewsfeedScreen(highlightDedupeKey: dedupeKey)'));
    });

    test('showNewsfeedItemNotification carries the item\'s dedupeKey in a '
        'structured JSON payload, not a bare route string', () {
      final source = File('lib/services/notification.dart').readAsStringSync();
      final start = source.indexOf('Future<void> showNewsfeedItemNotification(');
      expect(start, greaterThan(-1));
      final body = source.substring(start, start + 400);
      expect(body, contains("'type': 'newsfeed_item'"));
      expect(body, contains("'dedupeKey': dedupeKey"));
    });
  });

  group('D-154: the Settings test-notification control behaves exactly '
      'like a real newsfeed notification', () {
    test('picks a real newsfeed item and schedules it via '
        'scheduleNewsfeedTestNotification, not the old generic message',
        () {
      final source = File('lib/screens/settings.dart').readAsStringSync();
      expect(source, contains('NewsfeedService.instance.generateNewItems()'));
      expect(source, contains('NewsfeedService.instance.getFeed('));
      expect(source, contains('scheduleNewsfeedTestNotification('));
    });

    test('scheduleNewsfeedTestNotification reuses testNotificationId, so '
        'the existing pending/cancel tracking keeps working unchanged',
        () {
      final source = File('lib/services/notification.dart').readAsStringSync();
      final start =
          source.indexOf('Future<void> scheduleNewsfeedTestNotification(');
      expect(start, greaterThan(-1));
      expect(source.substring(start, start + 1200), contains('testNotificationId'));
    });
  });

  group('D-154: NewsfeedScreen accepts a highlightDedupeKey and loads '
      'exactly far enough into the feed to include that item', () {
    test('the constructor takes an optional highlightDedupeKey', () {
      final source =
          File('lib/screens/newsfeed_screen.dart').readAsStringSync();
      expect(source, contains('this.highlightDedupeKey'));
      expect(source, contains('final String? highlightDedupeKey;'));
    });

    test('loading computes the target item\'s position and loads that far '
        'in, rather than always starting from a fixed page size', () {
      final source =
          File('lib/screens/newsfeed_screen.dart').readAsStringSync();
      expect(source, contains('_service.getItemPosition(target)'));
      expect(source, contains('_service.getFeed(limit: targetPosition + 1'));
    });

    test('the loaded item is scrolled into view via Scrollable.ensureVisible',
        () {
      final source =
          File('lib/screens/newsfeed_screen.dart').readAsStringSync();
      expect(source, contains('Scrollable.ensureVisible('));
    });
  });
}
