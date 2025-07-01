import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:io';

class Ads {

  final String testDevice = 'ac0a2fbd47a6c4816f91dd350018e4d7';
  final int maxFailedLoadAttempts = 3;

  InterstitialAd? _interstitialAd;
  // int _numInterstitialLoadAttempts = 0;

  void loadAndShowInterstitialAd() async {

    AdRequest request = const AdRequest();

    // Real Ids
    String androidAdUnitId = 'ca-app-pub-4402198490627677/3511486167';
    String iOSAdUnitId = 'ca-app-pub-4402198490627677/6515271064';

    // Demo Ids
    // String androidAdUnitId = 'ca-app-pub-3940256099942544/1033173712';
    // String iOSAdUnitId = 'ca-app-pub-3940256099942544/4411468910';

    await InterstitialAd.load(
      // Demo Ad Unit Ids
        adUnitId: Platform.isAndroid
            ? androidAdUnitId // Android Demo Ad Unit Id
            : iOSAdUnitId, // iOS Demo Ad Unit Id
        request: request,
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (InterstitialAd ad) {
            _interstitialAd = ad;
            // _numInterstitialLoadAttempts = 0;
            _interstitialAd!.setImmersiveMode(true);
          },
          onAdFailedToLoad: (LoadAdError error) {
            // _numInterstitialLoadAttempts += 1;
            _interstitialAd = null;
            // if (_numInterstitialLoadAttempts < maxFailedLoadAttempts) {
            //   loadAndShowInterstitialAd();
            // }
          },
        ));

    // Hack! There must be a better way to determine if the ad is loaded.
    while (_interstitialAd == null) {
      await Future.delayed(const Duration(seconds: 1));
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (InterstitialAd ad) =>
          print('ad onAdShowedFullScreenContent.'),
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        print('$ad onAdDismissedFullScreenContent.');
        ad.dispose();
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
        print('$ad onAdFailedToShowFullScreenContent: $error');
        ad.dispose();
      },
    );
    _interstitialAd!.show();
    _interstitialAd = null;
  }
}
