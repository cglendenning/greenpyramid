import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D-131: structural regression tests, not a full widget pump — this
/// screen composition calls FirebaseAnalytics.instance the same way every
/// other analytics-logging screen in this codebase does, none of which
/// are pumped in a widget test here either (Firebase Core isn't mocked
/// anywhere in this suite). Same source-text-assertion pattern
/// schedule_habits_screen_test.dart already uses for its D-128 group.
///
/// The toolbar's own look was revised once already, live, in the same
/// session: the first pass (rounded corners, a flat translucent
/// AppColors.surface fill) wasn't what was wanted — "I like what I had
/// before... I really wanted was simply to have more transparency...
/// and to make it look a little glassier like the modern iOS glass
/// interface." The tests below assert the *current*, corrected shape.
void main() {
  group('D-131: main-screen background is full-bleed, toolbar is a '
      'translucent glass version of the original gradient', () {
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

    test('CustomAppBar keeps the original purple-to-blue gradient — '
        'reverted after a first pass replaced it entirely, which wasn\'t '
        'wanted: "I like what I had before"', () {
      expect(homescreenSource, contains('AppColors.appBarGradient'));
    });

    test('the gradient itself is translucent (not a solid fill) over a '
        'BackdropFilter blur — the background photo genuinely shows '
        'through it, blurred, rather than sitting behind an opaque or '
        'flat-tinted panel', () {
      expect(homescreenSource, contains('BackdropFilter'));
      expect(homescreenSource, contains('.withValues(alpha: 0.45)'));
    });

    test('no rounded corners on the toolbar — the original shape had '
        'none, and rounding wasn\'t reaffirmed when the transparency/glass '
        'request was clarified', () {
      expect(homescreenSource, isNot(contains('bottomLeft: Radius.circular')));
      expect(homescreenSource, isNot(contains('bottomRight: Radius.circular')));
    });

    test('the shared Scaffold sets an explicit backgroundColor — without '
        'it, Flutter\'s Material default (white) would show through the '
        'now-transparent app bar', () {
      expect(homescreenSource, contains('backgroundColor: AppColors.background,\n            appBar: const CustomAppBar'));
    });
  });
}
