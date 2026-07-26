import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/widgets.dart' show AppLifecycleListener, AppLifecycleState;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:life_ops/services/ad_pacer.dart';
import 'package:life_ops/services/usage_ledger.dart';

// Real production interstitial ad unit IDs from the AdMob console, under
// this app's registered AdMob apps (publisher 4402198490627677).
const String _iosInterstitialUnitId =
    'ca-app-pub-4402198490627677/6515271064';
const String _androidInterstitialUnitId =
    'ca-app-pub-4402198490627677/3511486167';

// Google's official test unit IDs — they only ever serve harmless test ads.
// Debug builds use these so live ads are never requested or tapped during
// development, which AdMob treats as invalid traffic and can suspend the
// account for.
const String _androidTestInterstitialUnitId =
    'ca-app-pub-3940256099942544/1033173712';
const String _iosTestInterstitialUnitId =
    'ca-app-pub-3940256099942544/4411468910';

// Forces Google's *test* ad units even in a release build. Any artifact that
// isn't the real Play Store / App Store download — i.e. an OTA/sideload we hand
// to one of our own phones — must serve test ads, otherwise the SDK requests
// *live* ads and every impression or tap from our own device is invalid traffic
// that AdMob can (and did) suspend the account over. Kept in lockstep with the
// OTA App Check debug flag: every OTA build already passes
// FORCE_APP_CHECK_DEBUG, so it can't accidentally serve live ads even if the
// dedicated flag is forgotten. Pass `--dart-define=ADMOB_TEST=true` to force it
// on independently.
const bool _forceTestAds =
    bool.fromEnvironment('ADMOB_TEST', defaultValue: false) ||
    bool.fromEnvironment('FORCE_APP_CHECK_DEBUG', defaultValue: false);

/// Pure selection of the interstitial ad unit id, extracted so it can be
/// unit-tested without a running engine. [useTestUnits] folds together debug
/// mode and the force-test-ads signal; [isAndroid] picks the platform's unit.
String resolveInterstitialUnitId({
  required bool isAndroid,
  required bool useTestUnits,
}) {
  if (isAndroid) {
    return useTestUnits
        ? _androidTestInterstitialUnitId
        : _androidInterstitialUnitId;
  }
  return useTestUnits ? _iosTestInterstitialUnitId : _iosInterstitialUnitId;
}

/// Outcome of the lifecycle reducer below: the updated backgrounded flag and
/// whether a pacing-due interstitial should be flushed on this transition.
class ResumeFlushDecision {
  const ResumeFlushDecision({
    required this.wasBackgrounded,
    required this.flush,
  });
  final bool wasBackgrounded;
  final bool flush;
}

/// Pure lifecycle reducer for transition-gated interstitials. A due ad may only
/// flush on a genuine background->foreground resume — a natural transition —
/// never on a cold start (nothing has accrued) and never while the app simply
/// stays foregrounded. This is what keeps an interstitial from popping
/// mid-interaction, the placement that generates invalid impressions.
ResumeFlushDecision decideResumeFlush({
  required bool resumed,
  required bool wasBackgrounded,
  required bool adDue,
}) {
  if (!resumed) {
    return const ResumeFlushDecision(wasBackgrounded: true, flush: false);
  }
  return ResumeFlushDecision(
    wasBackgrounded: false,
    flush: wasBackgrounded && adDue,
  );
}

class AdService {
  AdService._();
  static final AdService instance = AdService._();

  static const Duration _cooldown = Duration(minutes: 5);
  static const Duration _pacerTick = Duration(seconds: 15);

  InterstitialAd? _interstitialAd;
  DateTime? _lastShownAt;

  final InterstitialPacer _pacer = InterstitialPacer();
  Timer? _pacerTimer;
  AppLifecycleListener? _lifecycleListener;
  bool _wasBackgrounded = false;

  // Accrues at most one interstitial per 5 minutes of foreground activity, but
  // only ever *shows* it at a natural transition — never mid-interaction, which
  // is the placement AdMob treats as an invalid impression. The periodic tick
  // just accrues foreground time on the pacer; a due ad is flushed either when
  // the user brings the app back to the foreground (handled here) or via the
  // event-driven triggers (chat messages, screen exits) that call
  // showInterstitialIfEligible directly. A show from any path resets the pacer
  // so the user never gets two ads back to back.
  void startActivityPacing() {
    if (_pacerTimer != null) return;
    _lifecycleListener = AppLifecycleListener(
      onStateChange: (state) {
        final resumed = state == AppLifecycleState.resumed;
        _pacer.foreground = resumed;
        final decision = decideResumeFlush(
          resumed: resumed,
          wasBackgrounded: _wasBackgrounded,
          adDue: _pacer.adDue,
        );
        _wasBackgrounded = decision.wasBackgrounded;
        if (decision.flush) {
          unawaited(showInterstitialIfEligible());
        }
      },
    );
    // Timer only accrues time; it no longer shows an ad on the raw tick.
    _pacerTimer = Timer.periodic(_pacerTick, (_) => _pacer.onTick(_pacerTick));
  }

  // Visible for completeness; the singleton normally lives for the whole
  // app session, so this is only exercised by tests or a future teardown.
  void stopActivityPacing() {
    _pacerTimer?.cancel();
    _pacerTimer = null;
    _lifecycleListener?.dispose();
    _lifecycleListener = null;
  }

  // Real ad units only in a genuine store release; Google's test units in debug
  // and in any OTA/sideload build (see the unit-id comments above for why).
  String get _adUnitId => resolveInterstitialUnitId(
        isAndroid: Platform.isAndroid,
        useTestUnits: kDebugMode || _forceTestAds,
      );

  void preload() {
    InterstitialAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (error) {
          if (kDebugMode) {
            print('AdService: interstitial failed to load: $error');
          }
          _interstitialAd = null;
        },
      ),
    );
  }

  // Shows a full-screen interstitial only if at least 5 minutes have passed
  // since the last one was shown. A no-op (navigation just continues) if
  // we're still in the cooldown window or no ad is loaded yet.
  Future<void> showInterstitialIfEligible() async {
    final now = DateTime.now();
    if (_lastShownAt != null && now.difference(_lastShownAt!) < _cooldown) {
      return;
    }

    final ad = _interstitialAd;
    if (ad == null) {
      preload();
      return;
    }

    _interstitialAd = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      // Credit the ledger only on a confirmed impression (the revenue
      // event), so a failed or unshown ad never funds AI usage.
      onAdImpression: (ad) {
        UsageLedger.instance.creditAdImpression();
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        preload();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        preload();
      },
    );
    _lastShownAt = now;
    _pacer.onAdShown();
    await ad.show();
  }
}
