import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:life_ops/setup/setup13.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:life_ops/navbar.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:life_ops/setup/setup1.dart';

String otherDefault = 'Enter My Own...';

List<String> cat1dd = [cats[0].cat, otherDefault];
List<String> cat2dd = [cats[1].cat, otherDefault];
List<String> cat3dd = [cats[2].cat, otherDefault];

class Setup12 extends StatefulWidget {
  const Setup12({super.key});

  @override
  _Setup12State createState() => _Setup12State();
}

class _Setup12State extends State<Setup12> {
  String dd1Value = cat1dd.first;
  String dd2Value = cat2dd.first;
  String dd3Value = cat3dd.first;

  @override
  void initState() {
    super.initState();
  }

  _Setup12State();
  FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  final TextEditingController otherText = TextEditingController();

  @override
  Widget build(BuildContext context) {
    analytics.logEvent(name: '${setupVersion}_setup12');

    const String forward = 'images/svg/forward.svg';
    final Widget svgForward = SvgPicture.asset(forward,
        fit: BoxFit.scaleDown, semanticsLabel: 'forward');

    var mainTextStyle = const TextStyle(
        fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'SourceSans3');


    return SafeArea(
        child: Scaffold(
            appBar: const NavBar(),
            body: Center(
                child: Column(
                    children: [
                      LinearProgressIndicator(
                          value: 11/23,
                          color: Color(int.parse("#66CC5D".substring(1, 7), radix: 16) + 0xFF000000)
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Foundational Values',
                        style: mainTextStyle,
                      ),
                      const SizedBox(height: 10),
                      Container(
                      padding: const EdgeInsets.all(10.0),
                      child: const Text(
                        "Your best possible life will only happen if "
                        "you have clear values. ",
                      )),
                  Container(
                      padding: const EdgeInsets.all(10.0),
                      child: Text(
                        "Choose three values that matter most to you. "
                        "Use \"$otherDefault\" to choose your own foundational values. "
                        "You are choosing values at this step, not tasks yet. ",
                      )),
                  const SizedBox(height: 30),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    height: 40.0,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30.0),
                      color: Colors.lightBlueAccent,
                    ),
                    child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                      value: dd1Value,
                      borderRadius: BorderRadius.circular(30.0),
                      icon: const Icon(Icons.arrow_drop_down),
                      elevation: 16,
                      style: const TextStyle(color: Colors.black),
                      onChanged: (String? value) {
                        // This is called when the user selects an item.
                        setState(() {
                          if (value == otherDefault) {
                            showOtherDialog(cat1dd, 1);
                          } else {
                            dd1Value = value!;
                          }
                        });
                      },
                      items:
                          cat1dd.map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                    ) // your Dropdown Widget here
                        ),
                  ),
                  const SizedBox(height: 60),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    height: 40.0,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30.0),
                      color: Colors.lightBlueAccent,
                    ),
                    child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                      value: dd2Value,
                      borderRadius: BorderRadius.circular(30.0),
                      icon: const Icon(Icons.arrow_drop_down),
                      elevation: 16,
                      style: const TextStyle(color: Colors.black),
                      onChanged: (String? value) {
                        // This is called when the user selects an item.
                        setState(() {
                          if (value == otherDefault) {
                            showOtherDialog(cat2dd, 2);
                          } else {
                            dd2Value = value!;
                          }
                        });
                      },
                      items:
                          cat2dd.map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                    ) // your Dropdown Widget here
                        ),
                  ),
                  const SizedBox(height: 60),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    height: 40.0,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30.0),
                      color: Colors.lightBlueAccent,
                    ),
                    child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                      value: dd3Value,
                      borderRadius: BorderRadius.circular(30.0),
                      icon: const Icon(Icons.arrow_drop_down),
                      elevation: 16,
                      style: const TextStyle(color: Colors.black),
                      onChanged: (String? value) {
                        // This is called when the user selects an item.
                        setState(() {
                          if (value == otherDefault) {
                            showOtherDialog(cat3dd, 3);
                          } else {
                            dd3Value = value!;
                          }
                        });
                      },
                      items:
                          cat3dd.map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                    ) // your Dropdown Widget here
                        ),
                  ),
                  const SizedBox(height: 30),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: <Widget>[
                        RichText(
                          text: TextSpan(
                              text: 'Why Only Three?',
                              style: const TextStyle(
                                  color: Colors.blue,
                                  decoration: TextDecoration.underline,
                                  fontSize: 16),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  setState(() {
                                    showWhyThreeDialog();
                                  });
                                }),
                        ),
                        IconButton(
                          icon: svgForward,
                          onPressed: () {
                            setState(() {
                              navigateToSetup13();
                            });
                          },
                        )
                      ]),
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
                ]))));
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
          analytics.logEvent(name: 'skip_setup1');
          currentCatId = 1;
          currentTaskId = 0;
          cats.clear();
          tasks.clear();
          Navigator.popUntil(
              context,
              ModalRoute.withName(
                  Navigator.defaultRouteName));
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


  showWhyThreeDialog() {

    // set up the buttons
    Widget doneButton = TextButton(
      child: const Text("Gotcha"),
      onPressed: () => {Navigator.pop(context)},
    );
    // set up the AlertDialog
    AlertDialog info = AlertDialog(
      title: const Text("Why Only Three?"),
      content: Container(
          padding: const EdgeInsets.all(5.0),
          child: const Text(
            "Any more than three foundational values dilutes focus "
            "on what really matters in your life. You will have an "
            "opportunity to add more non-foundational values "
            "on a later screen."
          )),
      actions: [
        doneButton,
      ],
    );
    // show the dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return info;
      },
    );
  }

  showOtherDialog(List dd, int cat) {
    // set up the buttons
    otherText.clear();
    Widget cancelButton = TextButton(
      child: const Text("Cancel"),
      onPressed: () => {Navigator.pop(context)},
    );
    Widget doneButton = TextButton(
      child: const Text("Done"),
      onPressed: () {
        if (otherText.text != "") {
          dd.insert(0, otherText.text);
          switch (cat) {
            case 1:
              dd1Value = otherText.text;
            case 2:
              dd2Value = otherText.text;
            case 3:
              dd3Value = otherText.text;
          }
        }
        otherText.clear();
        setState(() {});
        Navigator.pop(context);
      },
    );
    Widget otherField = TextField(
      controller: otherText,
      textAlign: TextAlign.left,
      maxLength: 20,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        hintText: 'What matters most.',
        hintStyle: TextStyle(color: Colors.grey),
      ),
    );

    // set up the AlertDialog
    AlertDialog alert = AlertDialog(
      title: const Text("What Matters Most..."),
      content: const Text("Enter what matters most to you below."),
      actions: [
        otherField,
        cancelButton,
        doneButton,
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

  void navigateToSetup13() async {

    // "upsert"...
    cats.removeWhere((item) => item.categoryid == 1);
    cats.removeWhere((item) => item.categoryid == 2);
    cats.removeWhere((item) => item.categoryid == 3);
    cats.add(SetupCat(categoryid: 1, cat: dd1Value));
    cats.add(SetupCat(categoryid: 2, cat: dd2Value));
    cats.add(SetupCat(categoryid: 3, cat: dd3Value));

    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => Setup13(dd1Value, dd2Value, dd3Value)),
    );
  }
}
