import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:life_ops/navbar.dart';
import 'package:life_ops/personal_coaching.dart';
import 'package:life_ops/paywall.dart';
import 'package:life_ops/utils.dart' as utils;
import 'dart:io' show Platform;
import 'package:youtube_player_flutter/youtube_player_flutter.dart'
    as yt_flutter;
import 'package:flutter/widgets.dart';
import 'dart:developer';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'dart:convert' show jsonDecode;
import 'package:life_ops/secrets.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

void debugDumpState(String label, BuildContext? context,
    {dynamic controller, dynamic extra}) {
  final now = DateTime.now().toIso8601String();
  final ctxHash = context?.hashCode;
  final widgetTree = context != null ? context.widget.toStringShort() : 'null';
  final nav = context != null ? Navigator.canPop(context) : 'unknown';

  // Safely access MediaQuery to avoid crashes during initState
  String orientation = 'unknown';
  if (context != null) {
    try {
      orientation = MediaQuery.of(context).orientation.toString();
    } catch (e) {
      orientation = 'error: $e';
    }
  }

  log('[$now] $label | ctx: $ctxHash | widget: $widgetTree | canPop: $nav | orientation: $orientation | controller: $controller | extra: $extra');
}

// COACHING SCREEN
class Coaching extends StatefulWidget {
  const Coaching({super.key});

  @override
  State<Coaching> createState() => _CoachingState();
}

