import 'package:flutter/material.dart';
import 'package:life_ops/db.dart';
import 'package:intl/intl.dart' as intl;
import 'package:life_ops/navbar.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class EditTaskDetail extends StatefulWidget {
  final String category;
  final String desc;

  const EditTaskDetail(this.category, this.desc);

  @override
  _EditTaskDetailState createState() => _EditTaskDetailState(category, desc);
}

class _EditTaskDetailState extends State<EditTaskDetail> {
  final String category;
  String desc;

  _EditTaskDetailState(this.category, this.desc);

  final dbHelper = DatabaseHelper.instance;
  final TextEditingController taskDescriptionText = TextEditingController();
  FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  @override
  Widget build(BuildContext context) {
    analytics.logEvent(name: 'edittaskdetail');
    return SafeArea(
        child: Scaffold(
            appBar: const NavBar(),
            body: Center(
                child: Column(children: [
              const SizedBox(height: 10),
              FutureBuilder(
                  future: getTaskDetails(),
                  builder: (context, AsyncSnapshot snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    } else {
                      return Column(children: [
                        const SizedBox(height: 10),
                        Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: <Widget>[
                          Text('${snapshot.data[0].taskdescription}'),
                        GestureDetector(
                            onTap: () {
                               setState(() {
                                showEditDialog(context,
                                    snapshot.data[0]);
                               });
                            },
                            child: const Icon(Icons.edit)),
                        ]),
                        CheckboxListTile(
                            title: const Text('Sunday'),
                            value: toBoolean(snapshot.data[0].sunday),
                            onChanged: (bool? value) {
                              setState(() {
                                dbHelper.rawUpdate(
                                    "update task set sunday = '${value.toString()}' "
                                    "where category = '${snapshot.data[0].category}' and "
                                    "taskdescription = '${snapshot.data[0].taskdescription}'");
                              });
                            }),
                        CheckboxListTile(
                            title: const Text('Monday'),
                            value: toBoolean(snapshot.data[0].monday),
                            onChanged: (bool? value) {
                              setState(() {
                                dbHelper.rawUpdate(
                                    "update task set monday = '${value.toString()}' "
                                        "where category = '${snapshot.data[0].category}' and "
                                        "taskdescription = '${snapshot.data[0].taskdescription}'");
                              });
                            }),

                        CheckboxListTile(
                            title: const Text('Tuesday'),
                            value: toBoolean(snapshot.data[0].tuesday),
                            onChanged: (bool? value) {
                              setState(() {
                                dbHelper.rawUpdate(
                                    "update task set tuesday = '${value.toString()}' "
                                        "where category = '${snapshot.data[0].category}' and "
                                        "taskdescription = '${snapshot.data[0].taskdescription}'");
                              });
                            }),

                        CheckboxListTile(
                            title: const Text('Wednesday'),
                            value: toBoolean(snapshot.data[0].wednesday),
                            onChanged: (bool? value) {
                              setState(() {
                                dbHelper.rawUpdate(
                                    "update task set wednesday = '${value.toString()}' "
                                        "where category = '${snapshot.data[0].category}' and "
                                        "taskdescription = '${snapshot.data[0].taskdescription}'");
                              });
                            }),

                        CheckboxListTile(
                            title: const Text('Thursday'),
                            value: toBoolean(snapshot.data[0].thursday),
                            onChanged: (bool? value) {
                              setState(() {
                                dbHelper.rawUpdate(
                                    "update task set thursday = '${value.toString()}' "
                                        "where category = '${snapshot.data[0].category}' and "
                                        "taskdescription = '${snapshot.data[0].taskdescription}'");
                              });
                            }),

                        CheckboxListTile(
                            title: const Text('Friday'),
                            value: toBoolean(snapshot.data[0].friday),
                            onChanged: (bool? value) {
                              setState(() {
                                dbHelper.rawUpdate(
                                    "update task set friday = '${value.toString()}' "
                                        "where category = '${snapshot.data[0].category}' and "
                                        "taskdescription = '${snapshot.data[0].taskdescription}'");
                              });
                            }),

                        CheckboxListTile(
                            title: const Text('Saturday'),
                            value: toBoolean(snapshot.data[0].saturday),
                            onChanged: (bool? value) {
                              setState(() {
                                dbHelper.rawUpdate(
                                    "update task set saturday = '${value.toString()}' "
                                        "where category = '${snapshot.data[0].category}' and "
                                        "taskdescription = '${snapshot.data[0].taskdescription}'");
                              });
                            }),

                      ]);
                    }
                  }),
            ]))));
  }

  Future<List<Task>> getTaskDetails() async {
    final List<Map<String, dynamic>> maps =
        await dbHelper.querySingleTask(category, desc);

    // Convert the List<Map<String, dynamic> into a List<Task>.
    return List.generate(maps.length, (i) {
      return Task(
          id: maps[i]['id'],
          category: maps[i]['category'],
          taskdescription: maps[i]['taskdescription'],
          sunday: maps[i]['sunday'],
          monday: maps[i]['monday'],
          tuesday: maps[i]['tuesday'],
          wednesday: maps[i]['wednesday'],
          thursday: maps[i]['thursday'],
          friday: maps[i]['friday'],
          saturday: maps[i]['saturday']);
    });
  }

  showEditDialog(BuildContext context, Task task) {
    Widget cancelButton = TextButton(
      child: const Text("Cancel"),
      onPressed: () => {Navigator.pop(context)},
    );
    Widget continueButton = TextButton(
      child: const Text("Update Description"),
      onPressed: () async {
        setState(() {});
        if (task.taskdescription != taskDescriptionText.text) {
          dbHelper.rawDelete(
              "delete from tasklog where taskdescription = '${task.taskdescription}' "
                  "and category = '$category'");

          // Look at each dow column in task and determine whether or not
          // today's dow is set to true. If so, insert into tasklog.
          final intl.DateFormat dowFmt = intl.DateFormat('EEEE');
          var todayFmt = dowFmt.format(DateTime.now()).toString();

          if (todayFmt == 'Sunday' && task.sunday == 'true') {
            // row to insert
            final intl.DateFormat formatter = intl.DateFormat('yyyy-MM-dd');
            Map<String, dynamic> taskLogRow = {
              DatabaseHelper.columnTLCategory: category,
              DatabaseHelper.columnTLTaskDescription: taskDescriptionText.text,
              DatabaseHelper.columnTLChecked: 'false',
              DatabaseHelper.columnTLTaskDate:
              formatter.format(DateTime.now()).toString()
            };
            await dbHelper.insertTaskLog(taskLogRow);
          } else if (todayFmt == 'Monday' && task.monday == 'true') {
            // row to insert
            final intl.DateFormat formatter = intl.DateFormat('yyyy-MM-dd');
            Map<String, dynamic> taskLogRow = {
              DatabaseHelper.columnTLCategory: category,
              DatabaseHelper.columnTLTaskDescription: taskDescriptionText.text,
              DatabaseHelper.columnTLChecked: 'false',
              DatabaseHelper.columnTLTaskDate:
              formatter.format(DateTime.now()).toString()
            };
            await dbHelper.insertTaskLog(taskLogRow);
          } else if (todayFmt == 'Tuesday' && task.tuesday == 'true') {
            // row to insert
            final intl.DateFormat formatter = intl.DateFormat('yyyy-MM-dd');
            Map<String, dynamic> taskLogRow = {
              DatabaseHelper.columnTLCategory: category,
              DatabaseHelper.columnTLTaskDescription: taskDescriptionText.text,
              DatabaseHelper.columnTLChecked: 'false',
              DatabaseHelper.columnTLTaskDate:
              formatter.format(DateTime.now()).toString()
            };
            await dbHelper.insertTaskLog(taskLogRow);
          } else if (todayFmt == 'Wednesday' && task.wednesday == 'true') {
            // row to insert
            final intl.DateFormat formatter = intl.DateFormat('yyyy-MM-dd');
            Map<String, dynamic> taskLogRow = {
              DatabaseHelper.columnTLCategory: category,
              DatabaseHelper.columnTLTaskDescription: taskDescriptionText.text,
              DatabaseHelper.columnTLChecked: 'false',
              DatabaseHelper.columnTLTaskDate:
              formatter.format(DateTime.now()).toString()
            };
            await dbHelper.insertTaskLog(taskLogRow);
          } else if (todayFmt == 'Thursday' && task.thursday == 'true') {
            // row to insert
            final intl.DateFormat formatter = intl.DateFormat('yyyy-MM-dd');
            Map<String, dynamic> taskLogRow = {
              DatabaseHelper.columnTLCategory: category,
              DatabaseHelper.columnTLTaskDescription: taskDescriptionText.text,
              DatabaseHelper.columnTLChecked: 'false',
              DatabaseHelper.columnTLTaskDate:
              formatter.format(DateTime.now()).toString()
            };
            await dbHelper.insertTaskLog(taskLogRow);
          } else if (todayFmt == 'Friday' && task.friday == 'true') {
            // row to insert
            final intl.DateFormat formatter = intl.DateFormat('yyyy-MM-dd');
            Map<String, dynamic> taskLogRow = {
              DatabaseHelper.columnTLCategory: category,
              DatabaseHelper.columnTLTaskDescription: taskDescriptionText.text,
              DatabaseHelper.columnTLChecked: 'false',
              DatabaseHelper.columnTLTaskDate:
              formatter.format(DateTime.now()).toString()
            };
            await dbHelper.insertTaskLog(taskLogRow);
          } else if (todayFmt == 'Saturday' && task.saturday == 'true') {
            // row to insert
            final intl.DateFormat formatter = intl.DateFormat('yyyy-MM-dd');
            Map<String, dynamic> taskLogRow = {
              DatabaseHelper.columnTLCategory: category,
              DatabaseHelper.columnTLTaskDescription: taskDescriptionText.text,
              DatabaseHelper.columnTLChecked: 'false',
              DatabaseHelper.columnTLTaskDate:
              formatter.format(DateTime.now()).toString()
            };
            await dbHelper.insertTaskLog(taskLogRow);
          }
        }

          dbHelper.rawUpdate(
              "update task set taskdescription = '${taskDescriptionText.text}' "
                  "where category = '$category'"
                  " and taskdescription = '${task.taskdescription}'");

        desc = taskDescriptionText.text;
        setState(() {});
        Navigator.pop(context);
      },
    );
    Widget taskDescriptionField = TextField(
      controller: taskDescriptionText,
      textAlign: TextAlign.left,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        hintText: '(Task Description here)',
        hintStyle: TextStyle(color: Colors.grey),
      ),
    );

    Widget warning = const Row(
      children: <Widget>[
      SizedBox(height: 10),
      Flexible(
        child: Text(
          '*NOTE: If a task name is changed, all task log entries for the previous task name will be deleted.',
        style: TextStyle(
          color: Colors.black,
          fontSize: 15,
        ),
        textAlign: TextAlign.center,
      ))]);

    // set up the AlertDialog
    AlertDialog alert = AlertDialog(
      title: const Text("Update Task..."),
      content:
      Container(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Update the task description below."),
              const SizedBox(height: 10),
              taskDescriptionField,
              cancelButton,
              continueButton,
              warning
            ]
        )
      ),
    );
    // show the dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }

  bool toBoolean(String s) {
    return s != '0' && s != 'false' && s != '';
  }

  navigateToEditTask() async {
    Navigator.pop(context);
  }
}

class Task {
  int id = 0;
  String category = '';
  String taskdescription = '';
  String sunday = '';
  String monday = '';
  String tuesday = '';
  String wednesday = '';
  String thursday = '';
  String friday = '';
  String saturday = '';

  Task(
      {required this.id,
      required this.category,
      required this.taskdescription,
      required this.sunday,
      required this.monday,
      required this.tuesday,
      required this.wednesday,
      required this.thursday,
      required this.friday,
      required this.saturday});

  Task.fromMap(dynamic obj) {
    id = obj["id"];
    category = obj["category"];
    taskdescription = obj["taskdescription"];
    sunday = obj["sunday"];
    monday = obj["monday"];
    tuesday = obj["tuesday"];
    wednesday = obj["wednesday"];
    thursday = obj["thursday"];
    friday = obj["friday"];
    saturday = obj["saturday"];
  }
}
