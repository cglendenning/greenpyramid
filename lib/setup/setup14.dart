import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:life_ops/setup/setup1.dart';
import 'package:life_ops/setup/setup15.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:life_ops/navbar.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:life_ops/setup/setup2.dart';

String otherDefault = 'Enter My Own...';

List<String> cat4dd = <String>[categories[3], otherDefault];
List<String> cat5dd = <String>[categories[4], otherDefault];

class Setup14 extends StatefulWidget {
  const Setup14();

  @override
  _Setup14State createState() => _Setup14State();
}

class _Setup14State extends State<Setup14> {
  String dd4Value = cat4dd.first;
  String dd5Value = cat5dd.first;

  @override
  void initState() {
    super.initState();
  }

  _Setup14State();
  FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  final TextEditingController otherText = TextEditingController();

  @override
  Widget build(BuildContext context) {
    analytics.logEvent(name: '${setupVersion}_setup14');
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
              LinearProgressIndicator(
                  value: 16 / 23,
                  color: Color(int.parse("#66CC5D".substring(1, 7), radix: 16) +
                      0xFF000000)),
              const SizedBox(height: 10),
              Text(
                'Essential Values',
                style: mainTextStyle,
              ),
              const SizedBox(height: 10),
              Container(
                  padding: const EdgeInsets.all(10.0),
                  child: const Text(
                      "Now you will define your essential values...")),
              Container(
                  padding: const EdgeInsets.all(10.0),
                  child: const Text(
                      "Choose the two values that will build upon your "
                      "foundational values or choose \"Other\" to enter your "
                      "own. You are not creating tasks just yet - right now, "
                      "just choose your two essential values.")),
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
                  value: dd4Value,
                  borderRadius: BorderRadius.circular(30.0),
                  icon: const Icon(Icons.arrow_drop_down),
                  elevation: 16,
                  style: const TextStyle(color: Colors.black),
                  onChanged: (String? value) {
                    // This is called when the user selects an item.
                    setState(() {
                      if (value == otherDefault) {
                        showOtherDialog(cat4dd, 4);
                      } else {
                        dd4Value = value!;
                      }
                    });
                  },
                  items: cat4dd.map<DropdownMenuItem<String>>((String value) {
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
                  value: dd5Value,
                  borderRadius: BorderRadius.circular(30.0),
                  icon: const Icon(Icons.arrow_drop_down),
                  elevation: 16,
                  style: const TextStyle(color: Colors.black),
                  onChanged: (String? value) {
                    // This is called when the user selects an item.
                    setState(() {
                      if (value == otherDefault) {
                        showOtherDialog(cat5dd, 5);
                      } else {
                        dd5Value = value!;
                      }
                    });
                  },
                  items: cat5dd.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ) // your Dropdown Widget here
                    ),
              ),
              const SizedBox(height: 60),
              const SizedBox(height: 30),
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: <Widget>[
                    RichText(
                      text: TextSpan(
                          text: 'Why Only Two?',
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
                          navigateToSetup15();
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
          analytics.logEvent(name: 'skip_setup3');
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
      title: const Text("Why Only Two?"),
      content: Container(
          padding: const EdgeInsets.all(5.0),
          child: const Text(
              "Focus and consistency are the keys to success. You already "
              "defined your three foundational values. You need to be "
              "intentional about other values you add. If you focus on "
              "everything then you make progress on nothing. "
              "Be intentional.")),
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
            case 4:
              dd4Value = otherText.text;
            case 5:
              dd5Value = otherText.text;
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

  void navigateToSetup15() async {
    // "upsert"...
    cats.removeWhere((item) => item.categoryid == 4);
    cats.removeWhere((item) => item.categoryid == 5);
    cats.add(SetupCat(categoryid: 4, cat: dd4Value));
    cats.add(SetupCat(categoryid: 5, cat: dd5Value));

    var cat1 = cats.firstWhere((cat) => cat.categoryid == 1);
    var cat2 = cats.firstWhere((cat) => cat.categoryid == 2);
    var cat3 = cats.firstWhere((cat) => cat.categoryid == 3);
    var cat4 = cats.firstWhere((cat) => cat.categoryid == 4);
    var cat5 = cats.firstWhere((cat) => cat.categoryid == 5);

    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) =>
              Setup15(cat1.cat, cat2.cat, cat3.cat, cat4.cat, cat5.cat)),
    );
  }
}
