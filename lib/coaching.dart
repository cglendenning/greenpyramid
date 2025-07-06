import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:life_ops/navbar.dart';
import 'package:life_ops/personal_coaching.dart';
import 'package:life_ops/paywall.dart';

class Coaching extends StatefulWidget {
  const Coaching({super.key});

  @override
  State<Coaching> createState() => _CoachingState();
}

class _CoachingState extends State<Coaching> {
  List<YouTubeVideo> videos = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchVideos();
  }

  Future<void> fetchVideos() async {
    try {
      // YouTube Data API v3 endpoint to get channel videos
      // Note: This requires an API key, but for now we'll use a different approach
      // We'll scrape the channel page or use RSS feed
      
      // Using RSS feed approach (no API key required)
      final response = await http.get(
        Uri.parse('https://www.youtube.com/feeds/videos.xml?channel_id=UCLLThMzPSIa7ckEISQfhycw'),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        },
      );

      if (response.statusCode == 200) {
        final xmlData = response.body;
        final videos = parseRSSFeed(xmlData);
        setState(() {
          this.videos = videos;
          isLoading = false;
        });
      } else {
        // Fallback: Create some sample videos for testing
        setState(() {
          videos = [
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
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load videos: $e';
        isLoading = false;
      });
    }
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
    } catch (e) {
      debugPrint('Error parsing RSS feed: $e');
    }
    
    return videos;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const NavBar(),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
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
                )
              : _buildMarketingLayout(),
    );
  }

  Widget _buildMarketingLayout() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Hero Section
        _buildHeroSection(),
        const SizedBox(height: 32),
        
        // First CTA - AI Coaching
        _buildAICoachingCTA(),
        const SizedBox(height: 32),
        
        // All Videos with interspersed CTAs
        ..._buildAllVideosWithCTAs(),
        
        // Final CTA
        _buildFinalCTA(),
      ],
    );
  }

  List<Widget> _buildAllVideosWithCTAs() {
    List<Widget> widgets = [];
    
    for (int i = 0; i < videos.length; i++) {
      // Add video
      widgets.add(_buildVideoCard(videos[i], i + 1));
      widgets.add(const SizedBox(height: 24));
      
      // Add CTA after every 2-3 videos
      if (i == 0) {
        // After first video - Personal Coaching CTA
        widgets.add(_buildPersonalCoachingCTA());
        widgets.add(const SizedBox(height: 32));
      } else if (i == 2) {
        // After third video - AI Coaching CTA
        widgets.add(_buildAICoachingCTA2());
        widgets.add(const SizedBox(height: 32));
      } else if (i == 4) {
        // After fifth video - Personal Coaching CTA again
        widgets.add(_buildPersonalCoachingCTA2());
        widgets.add(const SizedBox(height: 32));
      } else if (i == 6) {
        // After seventh video - AI Coaching CTA again
        widgets.add(_buildAICoachingCTA3());
        widgets.add(const SizedBox(height: 32));
      } else if (i == 8) {
        // After ninth video - Personal Coaching CTA again
        widgets.add(_buildPersonalCoachingCTA3());
        widgets.add(const SizedBox(height: 32));
      } else if (i % 3 == 0 && i > 8) {
        // Every 3 videos after the 9th - alternating CTAs
        if ((i / 3) % 2 == 0) {
          widgets.add(_buildAICoachingCTA4());
        } else {
          widgets.add(_buildPersonalCoachingCTA4());
        }
        widgets.add(const SizedBox(height: 32));
      }
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
                  if (video.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      video.description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xff666666),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
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
            'Coach with Craig',
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

  Widget _buildAICoachingCTA() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xffF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffE9ECEF)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.smart_toy,
            size: 40,
            color: Color(0xff1782FF),
          ),
          const SizedBox(height: 16),
          const Text(
            'Get AI-Powered Coaching',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xff1782FF),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Unlock unlimited AI coaching conversations to get personalized guidance anytime, anywhere.',
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
                backgroundColor: const Color(0xff1782FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Unlock AI Coaching',
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

  Widget _buildAICoachingCTA2() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xffE8F5E8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffC8E6C9)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.auto_awesome,
            size: 40,
            color: Color(0xff4CAF50),
          ),
          const SizedBox(height: 16),
          const Text(
            '24/7 AI Support',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xff4CAF50),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Never feel stuck again. Get instant coaching support whenever you need motivation, advice, or accountability.',
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
                backgroundColor: const Color(0xff4CAF50),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Get Unlimited Access',
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

  Widget _buildPersonalCoachingCTA3() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xffFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffFFECB3)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.star,
            size: 40,
            color: Color(0xffFFC107),
          ),
          const SizedBox(height: 16),
          const Text(
            'VIP Coaching Experience',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xffFFC107),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Join an exclusive group of high-achievers getting personalized coaching from Craig. Limited spots available.',
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
                backgroundColor: const Color(0xffFFC107),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Apply for VIP Coaching',
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
          const Text(
            'Choose your path: AI coaching for 24/7 support or personal coaching for accelerated results.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
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
        ],
      ),
    );
  }

  void _navigateToPaywall(BuildContext context) {
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

  @override
  void initState() {
    super.initState();
    // Register observer to monitor orientation changes
    WidgetsBinding.instance.addObserver(this);
    // Force landscape orientation immediately
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _initializeWebView();
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
    // Force landscape orientation and lock it
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

        return WillPopScope(
      onWillPop: () async {
        // Ensure orientation is restored when back button is pressed
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);
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
            // Back button overlay
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    // Restore portrait orientation
                    SystemChrome.setPreferredOrientations([
                      DeviceOrientation.portraitUp,
                    ]);
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

  @override
  void dispose() {
    // Remove observer and restore portrait orientation
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // Force landscape orientation whenever metrics change (including rotation)
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }
} 