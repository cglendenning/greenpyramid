import 'package:flutter/material.dart';
import 'package:life_ops/pyramid.dart';
import 'package:flutter/gestures.dart';
import 'package:life_ops/setup/tasks/cat6tasks.dart';
import 'package:life_ops/setup/setup1.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:life_ops/navbar.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class Setup17 extends StatefulWidget {
  final String dd1Value;
  final String dd2Value;
  final String dd3Value;
  final String dd4Value;
  final String dd5Value;
  final String dd6Value;

  const Setup17(this.dd1Value, this.dd2Value, this.dd3Value, this.dd4Value,
      this.dd5Value, this.dd6Value);

  @override
  State<Setup17> createState() =>
      _Setup17State(dd1Value, dd2Value, dd3Value, dd4Value, dd5Value, dd6Value);
}

class _Setup17State extends State<Setup17> {
  String dd1Value;
  String dd2Value;
  String dd3Value;
  String dd4Value;
  String dd5Value;
  String dd6Value;

  @override
  void initState() {
    super.initState();
  }

  _Setup17State(this.dd1Value, this.dd2Value, this.dd3Value, this.dd4Value,
      this.dd5Value, this.dd6Value);
  FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  @override
  Widget build(BuildContext context) {
    analytics.logEvent(name: '${setupVersion}_setup17');
    Color green =
        Color(int.parse("#66CC5D".substring(1, 7), radix: 16) + 0xFF000000);

    final lg = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [green, green],
    );

    const String forward = 'images/svg/forward.svg';
    final Widget svgForward = SvgPicture.asset(forward,
        fit: BoxFit.scaleDown, semanticsLabel: 'forward');

    double pyramidWidth = MediaQuery.of(context).size.width * 0.87;
    double pyramidHeight = MediaQuery.of(context).size.width * 0.82;

    var mainTextStyle = const TextStyle(
        fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'SourceSans3');

    return Container(
        color: Colors.black,
        child: SafeArea(
            child: Scaffold(
          appBar: const NavBar(),
          body: Column(children: [
            Stack(
              children: [
                LinearProgressIndicator(
                    value: 21 / 23,
                    minHeight: 6.0,
                    color: Color(int.parse("#66CC5D".substring(1, 7), radix: 16) +
                        0xFF000000)),
                Positioned(
                  left: (MediaQuery.of(context).size.width - 24) * (21 / 23),
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
              'Peak Value',
              style: mainTextStyle,
            ),
            const SizedBox(height: 10),
            Container(
                padding: const EdgeInsets.all(10.0),
                child: const Text("Your peak value builds on top of your "
                    "foundational and essential values. Let's now define "
                    "your daily actions for your peak value...")),
            const SizedBox(height: 20),
            Stack(children: <Widget>[
              CustomPaint(
                  size: Size(pyramidWidth, pyramidHeight),
                  painter: DrawCat1(lg, dd1Value, 0)),
              CustomPaint(
                  size: Size(pyramidWidth, pyramidHeight),
                  painter: DrawCat2(lg, dd2Value, 0)),
              CustomPaint(
                  size: Size(pyramidWidth, pyramidHeight),
                  painter: DrawCat3(lg, dd3Value, 0)),
              CustomPaint(
                  size: Size(pyramidWidth, pyramidHeight),
                  painter: DrawCat4(lg, dd4Value, 0)),
              CustomPaint(
                  size: Size(pyramidWidth, pyramidHeight),
                  painter: DrawCat5(lg, dd5Value, 0)),
              CustomPaint(
                  size: Size(pyramidWidth, pyramidHeight),
                  painter: DrawCat6(lg, dd6Value, 0)),
            ]),
            const SizedBox(height: 40),
            IconButton(
              icon: svgForward,
              onPressed: () {
                setState(() {
                  navigateToCat6Tasks();
                });
              },
            ),
            const SizedBox(height: 20),
            RichText(
              text: TextSpan(
                  text: 'Skip Setup',
                  style: const TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                      fontSize: 12),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      setState(() {
                        showSkipAlertDialog(context);
                      });
                    }),
            ),
          ]),
        )));
  }

  showSkipAlertDialog(BuildContext context) {
    // set up the buttons
    Widget cancelButton = TextButton(
      child: const Text("Cancel"),
      onPressed: () => {Navigator.pop(context)},
    );
    Widget continueButton = TextButton(
      child: const Text("Skip Setup"),
      onPressed: () {
        setState(() {
          analytics.logEvent(name: 'skip_setup6');
          currentCatId = 1;
          currentTaskId = 0;
          cats.clear();
          tasks.clear();
          Navigator.popUntil(
              context, ModalRoute.withName(Navigator.defaultRouteName));
        });
      },
    );
    // set up the AlertDialog
    AlertDialog alert = AlertDialog(
      title: const Text("Skip Setup?"),
      content: const Text(
          "Green Pyramid will not be useful to you until you complete setup. "
          "You can resume setup through the menu in the upper right of the home "
          "screen. Press \"Skip Setup\" to skip setup or \"Cancel\" to continue "
          "setup."),
      actions: [
        cancelButton,
        continueButton,
      ],
    );
    // show the dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }

  void navigateToCat6Tasks() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => Cat6Tasks(dd6Value)),
    );
  }
}

class Cat {
  int categoryid = 0;
  String cat = '';
  int pctComplete = 0;

  Cat({required this.categoryid, required this.cat});

  Cat.fromMap(dynamic obj) {
    categoryid = obj["categoryid"];
    cat = obj["cat"];
  }
}
