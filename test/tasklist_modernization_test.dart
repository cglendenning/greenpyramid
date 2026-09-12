import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D-134: structural regression tests, not a full widget pump — this
/// screen owns live DatabaseHelper/FirebaseAnalytics singletons the same
/// way editpyramid.dart and setup_screen.dart do, and isn't widget-tested
/// directly anywhere in this suite either (see profile_wiring_test.dart's
/// own comment on this class of screen). Same source-text-assertion
/// pattern schedule_habits_screen_test.dart already uses for its D-128
/// group.
void main() {
  final source = File('lib/screens/tasklist.dart').readAsStringSync();

  group('D-134: the category detail screen uses the app\'s established '
      'dark visual language — found live: "I don\'t like the aesthetics '
      'of the links and the functionality within that screen"', () {
    test('the category name and essence text carry explicit AppColors, '
        'not the unstyled Material default', () {
      expect(source, contains('color: AppColors.textPrimary'));
      expect(source, contains('color: AppColors.textSecondary'));
    });

    test('the essence/edit block and the habit checklist are wrapped in '
        'the same card treatment (AppColors.surface, rounded corners)', () {
      expect(source, contains('Widget _card('));
      expect(source, contains('color: AppColors.surface'));
    });

    test('checkboxes use the brand green active color, not the Material '
        'default, and no longer show a redundant subtitle repeating the '
        'category name the whole screen is already about', () {
      expect(source, contains('activeColor: AppColors.brandGreen'));
      expect(source, isNot(contains('subtitle: Text(')));
    });

    test('"Edit Task List" and "Schedule Habits" are styled pill buttons '
        '(primary/secondary), not default-Material ElevatedButton/'
        'TextButton with a literal ">" in the label', () {
      expect(source, contains("Text('Edit Task List', style: _buttonLabelStyle)"));
      expect(source, contains("Text('Schedule Habits', style: _buttonLabelStyle)"));
      expect(source, isNot(contains('Edit Task List >')));
      expect(source, isNot(contains('Schedule Habits >')));
    });

    test('the date picker is explicitly dark-themed — the default '
        'CupertinoDatePicker follows light brightness regardless of the '
        'app\'s own dark Material theme', () {
      expect(source, contains('CupertinoThemeData(brightness: Brightness.dark)'));
    });

    test('the whole screen scrolls (SingleChildScrollView) instead of a '
        'fixed Center/Column that could overflow on a category with many '
        'habits or a smaller screen', () {
      expect(source, contains('SingleChildScrollView('));
    });

    test('D-113/D-047 structural invariants survive the redesign — exact '
        'literal Text/FutureBuilder/CheckboxListTile forms other tests '
        'depend on', () {
      expect(source, contains('Text(category, style: _categoryNameStyle)'));
      expect(source, contains('FutureBuilder<(int?, String?)>'));
      expect(source, contains('CheckboxListTile'));
      expect(source, contains('result.description != (currentEssence ?? \'\')'));
    });
  });

  group('D-145: the task-list card has a fixed height, not just a max — '
      'found live: "The two buttons should remain in exactly the same '
      'spot when the calendar is changed to a date that has a different '
      'number of tasks... when I switched from the 11th to the 10th the '
      'location of the buttons moved"', () {
    test('the task-list card uses a fixed SizedBox height, not a '
        'ConstrainedBox(maxHeight:) that lets it shrink to content', () {
      expect(source, contains('height: 180'),
          reason: 'D-153 trimmed the constant from D-147\'s 220 down to '
              '180 to help fit the calendar above the fold — the fixed-'
              'height mechanism itself is unchanged');
      expect(source, isNot(contains('BoxConstraints(')));
      expect(source, isNot(contains('maxHeight:')));
    });

    test('shrinkWrap is gone from the task ListView — a fixed-height '
        'parent already bounds it, and shrinkWrap would size it to '
        'content again, reintroducing the exact bug this fixes', () {
      expect(source, isNot(contains('shrinkWrap: true')));
    });
  });

  group('D-147: the fixed task-list height is a small constant, not a '
      'fraction of screen height — found live: "the recent modification '
      'to ensure that the buttons stay in the same location, pushed the '
      'calendar off the screen below"', () {
    test('the task-list card no longer sizes itself off the screen '
        "height, which pushed the calendar (below the buttons, further "
        'down the column) past the bottom of the screen', () {
      expect(source, isNot(contains('MediaQuery.of(context).size.height / 3')));
    });
  });

  group('D-153: "Edit Task List" and "Schedule Habits" sit side by side, '
      'not stacked — found live: "you could probably take the two '
      'buttons and rather than having them stack on top of each other '
      'vertically, they could align on a single row horizontally that '
      'might save some space"', () {
    test('both buttons are wrapped in Expanded inside a single Row', () {
      final rowStart = source.indexOf('Row(\n                    children: [');
      expect(rowStart, greaterThan(-1),
          reason: 'the two buttons should be direct children of one Row');
      final rowEnd = source.indexOf('const SizedBox(height: 16),', rowStart);
      expect(rowEnd, greaterThan(rowStart));
      final rowBody = source.substring(rowStart, rowEnd);
      expect(rowBody, contains("Text('Edit Task List', style: _buttonLabelStyle)"));
      expect(rowBody, contains("Text('Schedule Habits', style: _buttonLabelStyle)"));
      expect('Expanded('.allMatches(rowBody).length, 2,
          reason: 'each button should get an equal share of the row width');
    });
  });

  group('D-153: the calendar fits above the fold on a typical device — '
      'found live: "when tapping a category from the main screen ... the '
      'calendar picker the date picker is visible on the screen so right '
      'now it has scrolled off the screen"', () {
    test('the task-list card height was trimmed further, from D-147\'s '
        '220 down to 180, to reclaim vertical space for the calendar',
        () {
      expect(source, contains('height: 180'));
    });

    test('the task-list card\'s scrollbar thumb stays visible whenever '
        "there's more to scroll, not only while actively dragging — "
        'found live: "the card that is showing those tasks should '
        'display a scroll bar, if the tasks scroll beyond the screen"',
        () {
      expect(source, contains('thumbVisibility: true'));
    });
  });
}
