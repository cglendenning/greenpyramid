import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:life_ops/navbar.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:webview_flutter/webview_flutter.dart';

class Paywall extends StatefulWidget {
  @override
  State<Paywall> createState() => _PaywallState();
}

class _PaywallState extends State<Paywall> {
  WebViewController? _webViewController;
  bool _isMuted = true;
  bool _hasError = false;
  bool _isWebViewReady = false;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    try {
      print('🌐 [PAYWALL VIDEO] Initializing WebView');
      print('🌐 [PAYWALL VIDEO] Loading URL: https://www.stillwatersretreats.com/greenpyramid/paywall-video');
      
      // Load the redirect URL directly - it will redirect to YouTube video after 250ms
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.black)
        ..enableZoom(false)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              print('🌐 [PAYWALL VIDEO] Page started loading: $url');
            },
            onProgress: (int progress) {
              print('🌐 [PAYWALL VIDEO] Loading progress: $progress%');
            },
            onPageFinished: (String url) {
              print('✅ [PAYWALL VIDEO] Page finished loading: $url');
              setState(() {
                _isWebViewReady = true;
              });
            },
            onNavigationRequest: (NavigationRequest request) {
              print('🌐 [PAYWALL VIDEO] Navigation request: ${request.url}');
              return NavigationDecision.navigate;
            },
            onWebResourceError: (WebResourceError error) {
              print('❌ [PAYWALL VIDEO] WebView error: ${error.description}');
              print('❌ [PAYWALL VIDEO] Error code: ${error.errorCode}');
              setState(() {
                _hasError = true;
              });
            },
          ),
        )
        ..loadRequest(Uri.parse('https://www.stillwatersretreats.com/greenpyramid/paywall-video'));
    } catch (e) {
      print('❌ [PAYWALL VIDEO] Error initializing WebView: $e');
      setState(() {
        _hasError = true;
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Widget _buildEmbeddedVideo(BuildContext context) {
    final double aspectRatio = 9 / 16; // Portrait
    final double width = MediaQuery.of(context).size.width;
    final double height = width / aspectRatio;
    if (_hasError) {
      return Container(
        color: Colors.black,
        height: height,
        child: const Center(
          child: Icon(Icons.error_outline, color: Colors.white, size: 48),
        ),
      );
    }
    if (_webViewController == null) {
      return Container(
        color: Colors.black,
        height: height,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    return Stack(
      children: [
        GestureDetector(
          onTap: () {
            try {
              if (_isMuted && _webViewController != null) {
                _webViewController!.runJavaScript('setMute(false);');
                setState(() {
                  _isMuted = false;
                });
              }
            } catch (e) {}
          },
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: Colors.black),
            clipBehavior: Clip.hardEdge,
            child: WebViewWidget(controller: _webViewController!),
          ),
        ),
        if (!_isWebViewReady)
          Container(
            width: width,
            height: height,
            color: Colors.black,
            child: const Center(child: CircularProgressIndicator(color: Colors.white)),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    FirebaseAnalytics analytics = FirebaseAnalytics.instance;
    analytics.logEvent(name: 'paywall');
    var tsTiny = const TextStyle(
        fontSize: 12, fontStyle: FontStyle.normal);

    return SafeArea(
        child: Scaffold(
      appBar: const NavBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            // Hero section
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xff66cc5d).withOpacity(0.1),
                    const Color(0xffC35DCC).withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.psychology,
                    size: 48,
                    color: Color(0xff66cc5d),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Unlock Unlimited Coaching',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Get personalized guidance from your AI Green Pyramid coach',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Price section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'Only',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '\$14.95',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff66cc5d),
                    ),
                  ),
                  const Text(
                    'per month',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Coaching methodology section
            const Text(
              'Your Personal AI Green Pyramid Coach',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Powered by the Green Pyramid methodology and decades of coaching wisdom',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 24),
            
            _buildEmbeddedVideo(context),
            
            // Features section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'What You Get:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildFeatureItem(
                    Icons.chat_bubble_outline,
                    'Unlimited Coaching Sessions',
                    'Chat as much as you want with your AI coach',
                  ),
                  _buildFeatureItem(
                    Icons.psychology,
                    'Personalized Insights',
                    'Get advice based on your actual habit tracking data',
                  ),
                  _buildFeatureItem(
                    Icons.trending_up,
                    'Progress Analysis',
                    'Deep analysis of your habit patterns',
                  ),
                  _buildFeatureItem(
                    Icons.lightbulb_outline,
                    'Expert Methodology',
                    'Based on proven coaching techniques from world-class experts',
                  ),
                  _buildFeatureItem(
                    Icons.schedule,
                    '24/7 Availability',
                    'Get coaching and inspiration whenever you need it',
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // CTA button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  subscribe(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff66cc5d),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                child: const Text(
                  'Start Unlimited Coaching',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Guarantee
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xff66cc5d).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.verified,
                    color: Color(0xff66cc5d),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: const Text(
                      'Cancel anytime • No commitment required',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            Text(legal(), style: tsTiny),
            const SizedBox(height: 16),
            Terms(),
          ],
        ),
      ),
    ));
  }

  Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xff66cc5d).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: const Color(0xff66cc5d),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String legal() {
    String legal = '';
    if (Platform.isAndroid) {
      legal = "A \$14.95 monthly purchase will be applied "
          "to your Google account upon subscribing. "
          "Subscriptions will automatically renew monthly "
          "unless canceled within 24-hours before the end of the "
          "current period. You can cancel anytime in your Google play "
          "account settings.";
    } else if (Platform.isIOS) {
      legal = "A \$14.95 monthly purchase will be applied "
          "to your iTunes account upon subscribing. "
          "Subscriptions will automatically renew "
          "unless canceled within 24-hours before the end of the "
          "current period. You can cancel anytime with your iTunes "
          "account settings. For more information, see our Terms of Use (EULA) "
          "and Privacy Policy links below.";
    }
    return legal;
  }

  void subscribe(BuildContext context) async {
    List<String> productIDs = [];

    if (Platform.isAndroid) {
      productIDs = ['lifeops_premium_v1'];
    } else if (Platform.isIOS) {
      productIDs = ['lifeops_premium_monthly_1495'];
    } else {
      return;
    }
    showLoaderDialog(context);
    try {
      List<StoreProduct> storeProduct = await Purchases.getProducts(productIDs);
      await Purchases.purchaseStoreProduct(storeProduct.first);
      // Only pop the dialog and the paywall if the purchase is successful
      Navigator.pop(context); // pop the dialog box
      Navigator.pop(context); // pop back to the subscription-only feature
    } catch (e) {
      // Always pop the dialog if it is open
      Navigator.pop(context); // pop the dialog box
      
      // Handle specific Android billing error
      if (Platform.isAndroid && e.toString().contains('Billing is not available')) {
        _showAndroidBillingError(context);
      } else {
        // Handle other errors silently or show a generic message
        print('Purchase error: $e');
      }
    }
  }

  void _showAndroidBillingError(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.orange,
                size: 24,
              ),
              SizedBox(width: 8),
              Text(
                'Google Play Store Issue',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Unable to access Google Play billing. This usually happens when:',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 12),
              Text(
                '• You\'re not signed into your Google account\n'
                '• Google Play Store needs to be updated\n'
                '• Google Play Store cache needs to be cleared',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              SizedBox(height: 12),
              Text(
                'Please try:\n'
                '1. Sign into your Google account in Play Store\n'
                '2. Update Google Play Store\n'
                '3. Clear Play Store cache in Settings > Apps > Google Play Store > Storage > Clear Cache',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'OK',
                style: TextStyle(
                  color: Color(0xff66cc5d),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  showLoaderDialog(BuildContext context){
    AlertDialog alert=AlertDialog(
      content: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          Container(margin: const EdgeInsets.only(left: 7),child:const Text("Subscribing..." )),
        ],),
    );
    showDialog(barrierDismissible: false,
      context:context,
      builder:(BuildContext context){
        return alert;
      },
    );
  }

}

class Terms extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var row;
    if (Platform.isAndroid) {
      row = const Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[]);
    } else if (Platform.isIOS) {
      row = Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            RichText(
              text: TextSpan(
                  text: 'Terms Of Service',
                  style: const TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                      fontSize: 12),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      // https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
                      final Uri eula = Uri(
                          scheme: 'https',
                          host: 'www.apple.com',
                          path: 'legal/internet-services/itunes/dev/stdeula/');
                      launchInBrowser(eula);
                    }),
            ),
            RichText(
              text: TextSpan(
                  text: 'Privacy Policy',
                  style: const TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                      fontSize: 12),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      // https://cglendenning123.wixsite.com/growingconcerns
                      final Uri eula = Uri(
                          scheme: 'https',
                          host: 'cglendenning123.wixsite.com',
                          path: 'growingconcerns');
                      launchInBrowser(eula);
                    }),
            ),
          ]);
    }
    return row;
  }
}

Future<void> launchInBrowser(Uri url) async {
  if (!await launchUrl(
    url,
    mode: LaunchMode.externalApplication,
  )) {
    throw Exception('Could not launch $url');
  }
}
