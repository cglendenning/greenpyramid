// Pure pacing logic for the recurring interstitial: accumulates foreground
// ("activity") time and reports when enough has elapsed since the last ad.
// Kept free of plugin/timer dependencies so it is unit-testable; AdService
// owns the actual Timer, lifecycle wiring, and ad plugin calls.
class InterstitialPacer {
  InterstitialPacer({this.activityThreshold = const Duration(minutes: 5)});

  final Duration activityThreshold;

  bool foreground = true;
  Duration _activeSinceLastAd = Duration.zero;

  // Called on every timer tick with the elapsed interval. Only foreground
  // time counts as activity; background time never accrues toward an ad.
  void onTick(Duration delta) {
    if (foreground) {
      _activeSinceLastAd += delta;
    }
  }

  // True once the user has accumulated the threshold of foreground
  // activity since the last shown ad. Stays true until an ad actually
  // shows, so a not-yet-loaded ad is retried on following ticks.
  bool get adDue => _activeSinceLastAd >= activityThreshold;

  void onAdShown() {
    _activeSinceLastAd = Duration.zero;
  }
}
