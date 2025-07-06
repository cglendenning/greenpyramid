import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:life_ops/setup/setup4.dart';
import 'package:life_ops/setup/video_preloader.dart';
import 'package:life_ops/navbar.dart';
import 'package:life_ops/utils.dart' as utils;

class SetupVideo extends StatefulWidget {
  final List<String>? categories;
  
  const SetupVideo({super.key, this.categories});

  @override
  State<SetupVideo> createState() => _SetupVideoState();
}

class _SetupVideoState extends State<SetupVideo> {
  late YoutubePlayerController _controller;
  bool _isPlayerReady = false;
  bool _isMuted = true;

  @override
  void initState() {
    super.initState();
    
    // Force portrait orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    
    // Check preloading status
    if (VideoPreloader.instance.isPreloaded) {
      print('🎬 [SETUP VIDEO] Using preloaded video controller');
    } else if (VideoPreloader.instance.isPreloading) {
      print('⏳ [SETUP VIDEO] Video is still preloading, creating new controller');
    } else {
      print('⚠️ [SETUP VIDEO] No preloading detected, creating new controller');
    }
    
    // Try to get the preloaded controller first
    _controller = VideoPreloader.instance.getPreloadedController() ?? 
      YoutubePlayerController(
        initialVideoId: VideoPreloader.instance.videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: true, // Start muted to allow autoplay
          isLive: false,
          forceHD: true,
          enableCaption: true,
          showLiveFullscreenButton: false,
        ),
      );
    
    // Fallback: try to play after a short delay
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && !_controller.value.isPlaying) {
        _controller.play();
      }
    });
    
    // Disable controller listener - YouTube player controller state is unreliable
    // We'll manage mute state manually based on user actions only
    // _controller.addListener(() { ... });
  }

  @override
  void dispose() {
    _controller.dispose();
    // Clean up the video preloader since we're done with the video
    VideoPreloader.instance.dispose();
    
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Full screen video player with tap to unmute
          GestureDetector(
            onTap: () {
              // Unmute the video on first tap
              if (_isMuted) {
                // Use the YouTube player's built-in unmute method
                _controller.unMute();
                setState(() {
                  _isMuted = false;
                });
                print('🔊 [SETUP VIDEO] Video unmuted');
              }
            },
            child: SizedBox.expand(
              child: YoutubePlayer(
                controller: _controller,
                showVideoProgressIndicator: true,
                progressIndicatorColor: Colors.red,
                progressColors: const ProgressBarColors(
                  playedColor: Colors.red,
                  handleColor: Colors.redAccent,
                ),
                onReady: () {
                  setState(() {
                    _isPlayerReady = true;
                  });
                  // Explicitly start playing when ready
                  _controller.play();
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
                if (_isMuted) {
                  _controller.unMute();
                  setState(() {
                    _isMuted = false;
                  });
                  print('🔊 [SETUP VIDEO] Video unmuted via button');
                } else {
                  _controller.mute();
                  setState(() {
                    _isMuted = true;
                  });
                  print('🔇 [SETUP VIDEO] Video muted via button');
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
                  _controller.pause();
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
                  _controller.pause();
                  navigateToSetup4();
                },
              ),
            ),
          ),
        ],
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