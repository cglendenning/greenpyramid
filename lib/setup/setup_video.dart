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
        ..enableZoom(false)
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
          // Video player - full screen on iOS, slightly smaller on Android
          if (Platform.isAndroid) ...[
            // Android: Smaller video size to fix touch event issues
            Builder(
              builder: (context) {
                final screenWidth = MediaQuery.of(context).size.width;
                final screenHeight = MediaQuery.of(context).size.height;
                final videoWidth = screenWidth * 0.9; // 90% of screen width
                final videoHeight = videoWidth * 16 / 9; // 16:9 aspect ratio
                final topMargin = (screenHeight - videoHeight) / 2; // Center vertically
                
                return Positioned(
                  top: topMargin,
                  left: (screenWidth - videoWidth) / 2,
                  child: Container(
                    width: videoWidth,
                    height: videoHeight,
                    child: WebViewWidget(controller: _webViewController!),
                  ),
                );
              },
            ),
          ] else ...[
            // iOS: Full screen video (working fine)
            SizedBox.expand(
              child: WebViewWidget(controller: _webViewController!),
            ),
          ],
          
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
                  // Pause video before navigating back
                  try {
                    _webViewController!.runJavaScript('''
                      var iframe = document.querySelector('iframe');
                      if (iframe && iframe.contentWindow) {
                        // Try multiple methods to stop the video
                        iframe.contentWindow.postMessage('{"event":"command","func":"pauseVideo","args":""}', '*');
                        iframe.contentWindow.postMessage('{"event":"command","func":"mute","args":""}', '*');
                        iframe.contentWindow.postMessage('{"event":"command","func":"stopVideo","args":""}', '*');
                        
                        // Also try to pause by modifying the iframe src
                        setTimeout(function() {
                          var currentSrc = iframe.src;
                          if (currentSrc.includes('autoplay=1')) {
                            iframe.src = currentSrc.replace('autoplay=1', 'autoplay=0');
                          }
                        }, 100);
                      }
                    ''');
                  } catch (e) {
                    print('❌ [SETUP VIDEO] Error pausing video: $e');
                  }
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
                onPressed: () async {
                  // Pause video before navigating forward
                  try {
                    _webViewController!.runJavaScript('''
                      var iframe = document.querySelector('iframe');
                      if (iframe && iframe.contentWindow) {
                        // Try multiple methods to stop the video
                        iframe.contentWindow.postMessage('{"event":"command","func":"pauseVideo","args":""}', '*');
                        iframe.contentWindow.postMessage('{"event":"command","func":"mute","args":""}', '*');
                        iframe.contentWindow.postMessage('{"event":"command","func":"stopVideo","args":""}', '*');
                        
                        // Also try to pause by modifying the iframe src
                        setTimeout(function() {
                          var currentSrc = iframe.src;
                          if (currentSrc.includes('autoplay=1')) {
                            iframe.src = currentSrc.replace('autoplay=1', 'autoplay=0');
                          }
                        }, 100);
                      }
                    ''');
                  } catch (e) {
                    print('❌ [SETUP VIDEO] Error pausing video: $e');
                  }
                  
                  // Wait a moment for JavaScript to execute before navigating
                  await Future.delayed(const Duration(milliseconds: 300));
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