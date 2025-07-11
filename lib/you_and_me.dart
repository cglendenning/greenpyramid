import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:life_ops/personal_coaching.dart';
import 'dart:io';
import 'package:life_ops/you_and_me_video_player.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

class YouAndMeScreen extends StatefulWidget {
  const YouAndMeScreen({Key? key}) : super(key: key);

  @override
  State<YouAndMeScreen> createState() => _YouAndMeScreenState();
}

class _YouAndMeScreenState extends State<YouAndMeScreen> with RouteAware {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      routeObserver.subscribe(this, ModalRoute.of(context)! as PageRoute);
    });
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // Called when coming back to this screen
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }

  static const String youAndMeCopy = '''

You may be a builder, maker, solopreneur, entrepreneur or creator who gets frustrated and angry at non-creative people and processes that get in the way of you producing your best work. You probably never express this, because you are nice. Setting boundaries is not your love language because you are petrified of being perceived as a jerk. You fear having to defend your boundaries so much that you never set them. You resonate with the idea of a life where you can bask in the tranquility of craftsmanship where you construct high quality things for others that they find incredibly valuable.

If you said AMEN to that, we might be a fit. My name is Craig and for 25 years I have been a tech builder, teacher, consultant and manager and I have seen what makes insanely talented, brilliant and creative people tick. I have seen talented managers create environments where makers thrive as well as aggressive drivers and talented a**holes destroy morale. I have been a director in a fast growing startup and have learned the importance of creating the right social climate for makers.

Some of my fondest memories over my career include 1-on-1 coaching and being a traveling trainer of certification courses. I love coaching, mentoring, teaching and training. If you think we might be a coaching fit, here is a video on what it might be like to be coached by me.

[video link here]

You can also reach out for a free 15 minute chat with me below.

[coaching form here]
''';

  List<String> _bubbleBlocks() {
    // Split into 2-3 sentence blocks for bubbles
    final text = youAndMeCopy.replaceAll('\n', ' ').replaceAll('  ', ' ');
    final regex = RegExp(r'([^.!?]*[.!?])');
    final sentences = regex.allMatches(text).map((m) => m.group(0)!.trim()).toList();
    List<String> blocks = [];
    String current = '';
    int count = 0;
    for (final sentence in sentences) {
      if (sentence.contains('[video link here]') || sentence.contains('[coaching form here]')) {
        if (current.isNotEmpty) blocks.add(current.trim());
        blocks.add(sentence);
        current = '';
        count = 0;
        continue;
      }
      current += (current.isEmpty ? '' : ' ') + sentence;
      count++;
      if (count == 2 || sentence.endsWith('?')) {
        blocks.add(current.trim());
        current = '';
        count = 0;
      }
    }
    if (current.isNotEmpty) blocks.add(current.trim());
    return blocks;
  }

  @override
  Widget build(BuildContext context) {
    final blocks = _bubbleBlocks();
    final List<Widget> content = [];
    // Add styled headline at the top
    content.add(
      Padding(
        padding: const EdgeInsets.only(bottom: 24.0, top: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0xff66cc5d).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.spa, color: Color(0xff1782FF), size: 32),
                  const SizedBox(width: 10),
                  Text(
                    'You & Me',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff1782FF),
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    for (final block in blocks) {
      if (block.contains('[video link here]')) {
        content.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const YouAndMeVideoPlayerScreen(videoId: 'SeKP2Qgdk9o'),
                    ),
                  );
                },
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: Stack(
                      children: [
                        Image.network(
                          'https://img.youtube.com/vi/SeKP2Qgdk9o/hqdefault.jpg',
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
                              color: Colors.black.withOpacity(0.3),
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
              ),
            ),
          ),
        );
        // Add CTA button directly below the video
        content.add(
          Padding(
            padding: const EdgeInsets.only(top: 12.0, bottom: 24.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.psychology, color: Colors.white),
                label: const Text(
                  'Get Coached by Craig',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xff1782FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 4,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PersonalCoaching()),
                  );
                },
              ),
            ),
          ),
        );
      } else if (block.contains('[coaching form here]')) {
        // Skip the old coaching form placeholder
        continue;
      } else {
        content.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 4.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.07),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
              child: Text(
                block,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.black87, height: 1.4),
                textAlign: TextAlign.left,
              ),
            ),
          ),
        );
      }
    }
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('You & Me'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('images/morning_1.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: content,
            ),
          ),
        ),
      ),
    );
  }
} 