class _CoachingState extends State<Coaching>
    with RouteAware, WidgetsBindingObserver {
  List<YouTubeVideo> videos = [];
  bool isLoading = true;
  String? errorMessage;
  bool isSubscribed = false;
  // Memory management for large video lists
  static const int _maxVideosInMemory = 200; // Keep max 200 videos in memory
  static const int _cleanupThreshold = 150; // Start cleanup when we have 150+ videos
  
  // Cache for instant video loading
  List<YouTubeVideo> _instantCache = [];
  List<YouTubeVideo> _cachedVideos = [];
  DateTime? _lastCacheTime;

  // Lazy loading variables
  int _displayedVideoCount = 5; // Show 5 videos initially
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    debugDumpState('COACHING: initState', context);
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        debugDumpState('COACHING: subscribing to routeObserver', context);
        routeObserver.subscribe(this, ModalRoute.of(context)! as PageRoute);
      } catch (e, st) {
        log('COACHING: Error subscribing to routeObserver: $e\n$st');
      }
    });
    fetchVideos(); // Start loading videos immediately
    _checkSubscriptionStatus(); // Run subscription check in parallel
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    debugDumpState('COACHING: didChangeDependencies', context);
  }

  @override
  void dispose() {
    debugDumpState('COACHING: dispose called', context);
    try {
      WidgetsBinding.instance.removeObserver(this);
      _scrollController.removeListener(_onScroll);
      _scrollController.dispose();
      routeObserver.unsubscribe(this);
      debugDumpState('COACHING: dispose completed successfully', context);
    } catch (e, st) {
      log('COACHING: Error in dispose: $e\n$st');
    }
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreVideos();
    }
  }

  // Memory cleanup method to prevent memory leaks
  void _cleanupVideoMemory() {
    if (videos.length > _cleanupThreshold) {
      if (kDebugMode) {
        print('Memory cleanup: ${videos.length} videos, cleaning up...');
      }
      
      // Keep only the most recent videos and some older ones for variety
      final recentVideos = videos.take(100).toList(); // Keep first 100
      final olderVideos = videos.skip(100).take(50).toList(); // Keep 50 more for variety
      
      // Combine and shuffle for variety
      final cleanedVideos = [...recentVideos, ...olderVideos];
      cleanedVideos.shuffle();
      
      // Update the video list
      setState(() {
        this.videos = cleanedVideos;
        _displayedVideoCount = _displayedVideoCount.clamp(0, this.videos.length);
      });
      
      if (kDebugMode) {
        print('Memory cleanup complete: ${this.videos.length} videos kept');
      }
    }
  }

  // Update displayed video count with memory management
  void _loadMoreVideos() {
    if (_displayedVideoCount < videos.length) {
      if (kDebugMode) {
        print('_loadMoreVideos: Current _displayedVideoCount: $_displayedVideoCount');
        print('_loadMoreVideos: Total videos.length: ${videos.length}');
        print('_loadMoreVideos: _cachedVideos.length: ${_cachedVideos.length}');
      }
      
      // Check if we need memory cleanup
      if (videos.length > _cleanupThreshold) {
        _cleanupVideoMemory();
      }
      
      setState(() {
        _displayedVideoCount = (_displayedVideoCount + 10).clamp(0, videos.length);
        if (kDebugMode) {
          print('_loadMoreVideos: New _displayedVideoCount: $_displayedVideoCount');
        }
      });
    } else {
      if (kDebugMode) {
        print('_loadMoreVideos: No more videos to load');
        print('_loadMoreVideos: _displayedVideoCount: $_displayedVideoCount');
        print('_loadMoreVideos: videos.length: ${videos.length}');
      }
    }
  }

  @override
  void didPopNext() {
    // Use a post-frame callback to ensure context is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugDumpState('COACHING: didPopNext called', context);
      try {
        // Reset orientation to portrait when returning from video
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);

        // Refresh videos when returning to the screen to get latest from channel
        fetchVideos();

        debugDumpState('COACHING: didPopNext completed successfully', context);
      } catch (e, st) {
        log('COACHING: Error in didPopNext: $e\n$st');
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Refresh videos when app becomes active to get latest from channel
      fetchVideos();
    }
  }

  Future<void> _checkSubscriptionStatus() async {
    try {
      bool subscriptionStatus = await utils.Utils().isUserSubscribed();
      if (mounted) {
        setState(() {
          isSubscribed = subscriptionStatus;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error checking subscription status: $e');
      }
    }
  }

  Future<void> fetchVideos() async {
    try {
      // Check if we have cached videos that are still fresh (less than 1 hour old)
      final now = DateTime.now();
      if (_cachedVideos.isNotEmpty &&
          now.difference(_lastCacheTime!).inHours < 1) {
        setState(() {
          this.videos = List.from(_cachedVideos)..shuffle();
          _displayedVideoCount = 5; // Reset to show first 5 videos
          isLoading = false;
        });

        // Pre-load fresh data in background
        _preloadFreshVideos();
        return;
      }

      // Show instant cache immediately if available
      if (_instantCache.isNotEmpty) {
        setState(() {
          this.videos = List.from(_instantCache)..shuffle();
          _displayedVideoCount = 5; // Reset to show first 5 videos
          isLoading = false;
        });

        // Pre-load fresh data in background
        _preloadFreshVideos();
        return;
      }

      // Show cached videos immediately if available, even if expired
      if (_cachedVideos.isNotEmpty) {
        setState(() {
          this.videos = List.from(_cachedVideos)..shuffle();
          _displayedVideoCount = 5; // Reset to show first 5 videos
          isLoading = false;
        });

        // Pre-load fresh data in background
        _preloadFreshVideos();
        return;
      }

      // If no cache, show loading state and start fetching
      setState(() {
        isLoading = true; // Show loading spinner
        videos = []; // Clear any existing videos
      });

      // Start background fetch
      _preloadFreshVideos();
    } catch (e, st) {
      setState(() {
        errorMessage = 'Failed to load videos: $e';
        isLoading = false;
      });
      log('COACHING: Error fetching videos: $e\n$st');
    }
  }

  Future<void> _preloadFreshVideos() async {
    // ROBUST YOUTUBE API STRATEGY: Test API first, handle quotas, better fallbacks
    // This approach tests what actually works before proceeding
    
    try {
      List<YouTubeVideo> allVideos = [];
      Set<String> videoIds = {};
      bool instantCachePopulated = false;

      // Test the YouTube API first to see what we can actually get
      try {
        if (kDebugMode) {
          print('Testing YouTube Data API v3...');
        }
        
        const apiKey = Secrets.youtubeApiKey;
        
        // First, test if we can access the channel
        final channelResponse = await http.get(
          Uri.parse('https://www.googleapis.com/youtube/v3/channels?part=contentDetails&id=UCLLThMzPSIa7ckEISQfhycw&key=$apiKey'),
        ).timeout(const Duration(seconds: 20));
        
        if (channelResponse.statusCode == 200) {
          final channelData = jsonDecode(channelResponse.body);
          final uploadsPlaylistId = channelData['items']?[0]?['contentDetails']?['relatedPlaylists']?['uploads'];
          
          if (uploadsPlaylistId != null) {
            if (kDebugMode) {
              print('✅ YouTube API working! Found uploads playlist: $uploadsPlaylistId');
            }
            
            // Try to get videos from the playlist
            final playlistResponse = await http.get(
              Uri.parse('https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&playlistId=$uploadsPlaylistId&maxResults=50&key=$apiKey'),
            ).timeout(const Duration(seconds: 20));
            
            if (playlistResponse.statusCode == 200) {
              final playlistData = jsonDecode(playlistResponse.body);
              final items = playlistData['items'] as List?;
              final totalResults = playlistData['pageInfo']?['totalResults'];
              
              if (kDebugMode) {
                print('✅ Playlist API working! Total videos in channel: $totalResults');
                print('First page returned: ${items?.length ?? 0} videos');
              }
              
              if (items != null && items.isNotEmpty) {
                // Process first page of videos
                for (final item in items) {
                  final snippet = item['snippet'];
                  final videoId = snippet?['resourceId']?['videoId'];
                  final title = snippet?['title'];
                  
                  if (videoId != null && title != null && !videoIds.contains(videoId)) {
                    allVideos.add(YouTubeVideo(
                      id: videoId,
                      title: _cleanTitle(title),
                      thumbnail: 'https://img.youtube.com/vi/$videoId/mqdefault.jpg',
                      description: _cleanTitle(snippet?['description'] ?? ''),
                    ));
                    videoIds.add(videoId);
                    
                    // Populate _instantCache as soon as we have 5 videos
                    if (!instantCachePopulated && allVideos.length == 5) {
                      final List<YouTubeVideo> firstFive = List.from(allVideos);
                      firstFive.shuffle();
                      _instantCache = firstFive;
                      if (mounted) {
                        setState(() {
                          this.videos = List.from(_instantCache);
                          _displayedVideoCount = 5;
                          isLoading = false;
                        });
                      }
                      instantCachePopulated = true;
                    }
                  }
                }
                
                // If there are more videos, try to get them (but be careful with quotas)
                if (totalResults != null && totalResults > 50) {
                  if (kDebugMode) {
                    print('More videos available. Getting all videos...');
                  }
                  
                  // Get all remaining videos using pagination
                  String? nextPageToken = playlistData['nextPageToken'];
                  int totalVideos = items.length;
                  
                  while (nextPageToken != null) {
                    try {
                      final nextPageResponse = await http.get(
                        Uri.parse('https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&playlistId=$uploadsPlaylistId&maxResults=50&pageToken=$nextPageToken&key=$apiKey'),
                      ).timeout(const Duration(seconds: 20));
                      
                      if (nextPageResponse.statusCode == 200) {
                        final nextPageData = jsonDecode(nextPageResponse.body);
                        final nextItems = nextPageData['items'] as List?;
                        
                        if (nextItems != null && nextItems.isNotEmpty) {
                          if (kDebugMode) {
                            print('Fetched ${nextItems.length} more videos. Total so far: ${totalVideos + nextItems.length}');
                          }
                          
                          // Add videos from this page
                          for (final item in nextItems) {
                            final snippet = item['snippet'];
                            final videoId = snippet?['resourceId']?['videoId'];
                            final title = snippet?['title'];
                            
                            if (videoId != null && title != null && !videoIds.contains(videoId)) {
                              allVideos.add(YouTubeVideo(
                                id: videoId,
                                title: _cleanTitle(title),
                                thumbnail: 'https://img.youtube.com/vi/$videoId/mqdefault.jpg',
                                description: _cleanTitle(snippet?['description'] ?? ''),
                              ));
                              videoIds.add(videoId);
                              totalVideos++;
                            }
                          }
                          
                          // Get next page token for pagination
                          nextPageToken = nextPageData['nextPageToken'];
                          
                          if (nextPageToken != null) {
                            if (kDebugMode) {
                              print('More pages available, continuing...');
                            }
                            // Small delay between API calls to be respectful
                            await Future.delayed(const Duration(milliseconds: 200));
                          }
                        } else {
                          if (kDebugMode) {
                            print('No more items in this page');
                          }
                          break;
                        }
                      } else {
                        if (kDebugMode) {
                          print('Page request failed: ${nextPageResponse.statusCode}');
                        }
                        break;
                      }
                    } catch (e) {
                      if (kDebugMode) {
                        print('Error fetching page: $e');
                      }
                      break;
                    }
                  }
                  
                  if (kDebugMode) {
                    print('Pagination complete. Total videos fetched: $totalVideos');
                  }
                }
              }
            } else {
              if (kDebugMode) {
                print('❌ Playlist API failed: ${playlistResponse.statusCode}');
              }
            }
          } else {
            if (kDebugMode) {
              print('❌ Could not find uploads playlist ID');
            }
          }
        } else {
          if (kDebugMode) {
            print('❌ Channel API failed: ${channelResponse.statusCode}');
            print('Response: ${channelResponse.body}');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ YouTube API error: $e');
        }
      }

      if (kDebugMode) {
        print('YouTube API found ${allVideos.length} videos');
      }

      // If we didn't get enough videos from API, try alternative methods
      if (allVideos.length < 30) {
        if (kDebugMode) {
          print('API only gave ${allVideos.length} videos, trying alternative methods...');
        }
        
        // Try to get more videos using a different approach
        await _tryAlternativeVideoDiscovery(allVideos, videoIds);
      }

      if (kDebugMode) {
        print('Total unique videos found: ${allVideos.length}');
      }

      if (allVideos.isNotEmpty) {
        // Shuffle all videos to randomize the selection
        allVideos.shuffle();
        
        // Memory management: Limit the number of videos kept in memory
        if (allVideos.length > _maxVideosInMemory) {
          if (kDebugMode) {
            print('Memory limit reached: ${allVideos.length} videos, limiting to $_maxVideosInMemory');
          }
          
          // Keep a diverse selection of videos
          final recentVideos = allVideos.take(100).toList();
          final olderVideos = allVideos.skip(100).take(100).toList();
          
          // Combine and shuffle for variety
          allVideos = [...recentVideos, ...olderVideos];
          allVideos.shuffle();
          
          if (kDebugMode) {
            print('Memory management complete: ${allVideos.length} videos kept');
          }
        }
        
        // Update cache with shuffled videos
        _cachedVideos = List.from(allVideos);
        _lastCacheTime = DateTime.now();
        
        // DEBUG: Show all videos in _cachedVideos
        if (kDebugMode) {
          print('=== ALL VIDEOS IN _cachedVideos ===');
          for (int i = 0; i < _cachedVideos.length; i++) {
            final video = _cachedVideos[i];
            print('${i + 1}. ID: ${video.id}, Title: ${video.title}');
          }
          print('=== END VIDEOS LIST ===');
          print('Total videos in _cachedVideos: ${_cachedVideos.length}');
        }
        
        // Set instant cache to first 5 videos from shuffled list
        _instantCache = allVideos.take(5).toList();
        
        // Update UI with new videos
        if (mounted) {
          setState(() {
            this.videos = List.from(allVideos);
            _displayedVideoCount = 5;
            isLoading = false;
          });
        }
        
        if (kDebugMode) {
          print('Final video count: ${allVideos.length}');
          print('videos.length in setState: ${this.videos.length}');
          print('_displayedVideoCount set to: $_displayedVideoCount');
        }
      } else {
        // If all methods failed, show error
        if (mounted) {
          setState(() {
            errorMessage = 'Failed to load videos from all sources';
            isLoading = false;
          });
        }
        if (kDebugMode) {
          print('All video loading methods failed');
        }
      }
    } catch (e, st) {
      if (mounted) {
        setState(() {
          errorMessage = 'Failed to load videos: $e';
          isLoading = false;
        });
      }
      log('COACHING: Error fetching videos: $e\n$st');
    }
  }

  // Try alternative methods to discover more videos
  Future<void> _tryAlternativeVideoDiscovery(List<YouTubeVideo> allVideos, Set<String> videoIds) async {
    if (kDebugMode) {
      print('Trying alternative video discovery methods...');
    }
    
    // Method 1: Try RSS feed as backup
    try {
      final rssResponse = await http.get(
        Uri.parse('https://www.youtube.com/feeds/videos.xml?channel_id=UCLLThMzPSIa7ckEISQfhycw&max-results=100'),
      ).timeout(const Duration(seconds: 15));
      
      if (rssResponse.statusCode == 200) {
        final rssVideos = _parseRSSFeedSimple(rssResponse.body);
        if (kDebugMode) {
          print('RSS backup found ${rssVideos.length} videos');
        }
        
        for (final video in rssVideos) {
          if (!videoIds.contains(video.id)) {
            allVideos.add(video);
            videoIds.add(video.id);
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('RSS backup failed: $e');
      }
    }
    
    // Method 2: Try channel page parsing
    try {
      final channelResponse = await http.get(
        Uri.parse('https://www.youtube.com/channel/UCLLThMzPSIa7ckEISQfhycw/videos'),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        },
      ).timeout(const Duration(seconds: 15));
      
      if (channelResponse.statusCode == 200) {
        final additionalVideoIds = _extractVideoIdsFromChannelPage(channelResponse.body);
        if (kDebugMode) {
          print('Channel page parsing found ${additionalVideoIds.length} additional video IDs');
        }
        
        for (final videoId in additionalVideoIds) {
          if (!videoIds.contains(videoId)) {
            allVideos.add(YouTubeVideo(
              id: videoId,
              title: 'Video $videoId',
              thumbnail: 'https://img.youtube.com/vi/$videoId/mqdefault.jpg',
              description: '',
            ));
            videoIds.add(videoId);
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Channel page parsing failed: $e');
      }
    }
  }

  // Simple RSS parsing for backup method
  List<YouTubeVideo> _parseRSSFeedSimple(String xmlData) {
    List<YouTubeVideo> videos = [];
    
    try {
      final entries = RegExp(r'<entry>([\s\S]*?)</entry>').allMatches(xmlData);
      
      for (final entry in entries) {
        try {
          final entryContent = entry.group(1)!;
          final linkMatch = RegExp(r'<link[^>]*href="[^"]*watch\?v=([^"&]+)"').firstMatch(entryContent);
          
          if (linkMatch != null) {
            final videoId = linkMatch.group(1);
            if (videoId != null && videoId.length == 11) {
              final titleMatch = RegExp(r'<title>([^<]+)</title>').firstMatch(entryContent);
              final title = titleMatch?.group(1) ?? 'Video $videoId';
              
              videos.add(YouTubeVideo(
                id: videoId,
                title: _cleanTitle(title),
                thumbnail: 'https://img.youtube.com/vi/$videoId/mqdefault.jpg',
                description: '',
              ));
            }
          }
        } catch (e) {
          // Skip problematic entries
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error parsing RSS feed: $e');
      }
    }
    
    return videos;
  }

  // Fallback method if YouTube API is not configured

  // Clean up video titles from YouTube's data
  String _cleanTitle(String title) {
    return title
        .replaceAll('\\"', '"')
        .replaceAll('\\/', '/')
        .replaceAll('\\n', ' ')
        .replaceAll('\\t', ' ')
        .trim();
  }

  // Extract video IDs from a YouTube channel page HTML
  List<String> _extractVideoIdsFromChannelPage(String html) {
    List<String> videoIds = [];
    
    try {
      // Look for video IDs in the channel page HTML
      final videoIdPatterns = [
        RegExp(r'"videoId":"([^"]{11})"'),
        RegExp(r'data-video-id="([^"]{11})"'),
        RegExp(r'watch\?v=([^"&]{11})'),
        RegExp(r'/watch\?v=([^"&]{11})'),
      ];
      
      Set<String> foundIds = {};
      for (final pattern in videoIdPatterns) {
        final matches = pattern.allMatches(html);
        for (final match in matches) {
          final videoId = match.group(1);
          if (videoId != null && 
              videoId.length == 11 && 
              !foundIds.contains(videoId) &&
              videoId != 'UCLLThMzPSIa7ckEISQfhycw') { // Exclude channel ID
            foundIds.add(videoId);
            videoIds.add(videoId);
          }
        }
      }
      
      if (kDebugMode) {
        print('Channel page HTML parsing found ${videoIds.length} video IDs');
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('Error parsing channel page HTML: $e');
      }
    }
    
    return videoIds;
  }

  @override
  Widget build(BuildContext context) {
    debugDumpState('COACHING: build method called', context,
        extra: {'isLoading': isLoading, 'errorMessage': errorMessage});
    FirebaseAnalytics.instance.logEvent(name: 'coaching');
    return Scaffold(
      appBar: const NavBar(),
      body: _buildMarketingLayout(),
    );
  }

  Widget _buildMarketingLayout() {
    return RefreshIndicator(
      onRefresh: fetchVideos,
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          // Hero Section
          _buildHeroSection(),
          const SizedBox(height: 32),

          // All Videos with interspersed CTAs
          ..._buildAllVideosWithCTAs(),

          // Final CTA
          _buildFinalCTA(),
        ],
      ),
    );
  }

  List<Widget> _buildAllVideosWithCTAs() {
    List<Widget> widgets = [];

    // If videos are still loading and we don't have any yet, show loading state
    if (videos.isEmpty && isLoading) {
      widgets.add(
        Container(
          padding: const EdgeInsets.all(32.0),
          child: Center(
            child: Column(
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xff1782FF)),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Loading Coaching Videos',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff333333),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Fetching the latest videos from Craig\'s channel...',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xff666666),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'This will only take a moment',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xff999999),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return widgets;
    }

    // If there's an error, show error state
    if (errorMessage != null) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.all(32.0),
          child: Center(
            child: Column(
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading videos',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                Text(errorMessage!),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: fetchVideos,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
      return widgets;
    }

    // Only show the first _displayedVideoCount videos
    final videosToShow = videos.take(_displayedVideoCount).toList();

    for (int i = 0; i < videosToShow.length; i++) {
      // Add video
      widgets.add(_buildVideoCard(videosToShow[i], i + 1));
      widgets.add(const SizedBox(height: 24));

      // Add CTA after every 10 videos (reduced frequency)
      if (i == 9) {
        widgets.add(_buildPersonalCoachingCTA());
        widgets.add(const SizedBox(height: 32));
      } else if (i == 19) {
        widgets.add(_buildPersonalCoachingCTA2());
        widgets.add(const SizedBox(height: 32));
      } else if (i == 29 && !isSubscribed) {
        // Only show "Mindset Mastery" section if not subscribed
        widgets.add(_buildAICoachingCTA3());
        widgets.add(const SizedBox(height: 32));
      } else if (i % 10 == 9 && i > 29) {
        // Every 10 videos after the first 30 - alternating CTAs
        if ((i / 10) % 2 == 0 && !isSubscribed) {
          // Only show AI coaching CTAs if not subscribed
          widgets.add(_buildAICoachingCTA4());
        } else {
          widgets.add(_buildPersonalCoachingCTA4());
        }
        widgets.add(const SizedBox(height: 32));
      }
    }

    // Add loading indicator if there are more videos to load
    if (_displayedVideoCount < videos.length) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Column(
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xff1782FF)),
                ),
                const SizedBox(height: 8),
                Text(
                  'Loading more videos...',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Showing $_displayedVideoCount of ${videos.length} videos',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    // Show discovery status only when we're actively discovering videos
    // Hide it once all videos are loaded and displayed
    if (videos.length > 30 && _displayedVideoCount < videos.length) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.search,
                        size: 16,
                        color: Colors.blue[600],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Discovering videos...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Found ${videos.length} videos from your channel',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue[600],
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    // No message or spinner when all videos are loaded

    return widgets;
  }

  Widget _buildVideoCard(YouTubeVideo video, int videoNumber) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _playVideo(context, video),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: Stack(
                  children: [
                    Image.network(
                      video.thumbnail,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[300],
                          child: const Icon(
                            Icons.video_library,
                            size: 50,
                            color: Colors.grey,
                          ),
                        );
                      },
                    ),
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.play_circle_fill,
                            size: 60,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xff1782FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Video $videoNumber',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          video.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xff333333),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xff1782FF),
            Color(0xff000A61),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.psychology,
            size: 48,
            color: Colors.white,
          ),
          const SizedBox(height: 16),
          const Text(
            'Coaching by Craig',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Transform your life with proven strategies from someone who lost 120 pounds and built a successful business using the Green Pyramid method.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalCoachingCTA() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xffFFF3E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffFFE0B2)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.person,
            size: 40,
            color: Color(0xffFF9800),
          ),
          const SizedBox(height: 16),
          const Text(
            'Work 1-on-1 with Craig',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xffFF9800),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Ready for accelerated results? Get personalized coaching directly from Craig with weekly sessions and direct access.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xff666666),
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _navigateToPersonalCoaching(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xffFF9800),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Contact Craig',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalCoachingCTA2() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xffE3F2FD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffBBDEFB)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.rocket_launch,
            size: 40,
            color: Color(0xff2196F3),
          ),
          const SizedBox(height: 16),
          const Text(
            'Accelerate Your Results',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xff2196F3),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Ready to break through plateaus? Get personalized strategies and accountability from Craig himself.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xff666666),
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _navigateToPersonalCoaching(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff2196F3),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Work with Craig',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAICoachingCTA3() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xffF3E5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffE1BEE7)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.psychology,
            size: 40,
            color: Color(0xff9C27B0),
          ),
          const SizedBox(height: 16),
          const Text(
            'Mindset Mastery',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xff9C27B0),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Transform your thinking patterns with AI coaching that understands your unique challenges and goals.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xff666666),
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _navigateToPaywall(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff9C27B0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Master Your Mindset',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAICoachingCTA4() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xffE0F2F1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffB2DFDB)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.trending_up,
            size: 40,
            color: Color(0xff009688),
          ),
          const SizedBox(height: 16),
          const Text(
            'Continuous Growth',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xff009688),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Keep progressing with AI coaching that adapts to your growth and provides ongoing support.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xff666666),
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _navigateToPaywall(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff009688),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Keep Growing',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalCoachingCTA4() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xffFCE4EC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffF8BBD9)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.favorite,
            size: 40,
            color: Color(0xffE91E63),
          ),
          const SizedBox(height: 16),
          const Text(
            'Transform Your Life',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xffE91E63),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Ready for a complete transformation? Work directly with Craig to create lasting change in every area of your life.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xff666666),
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _navigateToPersonalCoaching(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xffE91E63),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Start Transformation',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinalCTA() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xffC35DCC),
            Color(0xff1782FF),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text(
            'Ready to Transform Your Life?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            isSubscribed
                ? 'Ready for the next level? Work directly with Craig for accelerated results and personalized guidance.'
                : 'Choose your path: AI coaching for 24/7 support or personal coaching for accelerated results.',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          if (!isSubscribed) ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _navigateToPaywall(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xff1782FF),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'AI Coaching',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _navigateToPersonalCoaching(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xffC35DCC),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Personal Coaching',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            // If subscribed, only show Personal Coaching button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _navigateToPersonalCoaching(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xffC35DCC),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Personal Coaching',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _navigateToPaywall(BuildContext context) async {
    // Check if user is already subscribed
    bool isSubscribed = await utils.Utils().isUserSubscribed();
    if (isSubscribed) {
      // Show a message that they're already subscribed
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You already have an active subscription!'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Navigate to paywall only if not subscribed
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => Paywall()),
    );
  }

  void _navigateToPersonalCoaching(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PersonalCoaching()),
    );
  }

  void _playVideo(BuildContext context, YouTubeVideo video) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(video: video),
      ),
    );
  }
}

