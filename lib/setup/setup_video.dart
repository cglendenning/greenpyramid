import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:life_ops/setup/setup4.dart';
import 'package:life_ops/utils.dart' as utils;
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

class SetupVideo extends StatefulWidget {
  final List<String>? categories;

  const SetupVideo({super.key, this.categories});

  @override
  State<SetupVideo> createState() => _SetupVideoState();
}

class _SetupVideoState extends State<SetupVideo> {
  WebViewController? _webViewController;
  bool _hasError = false;
  bool _isWebViewReady = false;

  @override
  void initState() {
    super.initState();
    // Force portrait orientation after first frame for reliability on iOS
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    });
    _initializeWebView();
  }

  void _initializeWebView() {
    try {
      if (kDebugMode) {
        print('🌐 [SETUP VIDEO] Initializing WebView');
      }
      if (kDebugMode) {
        print(
            '🌐 [SETUP VIDEO] Loading URL: https://www.stillwatersretreats.com/greenpyramid/setup-video');
      }

      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.black)
        ..enableZoom(false)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              if (kDebugMode) {
                print('🌐 [SETUP VIDEO] Page started loading: $url');
              }
            },
            onProgress: (int progress) {
              if (kDebugMode) {
                print('🌐 [SETUP VIDEO] Loading progress: $progress%');
              }
            },
            onPageFinished: (String url) {
              if (kDebugMode) {
                print('✅ [SETUP VIDEO] Page finished loading: $url');
              }
              setState(() {
                _isWebViewReady = true;
              });
            },
            onNavigationRequest: (NavigationRequest request) {
              if (kDebugMode) {
                print('🌐 [SETUP VIDEO] Navigation request: ${request.url}');
              }
              return NavigationDecision.navigate;
            },
            onWebResourceError: (WebResourceError error) {
              if (kDebugMode) {
                print('❌ [SETUP VIDEO] WebView error: ${error.description}');
              }
              if (kDebugMode) {
                print('❌ [SETUP VIDEO] Error code: ${error.errorCode}');
              }
              setState(() {
                _hasError = true;
              });
            },
          ),
        )
        ..loadRequest(Uri.parse(
            'https://www.stillwatersretreats.com/greenpyramid/setup-video'));
    } catch (e) {
      if (kDebugMode) {
        print('❌ [SETUP VIDEO] Error initializing WebView: $e');
      }
      setState(() {
        _hasError = true;
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    if (_hasError) {
      return _buildErrorUI();
    }
    if (Platform.isIOS) {
      return _IOSSetupVideoPlayer(categories: widget.categories);
    }
    if (_webViewController == null) {
      return _buildErrorUI();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Android: Smaller video size to fix touch event issues (restore 16:9 aspect ratio)
          Builder(
            builder: (context) {
              final screenWidth = MediaQuery.of(context).size.width;
              final screenHeight = MediaQuery.of(context).size.height;
              final videoWidth = screenWidth * 0.9; // 90% of screen width
              final videoHeight = videoWidth * 16 / 9; // 16:9 aspect ratio
              final topMargin =
                  (screenHeight - videoHeight) / 2; // Center vertically
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
                    if (kDebugMode) {
                      print('❌ [SETUP VIDEO] Error pausing video: $e');
                    }
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
                    if (kDebugMode) {
                      print('❌ [SETUP VIDEO] Error pausing video: $e');
                    }
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

// --- iOS dynamic video player widget ---
class _IOSSetupVideoPlayer extends StatefulWidget {
  final List<String>? categories;
  const _IOSSetupVideoPlayer({this.categories});
  @override
  State<_IOSSetupVideoPlayer> createState() => _IOSSetupVideoPlayerState();
}

class _IOSSetupVideoPlayerState extends State<_IOSSetupVideoPlayer> {
  String? _videoId;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _resolveVideoId();
  }

  Future<void> _resolveVideoId() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final response = await http.get(Uri.parse(
          'https://www.stillwatersretreats.com/greenpyramid/setup-video'));
      if (kDebugMode) {
        print('Status: ${response.statusCode}, Headers: ${response.headers}');
      }
      if (kDebugMode) {
        print('Request URL: ${response.request?.url}');
      }
      if (kDebugMode) {
        print('Body: ${response.body}');
      }
      String? youtubeUrl;
      final document = html_parser.parse(response.body);
      final iframe = document.querySelector('iframe');
      if (iframe != null) {
        youtubeUrl = iframe.attributes['src'];
        if (kDebugMode) {
          print('Found iframe src: $youtubeUrl');
        }
      }
      final id = youtubeUrl != null ? _extractYouTubeId(youtubeUrl) : null;
      if (kDebugMode) {
        print('Extracted YouTube ID: $id');
      }
      if (id != null && id.isNotEmpty) {
        setState(() {
          _videoId = id;
          _loading = false;
        });
      } else {
        setState(() {
          _error = true;
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  String? _extractYouTubeId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    // Handles both youtu.be and youtube.com URLs
    if (uri.host.contains('youtu.be')) {
      return uri.pathSegments.isNotEmpty ? uri.pathSegments[0] : null;
    }
    if (uri.host.contains('youtube.com')) {
      if (uri.path == '/watch') {
        return uri.queryParameters['v'];
      }
      // /embed/VIDEOID
      if (uri.pathSegments.isNotEmpty && uri.pathSegments[0] == 'embed') {
        return uri.pathSegments.length > 1 ? uri.pathSegments[1] : null;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    if (_error || _videoId == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 64),
              const SizedBox(height: 16),
              const Text('Could not load video',
                  style: TextStyle(color: Colors.white)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _resolveVideoId,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    // Use overlays for navigation
    return _IOSSetupVideoWithOverlays(
      videoId: _videoId!,
      categories: widget.categories ?? [],
    );
  }
}

class _IOSSetupVideoWithOverlays extends StatefulWidget {
  final String videoId;
  final List<String> categories;
  const _IOSSetupVideoWithOverlays(
      {required this.videoId, required this.categories});

  @override
  State<_IOSSetupVideoWithOverlays> createState() =>
      _IOSSetupVideoWithOverlaysState();
}

class _IOSSetupVideoWithOverlaysState
    extends State<_IOSSetupVideoWithOverlays> {
  bool showOverlays = true;
  late WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('PlayerStateChannel',
          onMessageReceived: (JavaScriptMessage message) {
        // YouTube player states: 1 = playing, 2 = paused
        if (kDebugMode) {
          print('[PlayerStateChannel] Received: ${message.message}');
        }
        if (message.message == '1') {
          setState(() {
            showOverlays = false;
          });
        } else if (message.message == '2') {
          setState(() {
            showOverlays = true;
          });
        }
      })
      ..setNavigationDelegate(NavigationDelegate())
      ..loadHtmlString(_getVideoEmbedHtml(widget.videoId));
  }

  String _getVideoEmbedHtml(String videoId) {
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body { margin: 0; padding: 0; background: #000; display: flex; justify-content: center; align-items: center; min-height: 100vh; }
        .video-container { width: 100vw; height: 100vh; position: relative; }
        iframe { width: 100vw; height: 100vh; border: none; }
    </style>
</head>
<body>
    <div class="video-container">
        <iframe id="ytplayer" src="https://www.youtube.com/embed/$videoId?enablejsapi=1&autoplay=1&rel=0&showinfo=0" allow="autoplay; encrypted-media" allowfullscreen></iframe>
    </div>
    <script>
      var tag = document.createElement('script');
      tag.src = "https://www.youtube.com/iframe_api";
      var firstScriptTag = document.getElementsByTagName('script')[0];
      firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);
      var player;
      function onYouTubeIframeAPIReady() {
        player = new YT.Player('ytplayer', {
          events: {
            'onStateChange': onPlayerStateChange
          }
        });
      }
      function onPlayerStateChange(event) {
        // 1 = playing, 2 = paused
        console.log('[JS] Player state: ' + event.data);
        PlayerStateChannel.postMessage(event.data.toString());
      }
      function playVideo() {
        if (player) player.playVideo();
      }
      function pauseVideo() {
        if (player) player.pauseVideo();
      }
    </script>
</body>
</html>
    ''';
  }

  void _toggleOverlaysAndPausePlay() async {
    if (showOverlays) {
      // Hide overlays and play video
      setState(() {
        showOverlays = false;
      });
      try {
        await _controller.runJavaScript('playVideo();');
      } catch (_) {}
    } else {
      // Show overlays and pause video
      setState(() {
        showOverlays = true;
      });
      try {
        await _controller.runJavaScript('pauseVideo();');
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      print('[OverlayDebug] build called, showOverlays: $showOverlays');
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleOverlaysAndPausePlay,
            child: WebViewWidget(controller: _controller),
          ),
          if (showOverlays) ...[
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
                  onPressed: () async {
                    utils.Utils().changeSystemColor(Brightness.dark);
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => Setup4(widget.categories)),
                    ).then((_) {
                      utils.Utils().changeSystemColor(Brightness.light);
                    });
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
