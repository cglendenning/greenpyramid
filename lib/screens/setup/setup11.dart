import 'package:flutter/material.dart';
import 'package:life_ops/widgets/pyramid.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:life_ops/screens/setup/setup1.dart';
import 'package:life_ops/screens/setup/setup12.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:life_ops/widgets/navbar.dart';
import 'package:life_ops/theme/app_colors.dart';
import 'package:life_ops/widgets/progress_bar.dart';

class Setup11 extends StatefulWidget {
  const Setup11();

  @override
  _Setup11State createState() => _Setup11State();
}

class _Setup11State extends State<Setup11> {
  @override
  void initState() {
    super.initState();
  }

  _Setup11State();

  FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  @override
  Widget build(BuildContext context) {
    analytics.logEvent(name: '${setupVersion}_setup11');
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
        fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Exo2');

    var explainTextStyle = const TextStyle(
        fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Exo2');

    return SafeArea(
        child: Scaffold(
            appBar: const NavBar(),
            backgroundColor: AppColors.background,
            body: Center(
                child: Column(children: [
              ProgressBar(currentStep: 10, totalSteps: 23),
              const SizedBox(height: 10),
              Text(
                'Green Pyramid Explained',
                style: mainTextStyle,
              ),
              const SizedBox(height: 10),
              Container(
                  padding: const EdgeInsets.all(10.0),
                  child: Text(
                      "Now that you have a grasp of the concepts, let's "
                      "flesh out your Green Pyramid! ",
                      style: explainTextStyle)),
              const SizedBox(height: 30),

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
                // Essential Stack (Pyramid + Text)
                Stack(children: <Widget>[
                  // Essential Stack (Pyramid Only)
                  Stack(children: <Widget>[
                    CustomPaint(
                        size: Size(pyramidWidth, pyramidHeight),
                        painter: DrawCat4(lg, cats[3].cat, 0)),
                    CustomPaint(
                        size: Size(pyramidWidth, pyramidHeight),
                        painter: DrawCat5(lg, cats[4].cat, 0))
                  ]).animate().slideY(
                      begin: -2,
                      delay: 1700.ms,
                      duration: 1000.ms,
                      curve: Curves.easeOut),
                ]),
                CustomPaint(
                        size: Size(pyramidWidth, pyramidHeight),
                        painter: DrawCat6(lg, cats[5].cat, 0))
                    .animate()
                    .slideY(
                        begin: -2,
                        delay: 3500.ms,
                        duration: 1000.ms,
                        curve: Curves.easeOut),
              ]).animate().shimmer(duration: 2000.ms, delay: 6000.ms),
              const SizedBox(height: 20),
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: <Widget>[
                    IconButton(
                      icon: svgForward,
                      onPressed: () {
                        setState(() {
                          navigateToSetup12();
                        });
                      },
                    )
                  ]).animate().fadeIn(),
              const SizedBox(height: 10),
            ]))));
  }

  void navigateToSetup12() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const Setup12()),
    );
  }
}