class YouTubeVideo {
  final String id;
  final String title;
  final String thumbnail;
  final String description;

  YouTubeVideo({
    required this.id,
    required this.title,
    required this.thumbnail,
    required this.description,
  });
}

class VideoPlayerScreen extends StatefulWidget {
  final YouTubeVideo video;

  const VideoPlayerScreen({super.key, required this.video});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen>
    with WidgetsBindingObserver {
  late WebViewController _controller;
  bool isLoading = true;
  yt_flutter.YoutubePlayerController? _ytController;

  @override
  void initState() {
    super.initState();
    debugDumpState('VIDEO PLAYER: initState called', context,
        controller: _ytController);
    WidgetsBinding.instance.addObserver(this);

    // Delay orientation change to allow widget to fully initialize
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        debugDumpState(
            'VIDEO PLAYER: setPreferredOrientations to landscape', context);
      } catch (e, st) {
        log('VIDEO PLAYER: Error setting orientation in initState: $e\n$st');
      }
    });

    if (Platform.isIOS) {
      _ytController = yt_flutter.YoutubePlayerController(
        initialVideoId: widget.video.id,
        flags: const yt_flutter.YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          forceHD: false,
          enableCaption: false,
          controlsVisibleAtStart: true,
        ),
      );
      debugDumpState('VIDEO PLAYER: Created YoutubePlayerController', context,
          controller: _ytController);
    } else {
      _initializeWebView();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    debugDumpState('VIDEO PLAYER: didChangeDependencies', context,
        controller: _ytController);
  }

  void _initializeWebView() {
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

  String _getVideoEmbedHtml() {
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
            src="https://www.youtube.com/embed/${widget.video.id}?autoplay=1&mute=1&rel=0&showinfo=0"
            allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
            allowfullscreen>
        </iframe>
    </div>
</body>
</html>
    ''';
  }

  @override
  Widget build(BuildContext context) {
    debugDumpState('VIDEO PLAYER: build method called', context,
        controller: _ytController, extra: {'isLoading': isLoading});
    if (Platform.isIOS) {
      return WillPopScope(
        onWillPop: () async {
          log('VIDEO PLAYER: WillPopScope iOS called');

          // Pause YouTube controller before popping
          if (Platform.isIOS && _ytController != null) {
            try {
              _ytController!.pause();
              log('VIDEO PLAYER: WillPopScope iOS paused controller');
            } catch (e, st) {
              log('VIDEO PLAYER: Error pausing controller in WillPopScope iOS: $e\n$st');
            }
          }

          // Reset orientation to portrait
          try {
            SystemChrome.setPreferredOrientations([
              DeviceOrientation.portraitUp,
            ]);
            log('VIDEO PLAYER: WillPopScope iOS set portrait');
          } catch (e, st) {
            log('VIDEO PLAYER: Error in WillPopScope iOS: $e\n$st');
          }

          return true;
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              SizedBox.expand(
                child: yt_flutter.YoutubePlayer(
                  controller: _ytController!,
                  showVideoProgressIndicator: true,
                  onReady: () {
                    setState(() {});
                  },
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
                      log('VIDEO PLAYER: Back button pressed');

                      // Pause YouTube controller before navigating
                      if (Platform.isIOS && _ytController != null) {
                        try {
                          _ytController!.pause();
                          log('VIDEO PLAYER: Back button paused controller');
                        } catch (e, st) {
                          log('VIDEO PLAYER: Error pausing controller in back button: $e\n$st');
                        }
                      }

                      // Reset orientation to portrait
                      try {
                        SystemChrome.setPreferredOrientations([
                          DeviceOrientation.portraitUp,
                        ]);
                        log('VIDEO PLAYER: Back button set portrait');
                      } catch (e, st) {
                        log('VIDEO PLAYER: Error in Back button: $e\n$st');
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
      return WillPopScope(
        onWillPop: () async {
          log('VIDEO PLAYER: WillPopScope Android called');
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
                      log('VIDEO PLAYER: Back button pressed Android');
                      Navigator.pop(context);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    log('VIDEO PLAYER: dispose called');

    // Pause and dispose YouTube controller on iOS
    if (Platform.isIOS && _ytController != null) {
      try {
        _ytController!.pause();
        _ytController!.dispose();
        log('VIDEO PLAYER: YouTube controller disposed');
      } catch (e, st) {
        log('VIDEO PLAYER: Error disposing YouTube controller: $e\n$st');
      }
    }

    // Reset orientation to portrait
    try {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      log('VIDEO PLAYER: Orientation reset to portrait');
    } catch (e, st) {
      log('VIDEO PLAYER: Error resetting orientation: $e\n$st');
    }

    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
    log('VIDEO PLAYER: super.dispose() completed');
  }
}

