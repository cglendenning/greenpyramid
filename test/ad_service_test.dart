import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/services/ad_service.dart';

// Google's published test unit ids and this app's real production unit ids.
// Hard-coded here (not imported) so the test fails loudly if a code change ever
// swaps which id a build serves.
const _androidTest = 'ca-app-pub-3940256099942544/1033173712';
const _iosTest = 'ca-app-pub-3940256099942544/4411468910';
const _androidReal = 'ca-app-pub-4402198490627677/3511486167';
const _iosReal = 'ca-app-pub-4402198490627677/6515271064';

void main() {
  group('resolveInterstitialUnitId', () {
    test('serves live units only when test units are not forced', () {
      expect(
        resolveInterstitialUnitId(isAndroid: true, useTestUnits: false),
        _androidReal,
      );
      expect(
        resolveInterstitialUnitId(isAndroid: false, useTestUnits: false),
        _iosReal,
      );
    });

    test('serves Google test units when test units are forced', () {
      expect(
        resolveInterstitialUnitId(isAndroid: true, useTestUnits: true),
        _androidTest,
      );
      expect(
        resolveInterstitialUnitId(isAndroid: false, useTestUnits: true),
        _iosTest,
      );
    });

    test('never serves a live unit while test units are forced', () {
      // The whole point of the invalid-traffic fix: a forced-test build must
      // never fall through to a production unit on either platform.
      for (final isAndroid in [true, false]) {
        final id = resolveInterstitialUnitId(
          isAndroid: isAndroid,
          useTestUnits: true,
        );
        expect(id, isNot(_androidReal));
        expect(id, isNot(_iosReal));
      }
    });
  });

  group('decideResumeFlush (transition-gated interstitial)', () {
    test('a due ad is never flushed on a cold-start resume', () {
      // First resume of the process: nothing was backgrounded, so even a due
      // ad must not pop on launch.
      final d = decideResumeFlush(
        resumed: true,
        wasBackgrounded: false,
        adDue: true,
      );
      expect(d.flush, isFalse);
      expect(d.wasBackgrounded, isFalse);
    });

    test('a due ad flushes on a genuine background->foreground resume', () {
      final d = decideResumeFlush(
        resumed: true,
        wasBackgrounded: true,
        adDue: true,
      );
      expect(d.flush, isTrue);
      expect(d.wasBackgrounded, isFalse);
    });

    test('resuming with no ad due does not flush', () {
      final d = decideResumeFlush(
        resumed: true,
        wasBackgrounded: true,
        adDue: false,
      );
      expect(d.flush, isFalse);
      expect(d.wasBackgrounded, isFalse);
    });

    test('leaving the foreground never flushes and marks backgrounded', () {
      final d = decideResumeFlush(
        resumed: false,
        wasBackgrounded: false,
        adDue: true,
      );
      expect(d.flush, isFalse);
      expect(d.wasBackgrounded, isTrue);
    });
  });
}
