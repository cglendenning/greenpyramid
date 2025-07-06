import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:life_ops/setup/setup4.dart';
import 'package:life_ops/utils.dart' as utils;
import 'dart:io' show Platform;

class SetupVideo extends StatefulWidget {
  final List<String>? categories;
  
  const SetupVideo({super.key, this.categories});

  @override
  State<SetupVideo> createState() => _SetupVideoState();
}

class _SetupVideoState extends State<SetupVideo> {
  WebViewController? _webViewController;
  bool _isMuted = true;
  bool _hasError = false;
  bool _isWebViewReady = false;

  @override
  void initState() {
    super.initState();
    
    // Force portrait orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    
    _initializeWebView();
  }

  void _initializeWebView() {
    try {
      print('🌐 [SETUP VIDEO] Initializing WebView');
      print('🌐 [SETUP VIDEO] Loading URL: https://www.stillwatersretreats.com/greenpyramid/setup-video');
      
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.black)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              print('🌐 [SETUP VIDEO] Page started loading: $url');
            },
            onProgress: (int progress) {
              print('🌐 [SETUP VIDEO] Loading progress: $progress%');
            },
            onPageFinished: (String url) {
              print('✅ [SETUP VIDEO] Page finished loading: $url');
              setState(() {
                _isWebViewReady = true;
              });
            },
            onNavigationRequest: (NavigationRequest request) {
              print('🌐 [SETUP VIDEO] Navigation request: ${request.url}');
              return NavigationDecision.navigate;
            },
            onWebResourceError: (WebResourceError error) {
              print('❌ [SETUP VIDEO] WebView error: ${error.description}');
              print('❌ [SETUP VIDEO] Error code: ${error.errorCode}');
              setState(() {
                _hasError = true;
              });
            },
          ),
        )
        ..loadRequest(Uri.parse('https://www.stillwatersretreats.com/greenpyramid/setup-video'));
        
    } catch (e) {
      print('❌ [SETUP VIDEO] Error initializing WebView: $e');
      setState(() {
        _hasError = true;
      });
    }
  }

  @override
  void dispose() {
    // Reset orientation to allow all orientations when leaving
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildErrorUI();
    }
    
    if (_webViewController == null) {
      return _buildErrorUI();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Full screen WebView video player
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
            child: SizedBox.expand(
              child: WebViewWidget(controller: _webViewController!),
            ),
          ),
          
          // Loading indicator
          if (!_isWebViewReady)
            Container(
              color: Colors.black,
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              ),
            ),
          
          // Floating back arrow (left side, centered vertically)
          Positioned(
            left: 20,
            top: MediaQuery.of(context).size.height / 2 - 30,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios,
                  color: Colors.white,
                  size: 24,
                ),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ),
          ),
          
          // Floating forward arrow (right side, centered vertically)
          Positioned(
            right: 20,
            top: MediaQuery.of(context).size.height / 2 - 30,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white,
                  size: 24,
                ),
                onPressed: () {
                  navigateToSetup4();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorUI() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'Video could not be loaded',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _hasError = false;
                });
                _initializeWebView();
              },
              child: const Text('Retry'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                navigateToSetup4();
              },
              child: const Text(
                'Skip Video',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void navigateToSetup4() async {
    utils.Utils().changeSystemColor(Brightness.dark);
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => Setup4(widget.categories ?? [])),
    ).then((_) {
      setState(() {
        utils.Utils().changeSystemColor(Brightness.light);
      });
    });
  }
} 