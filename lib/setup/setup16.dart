import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:life_ops/setup/setup1.dart';
import 'package:life_ops/setup/setup17.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:life_ops/navbar.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:life_ops/setup/setup2.dart';

String otherDefault = 'Enter My Own...';

List<String> cat6dd = <String>[categories[5], otherDefault];

class Setup16 extends StatefulWidget {
  const Setup16();

  @override
  _Setup16State createState() => _Setup16State();
}

class _Setup16State extends State<Setup16> {
  String dd6Value = cat6dd.first;

  @override
  void initState() {
    super.initState();
  }

  _Setup16State();
  FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  final TextEditingController otherText = TextEditingController();

  @override
  Widget build(BuildContext context) {
    analytics.logEvent(name: '${setupVersion}_setup16');
    const String forward = 'images/svg/forward.svg';
    final Widget svgForward = SvgPicture.asset(forward,
        fit: BoxFit.scaleDown, semanticsLabel: 'forward');

    var mainTextStyle = const TextStyle(
        fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'SourceSans3');

    return SafeArea(
        child: Scaffold(
            appBar: const NavBar(),
            body: Center(
                child: Column(children: [
              Stack(
                children: [
                  LinearProgressIndicator(
                      value: 20 / 23,
                      minHeight: 6.0,
                      color: Color(int.parse("#66CC5D".substring(1, 7), radix: 16) +
                          0xFF000000)),
                  Positioned(
                    left: (MediaQuery.of(context).size.width - 24) * (20 / 23),
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
                  child: const Text("Now you will define your peak value...")),
              Container(
                  padding: const EdgeInsets.all(10.0),
                  child: const Text(
                      "Choose a value that represents the pinnacle of living "
                      "your best life or choose \"Enter My Own...\" to enter your own. "
                      "This is the value that brings you joy, excitement, "
                      "peace or tranquility. You are not creating tasks just "
                      "yet - right now, just choose your peak value.")),
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
                  value: dd6Value,
                  borderRadius: BorderRadius.circular(30.0),
                  icon: const Icon(Icons.arrow_drop_down),
                  elevation: 16,
                  style: const TextStyle(color: Colors.black),
                  onChanged: (String? value) {
                    // This is called when the user selects an item.
                    setState(() {
                      if (value == otherDefault) {
                        showOtherDialog(cat6dd, 6);
                      } else {
                        dd6Value = value!;
                      }
                    });
                  },
                  items: cat6dd.map<DropdownMenuItem<String>>((String value) {
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
                          text: 'Why Only One?',
                          style: const TextStyle(
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                              fontSize: 16),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              setState(() {
                                showWhyTwoDialog();
                              });
                            }),
                    ),
                    IconButton(
                      icon: svgForward,
                      onPressed: () {
                        setState(() {
                          navigateToSetup17();
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
          analytics.logEvent(name: 'skip_setup5');
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

  showWhyTwoDialog() {
    // set up the buttons
    Widget doneButton = TextButton(
      child: const Text("Gotcha"),
      onPressed: () => {Navigator.pop(context)},
    );
    // set up the AlertDialog
    AlertDialog info = AlertDialog(
      title: const Text("Why Only One?"),
      content: Container(
          padding: const EdgeInsets.all(5.0),
          child: const Text(
              "You have defined your three foundational values and your two "
              "essential values. Your peak value is about "
              "leveraging all of that hard work. It is the one value that "
              "maximizes inspiration, joy and meaning in your life.")),
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
          dd6Value = otherText.text;
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

  void navigateToSetup17() async {
    // "upsert"...
    cats.removeWhere((item) => item.categoryid == 6);
    cats.add(SetupCat(categoryid: 6, cat: dd6Value));

    var cat1 = cats.firstWhere((cat) => cat.categoryid == 1);
    var cat2 = cats.firstWhere((cat) => cat.categoryid == 2);
    var cat3 = cats.firstWhere((cat) => cat.categoryid == 3);
    var cat4 = cats.firstWhere((cat) => cat.categoryid == 4);
    var cat5 = cats.firstWhere((cat) => cat.categoryid == 5);
    var cat6 = cats.firstWhere((cat) => cat.categoryid == 6);

    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => Setup17(
              cat1.cat, cat2.cat, cat3.cat, cat4.cat, cat5.cat, cat6.cat)),
    );
  }
}
