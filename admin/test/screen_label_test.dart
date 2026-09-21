import 'package:flutter_test/flutter_test.dart';
import 'package:green_pyramid_admin/screen_label.dart';

/// D-180: every key below was read off a live admin dashboard, so these are
/// the actual shapes the telemetry produces, not invented ones.
void main() {
  group(
    'D-180-AC-01: a route generic that names a screen becomes its title',
    () {
      test('MaterialPageRoute<SignInOutcome> reads as the sign-in screen', () {
        final label = ScreenLabel.parse('MaterialPageRoute<SignInOutcome>');
        expect(label.name, 'Sign in');
        expect(label.kind, 'Page');
        expect(label.identifies, isTrue);
      });

      test(
        'ModalBottomSheetRoute<CategoryEditResult> reads as category edit',
        () {
          final label = ScreenLabel.parse(
            'ModalBottomSheetRoute<CategoryEditResult>',
          );
          expect(label.name, 'Category edit');
          expect(label.kind, 'Bottom sheet');
          expect(label.identifies, isTrue);
        },
      );

      test('a private route type loses its leading underscore', () {
        expect(
          ScreenLabel.parse('_PopupMenuRoute<String?>').kind,
          'Popup menu',
        );
      });

      test('an acronym in the payload is not lowercased', () {
        expect(
          ScreenLabel.parse('MaterialPageRoute<OTAStatus>').name,
          'OTA status',
        );
      });
    },
  );

  group('D-181-AC-04: a route named after its widget reads as the screen', () {
    test('the names D-181 puts on the app\'s routes read as screens', () {
      const expected = <String, String>{
        // Stacked plumbing suffixes both come off.
        'HomeScreenWidget': 'Home',
        'PaywallScreen': 'Paywall',
        'GeneralCouncilScreen': 'General council',
        'ScheduleHabitsScreen': 'Schedule habits',
        'NotificationInboxScreen': 'Notification inbox',
        'TrialDisclosureScreen': 'Trial disclosure',
        'CancelSubscriptionScreen': 'Cancel subscription',
        'SetupCompletionScreen': 'Setup completion',
        'HomescreenErrorScreen': 'Homescreen error',
        'CouncilCategoryPicker': 'Council category picker',
        'EditTaskDetail': 'Edit task detail',
        'TaskList': 'Task list',
        'FAQ': 'FAQ',
        // The one route that already carried a hand-written slug.
        'setup-account-link': 'Setup account link',
      };
      expected.forEach((key, want) {
        final label = ScreenLabel.parse(key);
        expect(label.name, want, reason: key);
        expect(label.identifies, isTrue, reason: key);
      });
    });
  });

  group('D-180-AC-02: a generic that names nothing is marked unattributed', () {
    test('MaterialPageRoute<dynamic> is clearly marked as historical', () {
      final label = ScreenLabel.parse('MaterialPageRoute<dynamic>');
      expect(label.name, 'Unattributed page (historical)');
      expect(label.identifies, isFalse);
    });

    test('primitive payloads describe the return value, not the screen', () {
      for (final key in [
        'MaterialPageRoute<bool>',
        'DialogRoute<void>',
        'DialogRoute<bool>',
        '_PopupMenuRoute<String?>',
      ]) {
        expect(ScreenLabel.parse(key).identifies, isFalse, reason: key);
      }
    });

    test('the dialog and sheet kinds survive an anonymous payload', () {
      expect(
        ScreenLabel.parse('DialogRoute<void>').name,
        'Historical non-screen route',
      );
      expect(
        ScreenLabel.parse('_PopupMenuRoute<String?>').name,
        'Historical non-screen route',
      );
    });

    test('a bare route type with no generic names nothing either', () {
      final label = ScreenLabel.parse('MaterialPageRoute');
      expect(label.name, 'Unattributed page (historical)');
      expect(label.identifies, isFalse);
    });
  });

  group(
    'D-180-AC-03: an explicitly named route keeps the name it was given',
    () {
      test('the root route reads as Home', () {
        final label = ScreenLabel.parse('/');
        expect(label.name, 'Home');
        expect(label.identifies, isTrue);
        expect(label.kind, isEmpty);
      });

      test('a slug becomes a sentence', () {
        expect(ScreenLabel.parse('/setup_habits').name, 'Setup habits');
        expect(ScreenLabel.parse('paywall').name, 'Paywall');
      });
    },
  );

  group('D-180-AC-04: the raw key is never lost', () {
    test('every label carries the key it was parsed from', () {
      for (final key in [
        'MaterialPageRoute<SignInOutcome>',
        'MaterialPageRoute<dynamic>',
        '/',
        'DialogRoute<bool>',
      ]) {
        expect(ScreenLabel.parse(key).raw, key, reason: key);
      }
    });

    test('an empty or malformed key degrades instead of throwing', () {
      expect(ScreenLabel.parse('').name, 'Unknown screen');
      expect(ScreenLabel.parse('   ').name, 'Unknown screen');
      // A key truncated by the 96-character cap loses its closing bracket.
      final truncated = ScreenLabel.parse('MaterialPageRoute<SignInOutc');
      expect(truncated.identifies, isTrue);
      expect(truncated.kind, 'Page');
    });
  });
}
