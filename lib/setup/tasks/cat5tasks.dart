import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:dart_openai/dart_openai.dart';
import 'package:life_ops/setup/setup16.dart';
import 'package:life_ops/setup/tasks/taskdow.dart';
import 'package:intl/intl.dart' as intl;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:life_ops/navbar.dart';
import 'package:life_ops/utils.dart' as utils;
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:life_ops/setup/setup1.dart';
import 'package:life_ops/secrets.dart';

String defaultText = 'Generating ideas...';
List<String> cat5TaskChoices = <String>[defaultText];
List<SetupTask> tasksForCat5 = [];
bool cat5TasksGenerating = false;


class Cat5Tasks extends StatefulWidget {
  final String cat;

  const Cat5Tasks(this.cat);

  @override
  _Cat5TasksState createState() => _Cat5TasksState(cat);
}

class _Cat5TasksState extends State<Cat5Tasks> {
  String taskValue = cat5TaskChoices.first;
  String cat;

  @override
  void initState() {
    generateTaskList();
    gettasksForCat5();
    super.initState();
  }

  _Cat5TasksState(this.cat);
  FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  final TextEditingController otherText = TextEditingController();

  @override
  Widget build(BuildContext context) {
    analytics.logEvent(name: '${setupVersion}_cat5tasks');
    const String forward = 'images/svg/forward.svg';
    final Widget svgForward = SvgPicture.asset(forward,
        fit: BoxFit.scaleDown, semanticsLabel: 'forward');

    var mainTextStyle = const TextStyle(
        fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'SourceSans3');

    return SafeArea(
        child: Scaffold(
            appBar: NavBar(
              leading: BackButton(
                color: Colors.white,
                onPressed: () {
                  cat5TaskChoices.clear();
                  cat5TaskChoices.add(defaultText);
                  cat5TaskChoices.add(taskValue);
                  Navigator.pop(context);
                },
              ),
            ),
            body: Center(
                child: Column(
                    children: [
                      LinearProgressIndicator(
                          value: 19/23,
                          color: Color(int.parse("#66CC5D".substring(1, 7), radix: 16) + 0xFF000000)
                      ),
                      const SizedBox(height: 10),
                  Text(
                    cat,
                    style: mainTextStyle,
                  ),
                  const SizedBox(height: 10),
                  Container(
                      padding: const EdgeInsets.all(10.0),
                      child: Text(
                          "Daily action is the best way to support $cat.")),
                  Container(
                      padding: const EdgeInsets.all(10.0),
                      child: const Text(
                          "We generated some suggestions in the pick list below. "
                              "Choose from the list, choose \"Enter My Own...\", or "
                              "press the refresh icon to generate more suggestions.\n\n"
                              "Click \"Save\" to save this task before moving on.")),
                  const SizedBox(height: 30),
                  Container(
                      // constrain the scrollview to 1/3 of the height
                      // of the screen.
                      height: MediaQuery.of(context).size.height / 4,
                      child: Scrollbar(
                          child: ListView.builder(
                              itemCount: tasksForCat5.length,
                              itemBuilder: (BuildContext context, int index) {
                                return ListTile(
                                  title:
                                      Text(tasksForCat5[index].taskdescription),
                                  subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(tasksForCat5[index].category),
                                        Text(getDaysOfWeek(tasksForCat5[index]))
                                      ]),
                                  trailing:
                                        GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                showDeleteAlertDialog(
                                                    context,
                                                    tasksForCat5[index]
                                                        .taskdescription);
                                              });
                                            },
                                            child: const Icon(
                                                Icons.delete_rounded)),
                                );
                              }))),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: <Widget>[
                        GestureDetector(
                            onTap: () {
                              if (!cat5TasksGenerating) {
                                setState(() {
                                  cat5TaskChoices.clear();
                                  cat5TaskChoices.add(defaultText);
                                  cat5TaskChoices.add(taskValue);
                                  generateTaskList();
                                });
                              }
                            },
                            child: const Icon(
                              Icons.refresh,
                              color: Colors.blue,
                              size: 25,
                            )),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          height: 40.0,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30.0),
                            color: Colors.yellow,
                          ),
                          child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                            value: taskValue,
                                menuMaxHeight:
                                MediaQuery.of(context).size.height / 3,
                                borderRadius: BorderRadius.circular(30.0),
                            icon: const Icon(Icons.arrow_drop_down),
                            elevation: 16,
                            style: const TextStyle(color: Colors.black),
                            onChanged: (String? value) {
                              // This is called when the user selects an item.
                              setState(() {
                                if (value == "Enter My Own...") {
                                  showOtherDialog(cat5TaskChoices);
                                } else if (!cat5TaskChoices.contains(value)) {
                                  taskValue = cat5TaskChoices.first;
                                } else {
                                  taskValue = value!;
                                }
                              });
                            },
                            items: cat5TaskChoices
                                .map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                          ) // your Dropdown Widget here
                              ),
                        ),
                        ElevatedButton(
                          onPressed: !cat5TasksGenerating ? (){
                            cat5TaskChoices.clear();
                            cat5TaskChoices.add(defaultText);
                            cat5TaskChoices.add(taskValue);
                            navigateToSetupTaskDow();
                          } : null,
                          child: const Text('Save'),
                        ),
                      ]),
                  const SizedBox(height: 30),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: <Widget>[
                        IconButton(
                          icon: svgForward,
                          onPressed: () {
                            setState(() {
                              cat5TaskChoices.clear();
                              cat5TaskChoices.add(defaultText);
                              if (taskValue != defaultText) {
                                cat5TaskChoices.add(taskValue);
                              }
                              navigateToSetup16();
                            });
                          },
                        ),
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
          analytics.logEvent(name: 'skip_cat5tasks');
          currentCatId = 1;
          currentTaskId = 0;
          tasksForCat5.clear();
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


  showDeleteAlertDialog(BuildContext context, String taskdescription) {
    // set up the buttons
    Widget cancelButton = TextButton(
      child: const Text("Cancel"),
      onPressed: () => {Navigator.pop(context)},
    );
    Widget continueButton = TextButton(
      child: const Text("Delete!"),
      onPressed: () {
        setState(() {});
        tasksForCat5
            .removeWhere((item) => item.taskdescription == taskdescription);
        tasks.removeWhere((item) => item.taskdescription == taskdescription);
        Navigator.pop(context);
      },
    );
    // set up the AlertDialog
    AlertDialog alert = AlertDialog(
      title: const Text("Delete Task?"),
      content: const Text("Press \"Delete\" to delete this task or cancel to return to the previous screen."),
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

  showOtherDialog(List task) {
    // set up the buttons
    otherText.clear();

    Widget cancelButton = TextButton(
      child: const Text("Cancel"),
      onPressed: () => {Navigator.pop(context)},
    );
    Widget continueButton = TextButton(
      child: const Text("Done"),
      onPressed: () {
        if (otherText.text != "") {
          task.add(otherText.text);
          taskValue = otherText.text;
        }
        otherText.clear();
        setState(() {});
        Navigator.pop(context);
      },
    );
    Widget otherField = TextField(
      controller: otherText,
      textAlign: TextAlign.left,
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

  Future<String> generateTaskList() async {
    setState(() {
      taskValue = cat5TaskChoices.first;
      cat5TasksGenerating = true;
    });

    OpenAI.apiKey = openAIApiKey;

    var prompt = utils.Utils().taskPrompt(cat);
    const int timeout = 20;

    String chatResult = "";

    try {
      OpenAIChatCompletionModel chatCompletion =
          await OpenAI.instance.chat.create(
        model: "gpt-4o",
        messages: [
          OpenAIChatCompletionChoiceMessageModel(
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(prompt),
            ],
            role: OpenAIChatMessageRole.user,
          ),
        ],
      ).timeout(const Duration(seconds: timeout));

      chatResult = chatCompletion.choices.first.message.content?.first.text ?? '';
    } catch (e, s) {
      if (kDebugMode) {
        print(e);
      }
      if (kDebugMode) {
        print(s);
      }
    }

    if (kDebugMode) {
      print(chatResult);
    }
    cat5TaskChoices.clear();
    cat5TaskChoices = chatResult.split("|");
    cat5TaskChoices.add("Enter My Own...");
    taskValue = cat5TaskChoices.first;

    setState(() {});

    cat5TasksGenerating = false;
    return chatResult;
  }

  String getDaysOfWeek(SetupTask task) {
    String dowString = "";
    String dowPrefix = "[";
    String dowSuffix = "]";
    List<String> dows = [];

    if (task.sunday == "true") {
      dows.add("Sun");
    }
    if (task.monday == "true") {
      dows.add("Mon");
    }
    if (task.tuesday == "true") {
      dows.add("Tue");
    }
    if (task.wednesday == "true") {
      dows.add("Wed");
    }
    if (task.thursday == "true") {
      dows.add("Thu");
    }
    if (task.friday == "true") {
      dows.add("Fri");
    }
    if (task.saturday == "true") {
      dows.add("Sat");
    }

    if (dows.length == 7) {
      dowString = dowPrefix + "Every Day" + dowSuffix;
    } else {
      dowString = dows.toString();
    }

    return dowString;
  }

  void gettasksForCat5() {
    // constrain the task list to just those for this category.
    // may be silly to re-build this list repeatedly but whatevs.
    tasksForCat5.clear();
    tasks.forEach((element) {
      if (element.category == cat) {
        tasksForCat5.add(element);
      }
    });
  }

  void navigateToSetup16() async {

    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => const Setup16()),
    ).then((value) => currentCatId = 5);
  }

  void navigateToSetupTaskDow() async {
    final intl.DateFormat formatter = intl.DateFormat('yyyy-MM-dd');

    tasks.add(SetupTask(
        id: currentTaskId++,
        category: cat,
        taskdescription: taskValue,
        sunday: "true",
        monday: "true",
        tuesday: "true",
        wednesday: "true",
        thursday: "true",
        friday: "true",
        saturday: "true",
        createDate: formatter.format(DateTime.now()).toString()));

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SetupTaskDow(cat, taskValue)),
    );
    generateTaskList();
    gettasksForCat5();
    setState(() {});
  }
}
