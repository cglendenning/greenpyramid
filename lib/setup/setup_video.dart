import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:life_ops/setup/setup4.dart';
import 'package:life_ops/setup/video_preloader.dart';
import 'package:life_ops/utils.dart' as utils;
import 'dart:io' show Platform;

class SetupVideo extends StatefulWidget {
  final List<String>? categories;
  
  const SetupVideo({super.key, this.categories});

  @override
  State<SetupVideo> createState() => _SetupVideoState();
}

class _SetupVideoState extends State<SetupVideo> {
  YoutubePlayerController? _youtubeController;
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
    
    // Initialize appropriate video player based on platform
    if (Platform.isAndroid) {
      _initializeWebView();
    } else {
      _initializeYouTubePlayer();
    }
  }

  void _initializeWebView() {
    try {
      print('🌐 [SETUP VIDEO] Initializing WebView for Android');
      
      // Create WebView controller with YouTube embed
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.black)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (String url) {
              setState(() {
                _isWebViewReady = true;
              });
              print('✅ [SETUP VIDEO] WebView loaded successfully');
            },
            onWebResourceError: (WebResourceError error) {
              print('❌ [SETUP VIDEO] WebView error: ${error.description}');
              setState(() {
                _hasError = true;
              });
            },
          ),
        )
        ..loadHtmlString(_getYouTubeEmbedHtml());
        
    } catch (e) {
      print('❌ [SETUP VIDEO] Error initializing WebView: $e');
      setState(() {
        _hasError = true;
      });
    }
  }

  String _getYouTubeEmbedHtml() {
    const videoId = '4H9qCQo_Y8s';
    return '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          body {
            margin: 0;
            padding: 0;
            background-color: #000;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
          }
          .video-container {
            position: relative;
            width: 100%;
            height: 100%;
            max-width: 100vw;
            max-height: 100vh;
          }
          iframe {
            width: 100%;
            height: 100%;
            border: none;
          }
          .iframe-muted {
            display: block;
          }
          .iframe-unmuted {
            display: none;
          }
        </style>
        <script>
          var isMuted = true;
          var mutedIframe = null;
          var unmutedIframe = null;
          
          function onIframeLoad() {
            mutedIframe = document.getElementById('iframe-muted');
            unmutedIframe = document.getElementById('iframe-unmuted');
          }
          
          function pauseIframe(iframe) {
            if (iframe && iframe.contentWindow) {
              try {
                iframe.contentWindow.postMessage('{"event":"command","func":"pauseVideo","args":""}', '*');
              } catch (e) {
                // Fallback: try to pause by modifying src
                var currentSrc = iframe.src;
                if (!currentSrc.includes('autoplay=0')) {
                  iframe.src = currentSrc.replace('autoplay=1', 'autoplay=0');
                }
              }
            }
          }
          
          function playIframe(iframe) {
            if (iframe && iframe.contentWindow) {
              try {
                iframe.contentWindow.postMessage('{"event":"command","func":"playVideo","args":""}', '*');
              } catch (e) {
                // Fallback: try to play by modifying src
                var currentSrc = iframe.src;
                if (!currentSrc.includes('autoplay=1')) {
                  iframe.src = currentSrc.replace('autoplay=0', 'autoplay=1');
                }
              }
            }
          }
          
          function toggleMute() {
            if (!mutedIframe || !unmutedIframe) {
              onIframeLoad();
            }
            
            if (isMuted) {
              // Switch to unmuted
              pauseIframe(mutedIframe);
              mutedIframe.style.display = 'none';
              unmutedIframe.style.display = 'block';
              playIframe(unmutedIframe);
              isMuted = false;
            } else {
              // Switch to muted
              pauseIframe(unmutedIframe);
              unmutedIframe.style.display = 'none';
              mutedIframe.style.display = 'block';
              playIframe(mutedIframe);
              isMuted = true;
            }
          }
          
          function setMute(muted) {
            if (muted !== isMuted) {
              toggleMute();
            }
          }
          
          // Initialize when page loads
          window.onload = function() {
            onIframeLoad();
          };
        </script>
      </head>
      <body>
        <div class="video-container">
          <iframe 
            id="iframe-muted"
            class="iframe-muted"
            src="https://www.youtube.com/embed/$videoId?autoplay=1&mute=1&controls=1&rel=0&showinfo=0&modestbranding=1&playsinline=1&enablejsapi=1"
            allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
            allowfullscreen
            onload="onIframeLoad()">
          </iframe>
          <iframe 
            id="iframe-unmuted"
            class="iframe-unmuted"
            src="https://www.youtube.com/embed/$videoId?autoplay=0&mute=0&controls=1&rel=0&showinfo=0&modestbranding=1&playsinline=1&enablejsapi=1"
            allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
            allowfullscreen
            onload="onIframeLoad()">
          </iframe>
        </div>
      </body>
      </html>
    ''';
  }

  void _initializeYouTubePlayer() {
    try {
      // Check preloading status
      if (VideoPreloader.instance.isPreloaded) {
        print('🎬 [SETUP VIDEO] Using preloaded video controller');
      } else if (VideoPreloader.instance.isPreloading) {
        print('⏳ [SETUP VIDEO] Video is still preloading, creating new controller');
      } else {
        print('⚠️ [SETUP VIDEO] No preloading detected, creating new controller');
      }
      
      // Try to get the preloaded controller first with error handling
      final preloadedController = VideoPreloader.instance.getPreloadedController();
      
      if (preloadedController != null) {
        _youtubeController = preloadedController;
        print('✅ [SETUP VIDEO] Using preloaded controller');
      } else {
        // Create new controller with safer flags for Android
        _youtubeController = YoutubePlayerController(
          initialVideoId: VideoPreloader.instance.videoId,
          flags: const YoutubePlayerFlags(
            autoPlay: true,
            mute: true, // Start muted to allow autoplay
            isLive: false,
            forceHD: false, // Disable forceHD to prevent Android crashes
            enableCaption: false, // Disable captions to prevent Android crashes
            showLiveFullscreenButton: false,
          ),
        );
        print('✅ [SETUP VIDEO] Created new controller');
      }
      
      // Simple fallback: try to play after a short delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _youtubeController != null) {
          try {
            _youtubeController!.play();
          } catch (e) {
            print('❌ [SETUP VIDEO] Error playing video: $e');
          }
        }
      });
      
    } catch (e) {
      print('❌ [SETUP VIDEO] Error creating controller: $e');
      setState(() {
        _hasError = true;
      });
    }
  }

  @override
  void dispose() {
    try {
      if (_youtubeController != null) {
        _youtubeController!.dispose();
      }
      // Clean up the video preloader since we're done with the video
      VideoPreloader.instance.dispose();
    } catch (e) {
      print('❌ [SETUP VIDEO] Error disposing controller: $e');
    }
    
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
    
    if (Platform.isAndroid) {
      return _buildAndroidVideoUI();
    } else {
      return _buildIOSVideoUI();
    }
  }

  Widget _buildAndroidVideoUI() {
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
              // Unmute the video on first tap (Android)
              try {
                if (_isMuted && _webViewController != null) {
                  // Use the new toggle function
                  _webViewController!.runJavaScript('setMute(false);');
                  setState(() {
                    _isMuted = false;
                  });
                  print('🔊 [SETUP VIDEO] Android video unmuted via tap');
                }
              } catch (e) {
                print('❌ [SETUP VIDEO] Error unmuting Android video: $e');
              }
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
          
          // Audio control button overlay (Android)
          if (_isWebViewReady)
            Positioned(
              top: MediaQuery.of(context).padding.top + 20,
              left: 20,
              child: GestureDetector(
                onTap: () {
                  try {
                    if (_isMuted) {
                      // Unmute using new function
                      _webViewController!.runJavaScript('setMute(false);');
                      setState(() {
                        _isMuted = false;
                      });
                      print('🔊 [SETUP VIDEO] Android video unmuted via button');
                    } else {
                      // Mute using new function
                      _webViewController!.runJavaScript('setMute(true);');
                      setState(() {
                        _isMuted = true;
                      });
                      print('🔇 [SETUP VIDEO] Android video muted via button');
                    }
                  } catch (e) {
                    print('❌ [SETUP VIDEO] Error toggling Android audio: $e');
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isMuted ? Icons.volume_off : Icons.volume_up,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isMuted ? 'Tap to unmute' : 'Tap to mute',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
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

  Widget _buildIOSVideoUI() {
    if (_youtubeController == null) {
      return _buildErrorUI();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Full screen video player with tap to unmute
          GestureDetector(
            onTap: () {
              // Unmute the video on first tap
              try {
                if (_isMuted && _youtubeController != null) {
                  _youtubeController!.unMute();
                  setState(() {
                    _isMuted = false;
                  });
                  print('🔊 [SETUP VIDEO] Video unmuted');
                }
              } catch (e) {
                print('❌ [SETUP VIDEO] Error unmuting video: $e');
              }
            },
            child: SizedBox.expand(
              child: YoutubePlayer(
                controller: _youtubeController!,
                showVideoProgressIndicator: true,
                progressIndicatorColor: Colors.red,
                progressColors: const ProgressBarColors(
                  playedColor: Colors.red,
                  handleColor: Colors.redAccent,
                ),
                onReady: () {
                  // Explicitly start playing when ready
                  try {
                    if (_youtubeController != null) {
                      _youtubeController!.play();
                    }
                  } catch (e) {
                    print('❌ [SETUP VIDEO] Error playing video on ready: $e');
                  }
                },
                onEnded: (YoutubeMetaData metaData) {
                  // Auto-advance to next screen when video ends
                  navigateToSetup4();
                },
              ),
            ),
          ),
          
          // Audio control button overlay
          Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            left: 20,
            child: GestureDetector(
              onTap: () {
                try {
                  if (_youtubeController != null) {
                    if (_isMuted) {
                      _youtubeController!.unMute();
                      setState(() {
                        _isMuted = false;
                      });
                      print('🔊 [SETUP VIDEO] Video unmuted via button');
                    } else {
                      _youtubeController!.mute();
                      setState(() {
                        _isMuted = true;
                      });
                      print('🔇 [SETUP VIDEO] Video muted via button');
                    }
                  }
                } catch (e) {
                  print('❌ [SETUP VIDEO] Error toggling mute: $e');
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isMuted ? Icons.volume_off : Icons.volume_up,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isMuted ? 'Tap to unmute' : 'Tap to mute',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
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
                  try {
                    if (_youtubeController != null) {
                      _youtubeController!.pause();
                    }
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
                onPressed: () {
                  try {
                    if (_youtubeController != null) {
                      _youtubeController!.pause();
                    }
                  } catch (e) {
                    print('❌ [SETUP VIDEO] Error pausing video: $e');
                  }
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
                if (Platform.isAndroid) {
                  _initializeWebView();
                } else {
                  _initializeYouTubePlayer();
                }
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