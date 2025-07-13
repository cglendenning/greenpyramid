import 'package:flutter/material.dart';
import 'package:life_ops/tutorial/tutorial4.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:life_ops/navbar.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class Tutorial3 extends StatefulWidget {
  const Tutorial3();

  @override
  _Tutorial3State createState() => _Tutorial3State();
}

class _Tutorial3State extends State<Tutorial3> {
  @override
  void initState() {
    super.initState();
  }

  _Tutorial3State();
  FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  @override
  Widget build(BuildContext context) {
    analytics.logEvent(name: 'tutorial_tutorial3');
    const String forward = 'images/svg/forward.svg';
    final Widget svgForward = SvgPicture.asset(forward,
        fit: BoxFit.scaleDown, semanticsLabel: 'forward');

    List<String> tasks = ["Exercise", "Hip Mobility", "Shoulder Mobility"];

    return SafeArea(
        child: Scaffold(
            appBar: const NavBar(),
            body: Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                  const Text('Tutorial (3 of 5)'),
                  const SizedBox(height: 10),
                  Container(
                      padding: const EdgeInsets.all(10.0),
                      child: const Text(
                          "Each category has daily tasks that you need to do "
                          "in order to keep your pyramid green.")),
                  const SizedBox(height: 100),
                  Container(
                      // constrain the scrollview to 1/3 of the height
                      // of the screen.
                      height: MediaQuery.of(context).size.height / 3,
                      child: Scrollbar(
                          child: ListView.builder(
                              itemCount: tasks.length,
                              itemBuilder: (BuildContext context, int index) {
                                return CheckboxListTile(
                                    title: Text(tasks[index]),
                                    subtitle: const Text('Health'),
                                    value: true,
                                    onChanged: (bool? value) {
                                      setState(() {});
                                    });
                              }))),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: <Widget>[
                              IconButton(
                                icon: svgForward,
                                onPressed: () {
                                  setState(() {
                                    navigateToTutorial4();
                                  });
                                },
                              ),
                            ])
                      ]),
                  const SizedBox(height: 10),
                ]))));
  }

  void navigateToTutorial4() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const Tutorial4()),
    );
  }
}
