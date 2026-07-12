import 'package:flutter/material.dart';
import 'package:life_ops/pyramid.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:life_ops/setup/setup7.dart';
import 'package:life_ops/setup/setup1.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:life_ops/navbar.dart';
import 'package:life_ops/theme/app_colors.dart';
import 'package:life_ops/progress_bar.dart';

class Setup6 extends StatefulWidget {
  const Setup6();

  @override
  _Setup6State createState() => _Setup6State();
}

class _Setup6State extends State<Setup6> {
  @override
  void initState() {
    super.initState();
  }

  _Setup6State();

  FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  @override
  Widget build(BuildContext context) {
    analytics.logEvent(name: '${setupVersion}_setup6');
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
              ProgressBar(currentStep: 5, totalSteps: 23),
              const SizedBox(height: 10),
              Text(
                'What Matters Most',
                style: mainTextStyle,
              ),
              const SizedBox(height: 10),
              Container(
                  padding: const EdgeInsets.all(10.0),
                  child: Text(
                      "Your three foundational values are at the base "
                      "of the pyramid. Each block is a value that holds "
                      "the daily actions you will take to live your best "
                      "life.\n\nLet's look at what the \"Green\" in Green "
                      "Pyramid really means...",
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
              ]),
              const SizedBox(height: 20),
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: <Widget>[
                    IconButton(
                      icon: svgForward,
                      onPressed: () {
                        setState(() {
                          navigateToSetup7();
                        });
                      },
                    )
                  ]).animate().fadeIn(),
              const SizedBox(height: 10),
            ]))));
  }

  void navigateToSetup7() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const Setup7()),
    );
  }
}
