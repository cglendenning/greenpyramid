import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D-131: structural regression tests, not a full widget pump — this
/// screen composition calls FirebaseAnalytics.instance the same way every
/// other analytics-logging screen in this codebase does, none of which
/// are pumped in a widget test here either (Firebase Core isn't mocked
/// anywhere in this suite). Same source-text-assertion pattern
/// schedule_habits_screen_test.dart already uses for its D-128 group.
void main() {
  group('D-131: main-screen background is full-bleed, toolbar is '
      'translucent and rounded', () {
    final pyramidSource = File('lib/widgets/pyramid.dart').readAsStringSync();
    final homescreenSource = File('lib/screens/homescreen.dart').readAsStringSync();

    test('the jungle background fills the whole screen via a Positioned.fill '
        'in build() — found live: it was previously bounded to a small '
        'rounded card behind the pyramid, not "the background for the '
        'entire screen"', () {
      expect(pyramidSource, contains("Positioned.fill(\n          child: Image.asset(\n            'images/jungle_bg.jpg',"));
    });

    test('a gradient scrim sits between the full-bleed photo and the '
        'content so the title/percent text stays legible', () {
      expect(pyramidSource, contains('LinearGradient'));
      expect(pyramidSource, contains('AppColors.background.withValues(alpha:'));
    });

    test('the per-card jungle image and its rounded clip are gone — no '
        'longer duplicated now that the background is screen-wide', () {
      expect(pyramidSource, isNot(contains('ClipRRect')));
    });

    test('title and percent-complete text carry an explicit light color — '
        'the default text color would be illegible over the photo', () {
      expect(pyramidSource, contains('color: AppColors.textPrimary'));
    });

    test('CustomAppBar no longer paints the opaque purple-to-blue gradient '
        '— found live: "the top tool bar that has the gradient from purple '
        'to blue, I would like to make transparent"', () {
      expect(homescreenSource, isNot(contains('AppColors.appBarGradient')));
    });

    test('CustomAppBar is translucent (frosted, via BackdropFilter) with '
        'rounded bottom corners, not a flat opaque fill', () {
      expect(homescreenSource, contains('BackdropFilter'));
      expect(homescreenSource, contains('bottomLeft: Radius.circular'));
      expect(homescreenSource, contains('bottomRight: Radius.circular'));
    });

    test('the shared Scaffold sets an explicit backgroundColor — without '
        'it, Flutter\'s Material default (white) would show through the '
        'now-transparent app bar', () {
      expect(homescreenSource, contains('backgroundColor: AppColors.background,\n            appBar: const CustomAppBar'));
    });
  });
}
