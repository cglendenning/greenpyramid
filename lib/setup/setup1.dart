import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:life_ops/setup/setup2.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:video_player/video_player.dart';

String setupVersion = 'v1';

// This is our "data store" that will be used to populate the db.
int currentCatId = 1;
int currentTaskId = 0;
List<SetupCat> cats = <SetupCat>[];
List<SetupTask> tasks = <SetupTask>[];

class Setup1 extends StatefulWidget {
  const Setup1();

  @override
  _Setup1State createState() => _Setup1State();
}

class _Setup1State extends State<Setup1> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();

    _controller = VideoPlayerController.asset('videos/bora.mov')
      ..setLooping(true)
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  _Setup1State();

  FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  @override
  Widget build(BuildContext context) {

    const String forward = 'images/svg/forward.svg';
    final Widget svgForward = SvgPicture.asset(forward,
        fit: BoxFit.scaleDown, semanticsLabel: 'forward');

    var bestLifeStyle = const TextStyle(
      fontSize: 20,
      color: Colors.black,
    );

    var quoteStyle = const TextStyle(
      fontFamily: 'Caveat',
      fontSize: 36,
      color: Colors.black,
    );


    return SafeArea(
        child: Scaffold(
            body: Stack(children: <Widget>[
      SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _controller.value.size.width,
            height: _controller.value.size.height,
            child: VideoPlayer(_controller),
          ),
        ),
      ),
      Center(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
            Container(
                padding: const EdgeInsets.all(10.0),
                child:
            Text(
                "\"Do today what others won't, so tomorrow you can do "
                "what others can't.\"",
                style: quoteStyle)),
                      Container(
                        margin: const EdgeInsets.all(16.0),
                        child:Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Image.asset('images/logo.png', scale: 6),
                            ]
                        ),
                      ),
            const SizedBox(height: 20),
                Container(
                    padding: const EdgeInsets.all(10.0),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.6),
                        border: Border.all(
                          color: Colors.transparent,
                        ),
                        borderRadius: const BorderRadius.all(Radius.circular(20))
                    ),
                    child: Text("Let\'s build your best life...",
                        style: bestLifeStyle)),
                const SizedBox(height: 10),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
              IconButton(
                icon: svgForward,
                onPressed: () {
                  setState(() {
                    navigateToSetup2();
                  });
                },
              ).animate(delay: 2000.ms).fadeIn(duration: 3000.ms),
            ]),
          ]))
    ])));
  }

  void navigateToSetup2() async {
    analytics.logEvent(name: '${setupVersion}_setup1');
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const Setup2()),
    );
  }
}


class SetupCat {
  int categoryid = 0;
  String cat = '';

  SetupCat({required this.categoryid, required this.cat});
}

class SetupTask {
  int id = 0;
  String category = '';
  String taskdescription = '';
  String sunday = '';
  String monday = '';
  String tuesday = '';
  String wednesday = '';
  String thursday = '';
  String friday = '';
  String saturday = '';
  String createDate = '';

  SetupTask(
      {required this.id,
        required this.category,
        required this.taskdescription,
        required this.sunday,
        required this.monday,
        required this.tuesday,
        required this.wednesday,
        required this.thursday,
        required this.friday,
        required this.saturday,
        required this.createDate});
}

