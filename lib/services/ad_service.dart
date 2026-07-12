import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/widgets.dart' show AppLifecycleListener, AppLifecycleState;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:life_ops/services/ad_pacer.dart';

// TODO: swap these for the real AdMob interstitial ad unit IDs (created
// under the app's existing AdMob App ID) before release. These are
// Google's official test unit IDs and only ever serve harmless test ads.
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

  String get _adUnitId =>
      Platform.isAndroid ? _androidTestInterstitialUnitId : _iosTestInterstitialUnitId;

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
