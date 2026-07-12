import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/services/ad_pacer.dart';

void main() {
  group('InterstitialPacer', () {
    test('ad becomes due after 5 minutes of foreground activity', () {
      final pacer = InterstitialPacer();
      for (int i = 0; i < 19; i++) {
        pacer.onTick(const Duration(seconds: 15));
      }
      expect(pacer.adDue, isFalse, reason: '4:45 of activity is not enough');
      pacer.onTick(const Duration(seconds: 15));
      expect(pacer.adDue, isTrue, reason: '5:00 of activity is due');
    });

    test('background time never accrues toward an ad', () {
      final pacer = InterstitialPacer();
      pacer.foreground = false;
      for (int i = 0; i < 100; i++) {
        pacer.onTick(const Duration(seconds: 15));
      }
      expect(pacer.adDue, isFalse);

      // Coming back to the foreground resumes accrual from where it left off.
      pacer.foreground = true;
      pacer.onTick(const Duration(minutes: 5));
      expect(pacer.adDue, isTrue);
    });

    test('stays due until an ad actually shows, then resets', () {
      final pacer = InterstitialPacer();
      pacer.onTick(const Duration(minutes: 6));
      expect(pacer.adDue, isTrue);

      // No ad loaded yet: still due on the next tick.
      pacer.onTick(const Duration(seconds: 15));
      expect(pacer.adDue, isTrue);

      pacer.onAdShown();
      expect(pacer.adDue, isFalse);
    });

    test('custom threshold is honored', () {
      final pacer =
          InterstitialPacer(activityThreshold: const Duration(seconds: 30));
      pacer.onTick(const Duration(seconds: 29));
      expect(pacer.adDue, isFalse);
      pacer.onTick(const Duration(seconds: 1));
      expect(pacer.adDue, isTrue);
    });
  });
}
