import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:dart_openai/dart_openai.dart';
import 'package:life_ops/setup/setup18.dart';
import 'package:life_ops/setup/tasks/taskdow.dart';
import 'package:intl/intl.dart' as intl;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:life_ops/navbar.dart';
import 'package:life_ops/utils.dart' as utils;
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:life_ops/setup/setup1.dart';
import 'package:life_ops/secrets.dart';
import 'package:life_ops/services/ai_guard.dart';
import 'package:life_ops/progress_bar.dart';

String defaultText = 'Generating ideas...';
List<String> cat6TaskChoices = <String>[defaultText];
List<SetupTask> tasksForCat6 = [];
bool cat6TasksGenerating = false;

class Cat6Tasks extends StatefulWidget {
  final String cat;

  const Cat6Tasks(this.cat);

  @override
  _Cat6TasksState createState() => _Cat6TasksState(cat);
}

class _Cat6TasksState extends State<Cat6Tasks> {
  String taskValue = cat6TaskChoices.first;
  String cat;

  @override
  void initState() {
    generateTaskList();
    gettasksForCat6();
    super.initState();
  }

  _Cat6TasksState(this.cat);
  FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  final TextEditingController otherText = TextEditingController();

  @override
  Widget build(BuildContext context) {
    analytics.logEvent(name: '${setupVersion}_cat6tasks');
    const String forward = 'images/svg/forward.svg';
    final Widget svgForward = SvgPicture.asset(forward,
        fit: BoxFit.scaleDown, semanticsLabel: 'forward');

    var mainTextStyle = const TextStyle(
        fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Exo2');

    return SafeArea(
        child: Scaffold(
            appBar: NavBar(
              leading: BackButton(
                color: Colors.white,
                onPressed: () {
                  cat6TaskChoices.clear();
                  cat6TaskChoices.add(defaultText);
                  cat6TaskChoices.add(taskValue);
                  Navigator.pop(context);
                },
              ),
            ),
            body: Center(
                child: Column(children: [
              ProgressBar(currentStep: 22, totalSteps: 23),
              const SizedBox(height: 10),
              Text(
                cat,
                style: mainTextStyle,
              ),
              const SizedBox(height: 10),
              Container(
                  padding: const EdgeInsets.all(10.0),
                  child: Text("Daily action is the best way to support $cat.")),
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
                          itemCount: tasksForCat6.length,
                          itemBuilder: (BuildContext context, int index) {
                            return ListTile(
                              title: Text(tasksForCat6[index].taskdescription),
                              subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(tasksForCat6[index].category),
                                    Text(getDaysOfWeek(tasksForCat6[index]))
                                  ]),
                              trailing: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      showDeleteAlertDialog(context,
                                          tasksForCat6[index].taskdescription);
                                    });
                                  },
                                  child: const Icon(Icons.delete_rounded)),
                            );
                          }))),
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: <Widget>[
                    GestureDetector(
                        onTap: () {
                          if (!cat6TasksGenerating) {
                            setState(() {
                              cat6TaskChoices.clear();
                              cat6TaskChoices.add(defaultText);
                              cat6TaskChoices.add(taskValue);
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
                        menuMaxHeight: MediaQuery.of(context).size.height / 3,
                        borderRadius: BorderRadius.circular(30.0),
                        icon: const Icon(Icons.arrow_drop_down),
                        elevation: 16,
                        style: const TextStyle(color: Colors.black),
                        onChanged: (String? value) {
                          // This is called when the user selects an item.
                          setState(() {
                            if (value == "Enter My Own...") {
                              showOtherDialog(cat6TaskChoices);
                            } else if (!cat6TaskChoices.contains(value)) {
                              taskValue = cat6TaskChoices.first;
                            } else {
                              taskValue = value!;
                            }
                          });
                        },
                        items: cat6TaskChoices
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
                      onPressed: !cat6TasksGenerating
                          ? () {
                              cat6TaskChoices.clear();
                              cat6TaskChoices.add(defaultText);
                              cat6TaskChoices.add(taskValue);
                              navigateToSetupTaskDow();
                            }
                          : null,
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
                          cat6TaskChoices.clear();
                          cat6TaskChoices.add(defaultText);
                          if (taskValue != defaultText) {
                            cat6TaskChoices.add(taskValue);
                          }
                          navigateToSetup18();
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
          analytics.logEvent(name: 'skip_cat6tasks');
          currentCatId = 1;
          currentTaskId = 0;
          tasksForCat6.clear();
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
        tasksForCat6
            .removeWhere((item) => item.taskdescription == taskdescription);
        tasks.removeWhere((item) => item.taskdescription == taskdescription);
        Navigator.pop(context);
      },
    );
    // set up the AlertDialog
    AlertDialog alert = AlertDialog(
      title: const Text("Delete Task?"),
      content: const Text(
          "Press \"Delete\" to delete this task or cancel to return to the previous screen."),
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
      taskValue = cat6TaskChoices.first;
      cat6TasksGenerating = true;
    });

    OpenAI.apiKey = openAIApiKey;

    var prompt = utils.Utils().taskPrompt(cat);
    const int timeout = 20;

    String chatResult = "";

    try {
      await AiGuard.instance.acquire();
      OpenAIChatCompletionModel chatCompletion =
          await OpenAI.instance.chat.create(
        model: "gpt-4o",
        maxTokens: 400,
        messages: [
          OpenAIChatCompletionChoiceMessageModel(
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(prompt),
            ],
            role: OpenAIChatMessageRole.user,
          ),
        ],
      ).timeout(const Duration(seconds: timeout));

      chatResult =
          chatCompletion.choices.first.message.content?.first.text ?? '';
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
    cat6TaskChoices.clear();
    cat6TaskChoices = chatResult.split("|");
    cat6TaskChoices.add("Enter My Own...");
    taskValue = cat6TaskChoices.first;

    setState(() {});

    cat6TasksGenerating = false;
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

  void gettasksForCat6() {
    // constrain the task list to just those for this category.
    // may be silly to re-build this list repeatedly but whatevs.
    tasksForCat6.clear();
    tasks.forEach((element) {
      if (element.category == cat) {
        tasksForCat6.add(element);
      }
    });
  }

  void navigateToSetup18() async {
    for (var category in cats) {
      if (kDebugMode) {
        print('categoryid: ${category.categoryid} cat: ${category.cat}');
      }
    }

    // "upsert"...
    cats.removeWhere((item) => item.categoryid == 6);
    cats.add(SetupCat(categoryid: 6, cat: cat));

    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => Setup18(cats[0].cat, cats[1].cat, cats[2].cat,
              cats[3].cat, cats[4].cat, cats[5].cat)),
    ).then((value) => currentCatId = 6);
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
    gettasksForCat6();
    setState(() {});
  }
}
