import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'dart:io' show Platform;

class VideoPreloader {
  static VideoPreloader? _instance;
  static VideoPreloader get instance => _instance ??= VideoPreloader._();
  
  VideoPreloader._();
  
  YoutubePlayerController? _preloadedController;
  bool _isPreloading = false;
  bool _isPreloaded = false;
  
  // Video ID from your redirect URL
  // Your redirect: http://www.stillwatersretreats.com/greenpyramid/setup-video
  // This will redirect to the original YouTube video
  static const String _videoId = '4H9qCQo_Y8s';
  
  /// Start preloading the video in the background
  Future<void> startPreloading() async {
    // Only preload on iOS since Android uses WebView
    if (Platform.isAndroid) {
      print('🌐 [VIDEO PRELOADER] Android detected - WebView will handle video loading');
      return;
    }
    
    if (_isPreloading || _isPreloaded) return;
    
    _isPreloading = true;
    print('🎬 [VIDEO PRELOADER] Starting background video buffering...');
    
    try {
      _preloadedController = YoutubePlayerController(
        initialVideoId: _videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: false, // Don't auto-play during preloading
          mute: true, // Mute during preloading to avoid audio issues
          isLive: false,
          forceHD: false, // Disable forceHD to prevent Android crashes
          enableCaption: false, // Disable captions to prevent Android crashes
          showLiveFullscreenButton: false,
        ),
      );
      
      // Wait for the controller to be ready
      await Future.delayed(const Duration(seconds: 2));
      
      _isPreloaded = true;
      _isPreloading = false;
      print('✅ [VIDEO PRELOADER] Video successfully preloaded and ready!');
      
    } catch (e) {
      _isPreloading = false;
      print('❌ [VIDEO PRELOADER] Failed to preload video: $e');
    }
  }
  
  /// Get the preloaded controller and reset for next use
  YoutubePlayerController? getPreloadedController() {
    // Return null on Android since we use WebView
    if (Platform.isAndroid) {
      print('🌐 [VIDEO PRELOADER] Android detected - using WebView instead of preloaded controller');
      return null;
    }
    
    if (!_isPreloaded || _preloadedController == null) {
      print('⚠️ [VIDEO PRELOADER] No preloaded controller available, creating new one');
      return null;
    }
    
    final controller = _preloadedController!;
    _preloadedController = null;
    _isPreloaded = false;
    
    print('🎬 [VIDEO PRELOADER] Returning preloaded controller for immediate playback');
    return controller;
  }
  
  /// Check if video is preloaded
  bool get isPreloaded => Platform.isAndroid ? false : _isPreloaded;
  
  /// Check if video is currently preloading
  bool get isPreloading => Platform.isAndroid ? false : _isPreloading;
  
  /// Get the video ID
  String get videoId => _videoId;
  
  /// Dispose of any preloaded controller
  void dispose() {
    try {
      _preloadedController?.dispose();
    } catch (e) {
      print('❌ [VIDEO PRELOADER] Error disposing preloaded controller: $e');
    }
    _preloadedController = null;
    _isPreloaded = false;
    _isPreloading = false;
  }
} 