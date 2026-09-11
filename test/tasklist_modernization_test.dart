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
      expect(source, contains('height: MediaQuery.of(context).size.height / 3'));
      expect(source, isNot(contains('BoxConstraints(')));
      expect(source, isNot(contains('maxHeight:')));
    });

    test('shrinkWrap is gone from the task ListView — a fixed-height '
        'parent already bounds it, and shrinkWrap would size it to '
        'content again, reintroducing the exact bug this fixes', () {
      expect(source, isNot(contains('shrinkWrap: true')));
    });
  });
}
