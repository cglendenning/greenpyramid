import 'package:flutter/material.dart';
import 'package:life_ops/setup/setup1.dart';
import 'package:life_ops/navbar.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class SetupTaskDow extends StatefulWidget {
  final String cat;
  final String taskDesc;

  const SetupTaskDow(this.cat, this.taskDesc);

  @override
  _SetupTaskDowState createState() => _SetupTaskDowState(cat, taskDesc);
}

class _SetupTaskDowState extends State<SetupTaskDow> {
  String cat;
  String taskDesc;

  @override
  void initState() {
    super.initState();
  }

  _SetupTaskDowState(this.cat, this.taskDesc);
  FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  final TextEditingController otherText = TextEditingController();

  @override
  Widget build(BuildContext context) {
    analytics.logEvent(name: '${setupVersion}_taskdow');
    var mainTextStyle = const TextStyle(
        fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Exo2');
    return SafeArea(
        child: Scaffold(
            appBar: const NavBar(),
            body: Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                  const SizedBox(height: 10),
                  Text(
                    cat,
                    style: mainTextStyle,
                  ),
                  const SizedBox(height: 10),
                  Container(
                      padding: const EdgeInsets.all(10.0),
                      child:
                          Text("Choose the days of week that you will execute "
                              "the task \"$taskDesc\"")),
                  const SizedBox(height: 10),
                  CheckboxListTile(
                      title: const Text('Sunday'),
                      value: toBoolean(tasks
                          .firstWhere(
                              (item) => item.taskdescription == taskDesc)
                          .sunday),
                      onChanged: (bool? value) {
                        setState(() {
                          tasks
                              .firstWhere(
                                  (item) => item.taskdescription == taskDesc)
                              .sunday = value.toString();
                        });
                      }),
                  CheckboxListTile(
                      title: const Text('Monday'),
                      value: toBoolean(tasks
                          .firstWhere(
                              (item) => item.taskdescription == taskDesc)
                          .monday),
                      onChanged: (bool? value) {
                        setState(() {
                          tasks
                              .firstWhere(
                                  (item) => item.taskdescription == taskDesc)
                              .monday = value.toString();
                        });
                      }),
                  CheckboxListTile(
                      title: const Text('Tuesday'),
                      value: toBoolean(tasks
                          .firstWhere(
                              (item) => item.taskdescription == taskDesc)
                          .tuesday),
                      onChanged: (bool? value) {
                        setState(() {
                          tasks
                              .firstWhere(
                                  (item) => item.taskdescription == taskDesc)
                              .tuesday = value.toString();
                        });
                      }),
                  CheckboxListTile(
                      title: const Text('Wednesday'),
                      value: toBoolean(tasks
                          .firstWhere(
                              (item) => item.taskdescription == taskDesc)
                          .wednesday),
                      onChanged: (bool? value) {
                        setState(() {
                          tasks
                              .firstWhere(
                                  (item) => item.taskdescription == taskDesc)
                              .wednesday = value.toString();
                        });
                      }),
                  CheckboxListTile(
                      title: const Text('Thursday'),
                      value: toBoolean(tasks
                          .firstWhere(
                              (item) => item.taskdescription == taskDesc)
                          .thursday),
                      onChanged: (bool? value) {
                        setState(() {
                          tasks
                              .firstWhere(
                                  (item) => item.taskdescription == taskDesc)
                              .thursday = value.toString();
                        });
                      }),
                  CheckboxListTile(
                      title: const Text('Friday'),
                      value: toBoolean(tasks
                          .firstWhere(
                              (item) => item.taskdescription == taskDesc)
                          .friday),
                      onChanged: (bool? value) {
                        setState(() {
                          tasks
                              .firstWhere(
                                  (item) => item.taskdescription == taskDesc)
                              .friday = value.toString();
                        });
                      }),
                  CheckboxListTile(
                      title: const Text('Saturday'),
                      value: toBoolean(tasks
                          .firstWhere(
                              (item) => item.taskdescription == taskDesc)
                          .saturday),
                      onChanged: (bool? value) {
                        setState(() {
                          tasks
                              .firstWhere(
                                  (item) => item.taskdescription == taskDesc)
                              .saturday = value.toString();
                        });
                      }),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: <Widget>[
                        ElevatedButton(
                          onPressed: () {
                            setState(() {});
                            Navigator.pop(context);
                          },
                          child: const Text('Done'),
                        ),
                      ]),
                ]))));
  }

  navigateBack() {
    Navigator.pop(context);
  }

  bool toBoolean(String s) {
    return s != '0' && s != 'false' && s != '';
  }
}
