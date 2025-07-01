import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:life_ops/navbar.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class Tutorial5 extends StatefulWidget {
  const Tutorial5();

  @override
  _Tutorial5State createState() => _Tutorial5State();
}

class _Tutorial5State extends State<Tutorial5> {
  @override
  void initState() {
    super.initState();
  }

  _Tutorial5State();
  FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  @override
  Widget build(BuildContext context) {
    analytics.logEvent(name: 'tutorial_tutorial5');
    const String forward = 'images/svg/forward.svg';
    final Widget svgForward = SvgPicture.asset(forward,
        fit: BoxFit.scaleDown, semanticsLabel: 'forward');


    List<String> tasks = [
      "Exercise",
      "Hip Mobility",
      "Shoulder Mobility"
    ];

    return SafeArea(
        child: Scaffold(
            appBar: const NavBar(),
            body: Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text('Tutorial (5 of 5)'),
                      const SizedBox(height: 10),
                      Container(
                          padding: const EdgeInsets.all(10.0),
                          child: const Text("Every day you will receive notifications "
                              "to check the tasks that you did yesterday. "
                              "Please be sure to turn on notifications in "
                              "settings for Green Pyramid if you have not already.")),
                      const SizedBox(height: 10),
                Container(
                // constrain the scrollview to 1/3 of the height
                // of the screen.
                height: MediaQuery.of(context).size.height / 3,
            child: Scrollbar(
                child: ListView.builder(
                    itemCount: tasks.length,
                    itemBuilder:
                        (BuildContext context, int index) {
                      return CheckboxListTile(
                          title: Text(tasks[index]),
                          subtitle: const Text('Health'),
                          value: false,
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
                                        Navigator.popUntil(context, ModalRoute.withName(Navigator.defaultRouteName));
                                      });
                                    },
                                  ),
                                ])
                          ]),
                  const SizedBox(height: 10),
                ]))));
  }
}
