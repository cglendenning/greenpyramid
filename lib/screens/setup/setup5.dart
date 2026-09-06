import 'package:flutter/material.dart';
import 'package:life_ops/widgets/pyramid.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:life_ops/screens/setup/setup6.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:life_ops/widgets/navbar.dart';
import 'package:life_ops/theme/app_colors.dart';
import 'package:life_ops/screens/setup/setup1.dart';
import 'package:life_ops/widgets/progress_bar.dart';

class Setup5 extends StatefulWidget {
  const Setup5();

  @override
  _Setup5State createState() => _Setup5State();
}

class _Setup5State extends State<Setup5> {
  @override
  void initState() {
    super.initState();
  }

  _Setup5State();
  FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  @override
  Widget build(BuildContext context) {
    analytics.logEvent(name: '${setupVersion}_setup5');
    Color green =
        Color(int.parse("#66CC5D".substring(1, 7), radix: 16) + 0xFF000000);

    final lg = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [green, green],
    );

    double pyramidWidth = MediaQuery.of(context).size.width * 0.87;
    double pyramidHeight = MediaQuery.of(context).size.width * 0.82;

    var foundationalStyle = const TextStyle(fontSize: 24);

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
              ProgressBar(currentStep: 4, totalSteps: 23),
              const SizedBox(height: 10),
              Text(
                'What Is Green Pyramid?',
                style: mainTextStyle,
              ),
              const SizedBox(height: 10),
              Container(
                  padding: const EdgeInsets.all(10.0),
                  child: Text(
                    "Green Pyramid is an AI-empowered system to make it "
                    "effortless to live your best possible life.\n\n"
                    "See the pyramid base below? If that foundation "
                    "is weak, the whole pyramid will crumble. This analogy "
                    "works for your life too...\n\n",
                    style: explainTextStyle,
                  )),

              // Entire Pyramid Stack
              Stack(children: <Widget>[
                // Foundational Stack (Pyramid + Text)
                Stack(children: <Widget>[
                  // Foundational Stack (Pyramid Only)
                  Stack(children: <Widget>[
                    CustomPaint(
                        size: Size(pyramidWidth, pyramidHeight),
                        painter: DrawCat1(lg, '', 0)),
                    CustomPaint(
                        size: Size(pyramidWidth, pyramidHeight),
                        painter: DrawCat2(lg, '', 0)),
                    CustomPaint(
                        size: Size(pyramidWidth, pyramidHeight),
                        painter: DrawCat3(lg, '', 0))
                  ]).animate().fadeIn(duration: 1000.ms),
                  Container(
                    height: pyramidHeight,
                    width: pyramidWidth,
                    child: Align(
                      // alignment: Alignment.bottomCenter,
                      alignment: const Alignment(0, 0.7),
                      child:
                          Text('Foundational Values', style: foundationalStyle),
                    ),
                  ).animate().fadeIn(delay: 1000.ms),
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
                          navigateToSetup6();
                        });
                      },
                    )
                  ]).animate().fadeIn(),
              const SizedBox(height: 10),
            ]))));
  }

  void navigateToSetup6() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const Setup6()),
    );
  }
}
