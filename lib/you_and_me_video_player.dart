import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:io' show Platform;
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class YouAndMeVideoPlayerScreen extends StatefulWidget {
  final String videoId;
  final bool forceLandscape;
  final bool showOverlays;
  const YouAndMeVideoPlayerScreen({Key? key, required this.videoId, this.forceLandscape = true, this.showOverlays = true}) : super(key: key);

  @override
  State<YouAndMeVideoPlayerScreen> createState() => _YouAndMeVideoPlayerScreenState();
}

class _YouAndMeVideoPlayerScreenState extends State<YouAndMeVideoPlayerScreen> with WidgetsBindingObserver {
  late WebViewController _controller;
  bool isLoading = true;
  bool showOverlays = false;
  YoutubePlayerController? _ytController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.forceLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    if (!widget.forceLandscape && Platform.isIOS) {
      _ytController = YoutubePlayerController(
        initialVideoId: widget.videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          forceHD: false,
          enableCaption: false,
          controlsVisibleAtStart: true,
        ),
      )..addListener(_ytListener);
      showOverlays = true; // Show overlays at start
    } else {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              setState(() {
                isLoading = true;
              });
            },
            onPageFinished: (String url) {
              setState(() {
                isLoading = false;
              });
            },
          ),
        )
        ..loadHtmlString(_getVideoEmbedHtml());
    }
  }

  void _ytListener() {
    if (_ytController == null) return;
    final playerState = _ytController!.value.playerState;
    final isPaused = playerState == PlayerState.paused;
    final isEnded = playerState == PlayerState.ended;
    final isPlaying = playerState == PlayerState.playing;
    if (isPaused || isEnded) {
      if (!showOverlays) setState(() { showOverlays = true; });
    } else if (isPlaying) {
      if (showOverlays) setState(() { showOverlays = false; });
    }
  }

  String _getVideoEmbedHtml() {
    if (!widget.forceLandscape) {
      // Portrait mode: overlays and JS channel for play/pause
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
        <iframe id="ytplayer" src="https://www.youtube.com/embed/${widget.videoId}?enablejsapi=1&autoplay=1&rel=0&showinfo=0" allow="autoplay; encrypted-media" allowfullscreen></iframe>
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
    } else {
      // Landscape mode: original HTML
      return '''
<!DOCTYPE html>
<html>
<head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body {
            margin: 0;
            padding: 0;
            background: #000;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
        }
        .video-container {
            width: 100%;
            height: 100vh;
            position: relative;
        }
        iframe {
            width: 100%;
            height: 100%;
            border: none;
        }
    </style>
</head>
<body>
    <div class="video-container">
        <iframe 
            src="https://www.youtube.com/embed/${widget.videoId}?autoplay=1&rel=0&showinfo=0"
            allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
            allowfullscreen>
        </iframe>
    </div>
</body>
</html>
      ''';
    }
  }


  @override
  Widget build(BuildContext context) {
    if (widget.forceLandscape || !Platform.isIOS) {
      // Android or landscape: original WebView logic
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      return WillPopScope(
        onWillPop: () async {
          if (widget.forceLandscape) {
            SystemChrome.setPreferredOrientations([
              DeviceOrientation.portraitUp,
            ]);
          }
          return true;
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              WebViewWidget(controller: _controller),
              if (isLoading)
                const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                  ),
                ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      if (widget.forceLandscape) {
                        SystemChrome.setPreferredOrientations([
                          DeviceOrientation.portraitUp,
                        ]);
                      }
                      Navigator.pop(context);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // iOS portrait: youtube_player_flutter with overlays
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      return WillPopScope(
        onWillPop: () async {
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
          ]);
          return true;
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              SizedBox.expand(
                child: YoutubePlayer(
                  controller: _ytController!,
                  showVideoProgressIndicator: true,
                  onReady: () {
                    setState(() { });
                  },
                ),
              ),
              if (widget.showOverlays && showOverlays) ...[
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
                        SystemChrome.setPreferredOrientations([
                          DeviceOrientation.portraitUp,
                        ]);
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
                        SystemChrome.setPreferredOrientations([
                          DeviceOrientation.portraitUp,
                        ]);
                        Navigator.pop(context);
                        // Add forward navigation logic here if needed
                      },
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.forceLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
    _ytController?.removeListener(_ytListener);
    _ytController?.dispose();
    super.dispose();
  }
} 