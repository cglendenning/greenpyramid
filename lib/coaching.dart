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
import 'package:youtube_player_flutter/youtube_player_flutter.dart' as yt_flutter;
import 'package:flutter/widgets.dart';
import 'dart:developer';
import 'dart:convert';
import 'package:firebase_analytics/firebase_analytics.dart';
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

void debugDumpState(String label, BuildContext? context, {dynamic controller, dynamic extra}) {
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

class _CoachingState extends State<Coaching> with RouteAware, WidgetsBindingObserver {
  List<YouTubeVideo> videos = [];
  bool isLoading = true;
  String? errorMessage;
  bool isSubscribed = false;
  static List<YouTubeVideo> _cachedVideos = []; // Simple cache for videos
  static DateTime _lastCacheTime = DateTime.now().subtract(const Duration(hours: 1)); // Cache for 1 hour
  
  // Lazy loading variables
  int _displayedVideoCount = 5; // Show 5 videos initially
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();
  
  // Instant display cache - stores just first 5 videos for immediate display
  static List<YouTubeVideo> _instantCache = [];

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
    fetchVideos();
    _checkSubscriptionStatus();
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
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMoreVideos();
    }
  }

  void _loadMoreVideos() {
    if (!_isLoadingMore && _displayedVideoCount < videos.length) {
      setState(() {
        _isLoadingMore = true;
      });
      
      // Simulate loading delay for better UX
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _displayedVideoCount = (_displayedVideoCount + 5).clamp(0, videos.length);
            _isLoadingMore = false;
          });
        }
      });
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
      if (_cachedVideos.isNotEmpty && now.difference(_lastCacheTime).inHours < 1) {
        setState(() {
          this.videos = List.from(_cachedVideos)..shuffle();
          _displayedVideoCount = 5; // Reset to show first 5 videos
          isLoading = false;
        });
        
        // Pre-load remaining videos in background
        _preloadRemainingVideos();
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
    try {
      // Try multiple approaches to get all videos from the channel
      List<YouTubeVideo> allVideos = [];
      Set<String> videoIds = {};
      
      // Method 1: Try RSS feed with different parameters (this has proper metadata)
      try {
        final response = await http.get(
          Uri.parse('https://www.youtube.com/feeds/videos.xml?channel_id=UCLLThMzPSIa7ckEISQfhycw&max-results=50'),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
          },
        );

        if (response.statusCode == 200) {
          final videos = parseRSSFeed(response.body);
          allVideos.addAll(videos);
          videoIds.addAll(videos.map((v) => v.id));
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error with RSS feed method: $e');
        }
      }

      // Method 2: Try alternative RSS feed format
      try {
        final altResponse = await http.get(
          Uri.parse('https://www.youtube.com/feeds/videos.xml?channel_id=UCLLThMzPSIa7ckEISQfhycw&orderby=published&max-results=50'),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
          },
        );
        
        if (altResponse.statusCode == 200) {
          final altVideos = parseRSSFeed(altResponse.body);
          // Add videos that aren't already in the list
          for (final video in altVideos) {
            if (!videoIds.contains(video.id)) {
              allVideos.add(video);
              videoIds.add(video.id);
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error with alternative RSS feed method: $e');
        }
      }

      // Method 3: Fetch additional videos if we have less than 50
      if (allVideos.length < 50) {
        try {
          final channelResponse = await http.get(
            Uri.parse('https://www.youtube.com/channel/UCLLThMzPSIa7ckEISQfhycw/videos'),
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
            },
          );
          
          if (channelResponse.statusCode == 200) {
            final channelVideoIds = parseChannelPageForVideoIds(channelResponse.body);
            
            // Fetch metadata for more videos (increased limit)
            int fetchCount = 0;
            for (final videoId in channelVideoIds) {
              if (!videoIds.contains(videoId) && fetchCount < 25) { // Increased from 10 to 25
                try {
                  final videoMetadata = await fetchVideoMetadata(videoId);
                  if (videoMetadata != null) {
                    allVideos.add(videoMetadata);
                    videoIds.add(videoId);
                    fetchCount++;
                  }
                } catch (e) {
                  if (kDebugMode) {
                    print('Error fetching metadata for video $videoId: $e');
                  }
                }
              }
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error with channel page scraping method: $e');
          }
        }
      }

      if (allVideos.isNotEmpty) {
        // Update cache
        _cachedVideos = List.from(allVideos);
        _lastCacheTime = DateTime.now();
        
        // Update instant cache with first 5 videos
        _instantCache = allVideos.take(5).toList();
        
        // Update UI with new videos
        if (mounted) {
          setState(() {
            this.videos = List.from(allVideos)..shuffle();
            _displayedVideoCount = 5; // Reset to show first 5 videos
            isLoading = false;
          });
        }
      } else {
        // Fallback: Create some sample videos for testing
        final sampleVideos = [
          YouTubeVideo(
            id: 'sample1',
            title: 'Green Pyramid Coaching - Getting Started',
            thumbnail: 'https://img.youtube.com/vi/sample1/mqdefault.jpg',
            description: 'Learn the basics of the Green Pyramid method',
          ),
          YouTubeVideo(
            id: 'sample2', 
            title: 'Building Your Foundation',
            thumbnail: 'https://img.youtube.com/vi/sample2/mqdefault.jpg',
            description: 'How to build a strong foundation for success',
          ),
          YouTubeVideo(
            id: 'sample3',
            title: 'Advanced Pyramid Strategies',
            thumbnail: 'https://img.youtube.com/vi/sample3/mqdefault.jpg', 
            description: 'Take your pyramid to the next level',
          ),
        ];
        
        // Randomize sample videos too
        sampleVideos.shuffle();
        
        if (mounted) {
          setState(() {
            videos = sampleVideos;
            _displayedVideoCount = 5; // Reset to show first 5 videos
            isLoading = false;
          });
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

  void _preloadRemainingVideos() {
    // This method can be used to pre-load additional data if needed
    // For now, it's a placeholder for future optimizations
  }

  List<YouTubeVideo> parseRSSFeed(String xmlData) {
    List<YouTubeVideo> videos = [];
    
    try {
      // Simple XML parsing for RSS feed
      final entries = xmlData.split('<entry>');
      
      for (int i = 1; i < entries.length; i++) { // Skip first empty entry
        final entry = entries[i];
        
        // Extract video ID
        final videoIdMatch = RegExp(r'<yt:videoId>([^<]+)</yt:videoId>').firstMatch(entry);
        if (videoIdMatch == null) continue;
        final videoId = videoIdMatch.group(1);
        
        // Extract title
        final titleMatch = RegExp(r'<title>([^<]+)</title>').firstMatch(entry);
        if (titleMatch == null) continue;
        final title = titleMatch.group(1);
        
        // Extract description from media:group
        final mediaGroupMatch = RegExp(r'<media:group>([\\s\\S]*?)</media:group>').firstMatch(entry);
        String description = '';
        if (mediaGroupMatch != null) {
          final mediaGroup = mediaGroupMatch.group(1)!;
          final descMatch = RegExp(r'<media:description>([\\s\\S]*?)</media:description>').firstMatch(mediaGroup);
          description = descMatch?.group(1)?.replaceAll('&quot;', '"').replaceAll('&amp;', '&') ?? '';
        }
        
        // Create thumbnail URL using hqdefault for better quality
        final thumbnail = 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
        
        videos.add(YouTubeVideo(
          id: videoId!,
          title: title!,
          thumbnail: thumbnail,
          description: description,
        ));
      }
    } catch (e, st) {
      debugPrint('Error parsing RSS feed: $e\n$st');
    }
    
    return videos;
  }

  List<String> parseChannelPageForVideoIds(String htmlData) {
    List<String> videoIds = [];
    
    try {
      // Look for video IDs in the channel page HTML
      // YouTube stores video IDs in various data attributes
      final videoIdPatterns = [
        RegExp(r'"videoId":"([^"]+)"'),
        RegExp(r'data-video-id="([^"]+)"'),
        RegExp(r'watch\?v=([^"&]+)'),
        RegExp(r'/watch\?v=([^"&]+)'),
      ];
      
      for (final pattern in videoIdPatterns) {
        final matches = pattern.allMatches(htmlData);
        for (final match in matches) {
          final videoId = match.group(1);
          if (videoId != null && videoId.length == 11 && !videoIds.contains(videoId)) {
            videoIds.add(videoId);
          }
        }
      }
    } catch (e, st) {
      debugPrint('Error parsing channel page for video IDs: $e\n$st');
    }
    
    return videoIds;
  }

  Future<YouTubeVideo?> fetchVideoMetadata(String videoId) async {
    try {
      // Try to get metadata from the video page HTML with timeout
      final response = await http.get(
        Uri.parse('https://www.youtube.com/watch?v=$videoId'),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        },
      ).timeout(const Duration(seconds: 5)); // Add 5-second timeout

      if (response.statusCode == 200) {
        final htmlData = response.body;
        
        // Extract title from meta tags
        String? title;
        final titleMatch = RegExp(r'<meta property="og:title" content="([^"]+)"').firstMatch(htmlData);
        if (titleMatch != null) {
          title = titleMatch.group(1);
        } else {
          // Fallback: try to find title in other meta tags
          final titleMatch2 = RegExp(r'<title>([^<]+)</title>').firstMatch(htmlData);
          if (titleMatch2 != null) {
            title = titleMatch2.group(1);
            // Clean up the title (remove " - YouTube" suffix)
            if (title != null && title.contains(' - YouTube')) {
              title = title.replaceAll(' - YouTube', '');
            }
          }
        }
        
        // Only extract description if we need it (we're not showing it anymore)
        String description = ''; // Empty since we're not displaying descriptions
        
        return YouTubeVideo(
          id: videoId,
          title: title ?? 'Video $videoId',
          thumbnail: 'https://img.youtube.com/vi/$videoId/mqdefault.jpg',
          description: description,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching video metadata for $videoId: $e');
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    debugDumpState('COACHING: build method called', context, extra: {'isLoading': isLoading, 'errorMessage': errorMessage});
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
      
      // Add CTA after every 2-3 videos
      if (i == 4) {
        widgets.add(_buildPersonalCoachingCTA());
        widgets.add(const SizedBox(height: 32));
      } else if (i == 8) {
        widgets.add(_buildPersonalCoachingCTA2());
        widgets.add(const SizedBox(height: 32));
      } else if (i == 12 && !isSubscribed) {
        // Only show "Mindset Mastery" section if not subscribed
        widgets.add(_buildAICoachingCTA3());
        widgets.add(const SizedBox(height: 32));
      } else if (i % 5 == 0 && i > 8) {
        // Every 5 videos - alternating CTAs
        if ((i / 3) % 2 == 0 && !isSubscribed) {
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
                if (_isLoadingMore)
                  const CircularProgressIndicator()
                else
                  const SizedBox(height: 20),
                const SizedBox(height: 8),
                Text(
                  '${_displayedVideoCount} of ${videos.length} videos loaded',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

class _VideoPlayerScreenState extends State<VideoPlayerScreen> with WidgetsBindingObserver {
  late WebViewController _controller;
  bool isLoading = true;
  yt_flutter.YoutubePlayerController? _ytController;

  @override
  void initState() {
    super.initState();
    debugDumpState('VIDEO PLAYER: initState called', context, controller: _ytController);
    WidgetsBinding.instance.addObserver(this);
    
    // Delay orientation change to allow widget to fully initialize
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        debugDumpState('VIDEO PLAYER: setPreferredOrientations to landscape', context);
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
      debugDumpState('VIDEO PLAYER: Created YoutubePlayerController', context, controller: _ytController);
    } else {
      _initializeWebView();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    debugDumpState('VIDEO PLAYER: didChangeDependencies', context, controller: _ytController);
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
    debugDumpState('VIDEO PLAYER: build method called', context, controller: _ytController, extra: {'isLoading': isLoading});
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
                    setState(() { });
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
