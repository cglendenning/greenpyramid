import 'package:flutter/material.dart';
import 'package:life_ops/pyramid.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:life_ops/setup/setup1.dart';
import 'package:life_ops/setup/setup11.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:life_ops/navbar.dart';
import 'package:life_ops/progress_bar.dart';

class Setup10 extends StatefulWidget {
  const Setup10();

  @override
  _Setup10State createState() => _Setup10State();
}

class _Setup10State extends State<Setup10> {
  @override
  void initState() {
    super.initState();
  }

  _Setup10State();

  FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  @override
  Widget build(BuildContext context) {
    analytics.logEvent(name: '${setupVersion}_setup10');
    Color green =
        Color(int.parse("#66CC5D".substring(1, 7), radix: 16) + 0xFF000000);

    final lg = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [green, green],
    );

    double pyramidWidth = MediaQuery.of(context).size.width * 0.87;
    double pyramidHeight = MediaQuery.of(context).size.width * 0.82;

    const String forward = 'images/svg/forward.svg';
    final Widget svgForward = SvgPicture.asset(forward,
        fit: BoxFit.scaleDown, semanticsLabel: 'forward');

    var mainTextStyle = const TextStyle(
        fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'SourceSans3');

    var explainTextStyle = const TextStyle(
        fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'SourceSans3');

    return SafeArea(
        child: Scaffold(
            appBar: const NavBar(),
            backgroundColor: Colors.white,
            body: Center(
                child: Column(children: [
              ProgressBar(currentStep: 9, totalSteps: 23),
              const SizedBox(height: 10),
              Text(
                'Daily Actions',
                style: mainTextStyle,
              ),
              const SizedBox(height: 10),
              Container(
                  padding: const EdgeInsets.all(10.0),
                  alignment: Alignment.topLeft,
                  child: Text(
                    "Each of your values require daily action if you truly "
                    "are committed to that value.\n\nLet\'s recap your "
                    "Green Pyramid so you can see how it all fits together...",
                    style: explainTextStyle,
                    textAlign: TextAlign.left,
                  )),
              // Entire Pyramid Stack
              Stack(children: <Widget>[
                // Foundational Stack (Pyramid + Text)
                Stack(children: <Widget>[
                  // Foundational Stack (Pyramid Only)
                  Stack(children: <Widget>[
                    CustomPaint(
                        size: Size(pyramidWidth, pyramidHeight),
                        painter: DrawCat1(lg, cats[0].cat, 0)),
                    CustomPaint(
                        size: Size(pyramidWidth, pyramidHeight),
                        painter: DrawCat2(lg, cats[1].cat, 0)),
                    CustomPaint(
                        size: Size(pyramidWidth, pyramidHeight),
                        painter: DrawCat3(lg, cats[2].cat, 0))
                  ]).animate().fadeIn(duration: 1000.ms),
                ]),
                // Essential Stack (Pyramid + Text)
              ]),
              const SizedBox(height: 10),
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: <Widget>[
                    IconButton(
                      icon: svgForward,
                      onPressed: () {
                        setState(() {
                          navigateToSetup11();
                        });
                      },
                    )
                  ]).animate().fadeIn(),
            ]))));
  }

  void navigateToSetup11() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const Setup11()),
    );
  }
}
