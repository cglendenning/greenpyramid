import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D-142: structural regression test, not a full widget pump — the
/// native launch/splash screen (iOS's LaunchScreen.storyboard, Android's
/// launch_background.xml) renders before Flutter's engine draws its
/// first frame, so none of it is reachable from `flutter test`. Same
/// source-text-assertion pattern main_stale_session_test.dart already
/// uses for main.dart's routing logic.
///
/// Found live: the app showed a plain white screen for 1-2 seconds on
/// launch, before Flutter's first frame — the default Flutter template's
/// LaunchScreen.storyboard/launch_background.xml, both still on their
/// out-of-the-box white background with an effectively blank image.
/// Owner: "what I would like is a splash screen that is dark with a
/// center icon of a glowing Green Pyramid."
void main() {
  group('D-142: a dark splash screen with the glowing brand pyramid, '
      'shown natively before Flutter draws its first frame', () {
    test('iOS LaunchScreen.storyboard uses the app\'s dark background '
        'color, not the default white', () {
      final storyboard =
          File('ios/Runner/Base.lproj/LaunchScreen.storyboard').readAsStringSync();
      expect(storyboard, isNot(contains('red="1" green="1" blue="1"')),
          reason: 'the default Flutter white background must be gone');
      // AppColors.background (#0B0B0F) as 0-1 float components.
      expect(storyboard, contains('red="0.043" green="0.043" blue="0.059"'));
    });

    test('the LaunchImage asset (the glowing pyramid) exists at all three '
        'iOS scale factors', () {
      const dir = 'ios/Runner/Assets.xcassets/LaunchImage.imageset';
      expect(File('$dir/LaunchImage.png').existsSync(), isTrue);
      expect(File('$dir/LaunchImage@2x.png').existsSync(), isTrue);
      expect(File('$dir/LaunchImage@3x.png').existsSync(), isTrue);
    });

    test('Android\'s launch_background.xml (both the default and the '
        'v21 variant) use the dark splash color and the pyramid bitmap, '
        'not the default white with no image', () {
      for (final path in [
        'android/app/src/main/res/drawable/launch_background.xml',
        'android/app/src/main/res/drawable-v21/launch_background.xml',
      ]) {
        final xml = File(path).readAsStringSync();
        expect(xml, isNot(contains('@android:color/white')));
        expect(xml, isNot(contains('?android:colorBackground')));
        expect(xml, contains('@color/splash_background'));
        expect(xml, contains('@drawable/launch_pyramid'));
      }
    });

    test('the pyramid bitmap exists at every Android density bucket', () {
      for (final density in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
        expect(
          File('android/app/src/main/res/drawable-$density/launch_pyramid.png')
              .existsSync(),
          isTrue,
          reason: '$density bucket must have the pyramid asset',
        );
      }
    });

    test('splash_background is defined as the app\'s own dark background '
        'color, #0B0B0F', () {
      final colors =
          File('android/app/src/main/res/values/colors.xml').readAsStringSync();
      expect(colors, contains('name="splash_background">#0B0B0F<'));
    });

    test('the light-mode LaunchTheme uses light (white) status bar icons, '
        'since the splash background is always dark regardless of the '
        'system light/dark setting', () {
      final styles =
          File('android/app/src/main/res/values/styles.xml').readAsStringSync();
      final launchThemeStart = styles.indexOf('name="LaunchTheme"');
      final launchThemeEnd = styles.indexOf('</style>', launchThemeStart);
      final launchThemeBody =
          styles.substring(launchThemeStart, launchThemeEnd);
      expect(launchThemeBody, contains('windowLightStatusBar">false'));
    });
  });
}
