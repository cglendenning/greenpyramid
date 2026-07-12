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

  // Guarantees an interstitial at minimum every 5 minutes of foreground
  // activity, independent of which screens the user visits: a periodic
  // tick accrues foreground time on the pacer and shows an ad as soon as
  // one is due (retrying on later ticks if no ad was loaded yet).
  // Event-driven triggers (chat messages, screen exits) still call
  // showInterstitialIfEligible directly; a show from any path resets the
  // pacer so the user never gets two ads back to back.
  void startActivityPacing() {
    if (_pacerTimer != null) return;
    _lifecycleListener = AppLifecycleListener(
      onStateChange: (state) {
        _pacer.foreground = state == AppLifecycleState.resumed;
      },
    );
    _pacerTimer = Timer.periodic(_pacerTick, (_) async {
      _pacer.onTick(_pacerTick);
      if (_pacer.adDue) {
        await showInterstitialIfEligible();
      }
    });
  }

  // Visible for completeness; the singleton normally lives for the whole
  // app session, so this is only exercised by tests or a future teardown.
  void stopActivityPacing() {
    _pacerTimer?.cancel();
    _pacerTimer = null;
    _lifecycleListener?.dispose();
    _lifecycleListener = null;
  }

  // Real ad units in release, Google's test units in debug (see the unit-id
  // comments above for why).
  String get _adUnitId {
    if (Platform.isAndroid) {
      return kDebugMode
          ? _androidTestInterstitialUnitId
          : _androidInterstitialUnitId;
    }
    return kDebugMode ? _iosTestInterstitialUnitId : _iosInterstitialUnitId;
  }

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
