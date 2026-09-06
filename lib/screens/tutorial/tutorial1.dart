import 'package:flutter/material.dart';
import 'package:life_ops/screens/tutorial/tutorial2.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:life_ops/widgets/navbar.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class Tutorial1 extends StatefulWidget {
  const Tutorial1();

  @override
  _Tutorial1State createState() => _Tutorial1State();
}

class _Tutorial1State extends State<Tutorial1> {
  @override
  void initState() {
    super.initState();
  }

  _Tutorial1State();
  FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  @override
  Widget build(BuildContext context) {
    analytics.logEvent(name: 'tutorial_tutorial1');
    const String forward = 'images/svg/forward.svg';
    final Widget svgForward = SvgPicture.asset(forward,
        fit: BoxFit.scaleDown, semanticsLabel: 'forward');

    return SafeArea(
        child: Scaffold(
            appBar: const NavBar(),
            body: Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                  const Text('Tutorial (1 of 5)'),
                  const SizedBox(height: 10),
                  Container(
                      padding: const EdgeInsets.all(10.0),
                      child: const Text(
                          "Certain things we do every day matter more than "
                          "other things. The Green Pyramid helps you "
                          "visualize this...")),
                  const SizedBox(height: 30),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              IconButton(
                                icon: svgForward,
                                onPressed: () {
                                  setState(() {
                                    navigateToTutorial2();
                                  });
                                },
                              ),
                            ])
                      ]),
                  const SizedBox(height: 10),
                ]))));
  }

  void navigateToTutorial2() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const Tutorial2()),
    );
  }
}
