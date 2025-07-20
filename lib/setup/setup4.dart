import 'package:flutter/material.dart';
import 'package:life_ops/pyramid.dart';
import 'package:life_ops/navbar.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:life_ops/setup/setup1.dart';
import 'package:life_ops/setup/setup5.dart';
import 'package:life_ops/progress_bar.dart';

class Setup4 extends StatefulWidget {
  final List<String> categories;

  const Setup4(this.categories);

  @override
  State<Setup4> createState() => _Setup4State(categories);
}

class _Setup4State extends State<Setup4> {
  List<String> categories;

  @override
  void initState() {
    super.initState();
  }

  _Setup4State(this.categories);
  FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  @override
  Widget build(BuildContext context) {
    analytics.logEvent(name: '${setupVersion}_setup4');
    Color green =
        Color(int.parse("#66CC5D".substring(1, 7), radix: 16) + 0xFF000000);

    final lg = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [green, green],
    );

    double pyramidWidth = MediaQuery.of(context).size.width * 0.87;
    double pyramidHeight = MediaQuery.of(context).size.width * 0.82;

    var mainTextStyle = const TextStyle(
        fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'SourceSans3');

    const String forward = 'images/svg/forward.svg';
    final Widget svgForward = SvgPicture.asset(forward,
        fit: BoxFit.scaleDown, semanticsLabel: 'forward');

    return Container(
        color: Colors.black,
        child: SafeArea(
            child: Scaffold(
          appBar: const NavBar(),
          body: Column(children: [
            Stack(
              children: [
                ProgressBar(currentStep: 3, totalSteps: 23),
                Positioned(
                  left: (MediaQuery.of(context).size.width - 24) * (3 / 23),
                  top: 0,
                  child: Container(
                    width: 12.0,
                    height: 6.0,
                    decoration: BoxDecoration(
                      color: Color(int.parse("#66CC5D".substring(1, 7), radix: 16) + 0xFF000000),
                      borderRadius: BorderRadius.circular(3.0),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Let\'s Go!',
              style: mainTextStyle,
            ),
            Container(
                padding: const EdgeInsets.all(10.0),
                child: const Text(
                    "Here is your Green Pyramid. The things that matter most "
                    "are on the bottom, holding up the rest of your life. "
                    "\n\nWe will now explain what the pyramid is all about "
                    "and the color coding. Let\'s continue...")),
            const SizedBox(height: 20),
            Stack(children: <Widget>[
              CustomPaint(
                  size: Size(pyramidWidth, pyramidHeight),
                  painter: DrawCat1(lg, categories[0], 0)),
              CustomPaint(
                  size: Size(pyramidWidth, pyramidHeight),
                  painter: DrawCat2(lg, categories[1], 0)),
              CustomPaint(
                  size: Size(pyramidWidth, pyramidHeight),
                  painter: DrawCat3(lg, categories[2], 0)),
              CustomPaint(
                  size: Size(pyramidWidth, pyramidHeight),
                  painter: DrawCat4(lg, categories[3], 0)),
              CustomPaint(
                  size: Size(pyramidWidth, pyramidHeight),
                  painter: DrawCat5(lg, categories[4], 0)),
              CustomPaint(
                  size: Size(pyramidWidth, pyramidHeight),
                  painter: DrawCat6(lg, categories[5], 0)),
            ]),
            const SizedBox(height: 40),
            IconButton(
              icon: svgForward,
              onPressed: () {
                setState(() {
                  navigateToSetup5();
                });
              },
            )
          ]),
        )));
  }

  void navigateToSetup5() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const Setup5()),
    );
  }
}
