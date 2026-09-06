import 'package:flutter/material.dart';
import 'package:life_ops/widgets/pyramid.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:life_ops/screens/setup/setup8.dart';
import 'package:life_ops/screens/setup/setup1.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:life_ops/widgets/navbar.dart';
import 'package:life_ops/theme/app_colors.dart';
import 'package:life_ops/widgets/progress_bar.dart';

class Setup7 extends StatefulWidget {
  const Setup7();

  @override
  _Setup7State createState() => _Setup7State();
}

class _Setup7State extends State<Setup7> {
  @override
  void initState() {
    super.initState();
  }

  _Setup7State();
  FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  @override
  Widget build(BuildContext context) {
    analytics.logEvent(name: '${setupVersion}_setup7');
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
              ProgressBar(currentStep: 6, totalSteps: 23),
              const SizedBox(height: 10),
              Text(
                'Green is good.',
                style: mainTextStyle,
              ),
              Container(
                  padding: const EdgeInsets.all(10.0),
                  child: Text(
                      "It means you are crushing most or "
                      "all of your habits toward your best life...\n\n",
                      style: explainTextStyle)),
              const SizedBox(height: 30),
              Container(
                color: Colors.white,
                alignment: Alignment.center,
                child: Image.asset('images/thumbs_up.jpg',
                    height: 100, width: 100),
              ),
              // Entire Pyramid Stack
              Stack(children: <Widget>[
                // Foundational Stack (Pyramid + Text)
                Stack(children: <Widget>[
                  // Foundational Stack (Pyramid Only)
                  Stack(children: <Widget>[
                    CustomPaint(
                        size: Size(pyramidWidth, pyramidHeight),
                        painter: DrawCat1(lg, cats[0].cat, 0)),
                  ]).animate().fadeIn(duration: 1000.ms),
                ]),
                // Essential Stack (Pyramid + Text)
              ]),
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: <Widget>[
                    IconButton(
                      icon: svgForward,
                      onPressed: () {
                        setState(() {
                          navigateToSetup8();
                        });
                      },
                    )
                  ]).animate().fadeIn(),
            ]))));
  }

  void navigateToSetup8() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const Setup8()),
    );
  }
}
