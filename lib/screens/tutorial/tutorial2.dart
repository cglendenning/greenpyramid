import 'package:flutter/material.dart';
import 'package:life_ops/screens/tutorial/tutorial3.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:life_ops/widgets/navbar.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:life_ops/widgets/pyramid.dart';

class Tutorial2 extends StatefulWidget {
  const Tutorial2({Key? key}) : super(key: key);

  @override
  State<Tutorial2> createState() => _Tutorial2();
}

class _Tutorial2 extends State<Tutorial2> {
  var _static1LGColor;
  var _static2LGColor;
  var _static3LGColor;
  var _static4LGColor;
  var _static5LGColor;
  var _static6LGColor;

  @override
  void initState() {
    _static1LGColor =
        Color(int.parse("#FFE177".substring(1, 7), radix: 16) + 0xFF000000);
    _static2LGColor =
        Color(int.parse("#F96E6E".substring(1, 7), radix: 16) + 0xFF000000);
    _static3LGColor =
        Color(int.parse("#FFE177".substring(1, 7), radix: 16) + 0xFF000000);
    _static4LGColor =
        Color(int.parse("#F96E6E".substring(1, 7), radix: 16) + 0xFF000000);
    _static5LGColor =
        Color(int.parse("#66CC5D".substring(1, 7), radix: 16) + 0xFF000000);
    _static6LGColor =
        Color(int.parse("#66CC5D".substring(1, 7), radix: 16) + 0xFF000000);

    super.initState();
  }

  FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  @override
  Widget build(BuildContext context) {
    analytics.logEvent(name: 'tutorial_tutorial2');
    const String forward = 'images/svg/forward.svg';
    final Widget svgForward = SvgPicture.asset(forward,
        fit: BoxFit.scaleDown, semanticsLabel: 'forward');

    final static1LG = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        _static1LGColor,
        _static1LGColor,
      ],
    );

    final static2LG = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        _static2LGColor,
        _static2LGColor,
      ],
    );

    final static3LG = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        _static3LGColor,
        _static3LGColor,
      ],
    );

    final static4LG = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        _static4LGColor,
        _static4LGColor,
      ],
    );

    final static5LG = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        _static5LGColor,
        _static5LGColor,
      ],
    );

    final static6LG = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        _static6LGColor,
        _static6LGColor,
      ],
    );

    double pyramidWidth = MediaQuery.of(context).size.width - 20;
    double pyramidHeight = MediaQuery.of(context).size.width - 20;

    return Container(
        color: Colors.black,
        child: SafeArea(
            child: Scaffold(
                appBar: const NavBar(),
                body: Center(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                      const Text('Tutorial (2 of 5)'),
                      const SizedBox(height: 10),
                      Container(
                          padding: const EdgeInsets.all(10.0),
                          child: const Text(
                              "Each block is a category of your life that matters "
                              "to you... ")),
                      Stack(children: <Widget>[
                        CustomPaint(
                            size: Size(pyramidWidth, pyramidHeight),
                            painter: DrawCat1(static1LG, 'Physical Health', 0)),
                        CustomPaint(
                            size: Size(pyramidWidth, pyramidHeight),
                            painter: DrawCat2(static2LG, 'Mindset', 0)),
                        CustomPaint(
                            size: Size(pyramidWidth, pyramidHeight),
                            painter: DrawCat3(static3LG, 'Finances', 0)),
                        CustomPaint(
                            size: Size(pyramidWidth, pyramidHeight),
                            painter: DrawCat4(static4LG, 'Spouse', 0)),
                        CustomPaint(
                            size: Size(pyramidWidth, pyramidHeight),
                            painter: DrawCat5(static5LG, 'Parent', 0)),
                        CustomPaint(
                            size: Size(pyramidWidth, pyramidHeight),
                            painter: DrawCat6(static6LG, 'Self-Care', 0)),
                      ]).animate().shimmer(duration: 1000.ms),
                      const SizedBox(height: 30),
                      Container(
                          padding: const EdgeInsets.all(10.0),
                          child: const Text(
                              "...You can put the most important categories of your "
                              "life on the bottom, because they hold up the rest of "
                              "your life.")),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: <Widget>[
                                  IconButton(
                                    icon: svgForward,
                                    onPressed: () {
                                      setState(() {
                                        navigateToTutorial3();
                                      });
                                    },
                                  ),
                                ])
                          ]),
                    ])))));
  }

  void navigateToTutorial3() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const Tutorial3()),
    );
  }
}
