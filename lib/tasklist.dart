import 'package:flutter/material.dart';
import 'package:life_ops/db.dart';
import 'package:life_ops/edittasklist.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:life_ops/navbar.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class TaskList extends StatefulWidget {
  final String category;
  final String taskLogDate;

  const TaskList(this.category, this.taskLogDate);

  @override
  _TaskListState createState() => _TaskListState(category, taskLogDate);
}

class _TaskListState extends State<TaskList> {
  final String category;
  String taskLogDate;
  DateFormat dowFmt = DateFormat('EEEE');
  String todayFmt = '';

  @override
  void initState() {
    todayFmt = dowFmt.format(DateTime.now()).toString();
    super.initState();
  }

  _TaskListState(this.category, this.taskLogDate);
  FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  final dbHelper = DatabaseHelper.instance;

  var pctCompleteTextStyle = const TextStyle(
      fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'SourceSans3');

  @override
  Widget build(BuildContext context) {
    analytics.logEvent(name: 'tasklist');
    return SafeArea(
        child: Scaffold(
            appBar: const NavBar(),
            body: Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text('$category Log'),
                  FutureBuilder(
                      future: getTaskLog(),
                      builder: (context, AsyncSnapshot snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        } else {
                          return Container(
                              // constrain the scrollview to 1/3 of the height
                              // of the screen.
                              height: MediaQuery.of(context).size.height / 3,
                              child: Scrollbar(
                                  child: ListView.builder(
                                      itemCount: snapshot.data.length,
                                      itemBuilder:
                                          (BuildContext context, int index) {
                                        return CheckboxListTile(
                                            title: Text(
                                                '${snapshot.data[index].taskdescription}'),
                                            subtitle: Text(
                                                '${snapshot.data[index].category}'),
                                            value: toBoolean(
                                                snapshot.data[index].checked),
                                            onChanged: (bool? value) {
                                              setState(() {
                                                var v = value.toString();
                                                snapshot.data[index].checked =
                                                    v;
                                                dbHelper.rawUpdate(
                                                    "update tasklog set checked = '${value.toString()}' "
                                                    "where taskdescription = '${snapshot.data[index].taskdescription}' "
                                                    " and category = '${snapshot.data[index].category}'"
                                                    " and taskdate = '${snapshot.data[index].taskdate}'");
                                              });
                                            });
                                      })));
                        }
                      }),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      navigateToEditTaskList();
                    },
                    child: const Text('Edit Task List >'),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    height: 80,
                    width: MediaQuery.of(context).size.width * 0.87,
                      child: CupertinoDatePicker(
                      key: UniqueKey(),
                      mode: CupertinoDatePickerMode.date,
                      minimumDate: DateFormat("yyyy-MM-dd").parse("2023-06-01"),
                      maximumDate: DateTime.now(),
                      showDayOfWeek: true,
                      dateOrder: DatePickerDateOrder.dmy,
                      initialDateTime:
                          DateFormat("yyyy-MM-dd").parse(taskLogDate),
                      onDateTimeChanged: (DateTime newDateTime) {
                        setState(() {
                          DateFormat formatter = DateFormat('yyyy-MM-dd');
                          taskLogDate = formatter.format(newDateTime);
                          todayFmt = dowFmt.format(newDateTime).toString();
                        });
                        // Do something
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  FutureBuilder(
                    future: combined(7),
                      builder: (context, AsyncSnapshot snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                              child: Text(
                                  ''));
                        } else {
                          // if there are no tasks at all, getCompletionPercentage()
                          // will return -1.
                          if (snapshot.data == -1) {
                            return const Center(
                                child: Text(
                                    ''));
                          } else {
                            return Text(
                                '${snapshot.data.toString()} Percent Complete (7 days)',
                            style: pctCompleteTextStyle);
                          }
                        }
                      }),
                  const SizedBox(height: 10),
                  FutureBuilder(
                      future: combined(30),
                      builder: (context, AsyncSnapshot snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                              child: Text(
                                  'Click "Edit Task List >" to add tasks.'));
                        } else {
                          // if there are no tasks at all, getCompletionPercentage()
                          // will return -1.
                          if (snapshot.data == -1) {
                            return const Center(
                                child: Text(
                                    'Click "Edit Task List >" to add tasks.'));
                          } else {
                            return Text(
                                '${snapshot.data.toString()} Percent Complete (30 days)',
                                style: pctCompleteTextStyle);
                          }
                        }
                      }),
                ]))));
  }

  void navigateToEditTaskList() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditTaskList(category)),
    );
    setState(() {
      // _taskLogFuture = getTaskLog();
    });
  }

  Future<List<TaskLog>> getTaskLog() async {

    // Is there a row for this category and date in tasklog?
    final List<Map<String, dynamic>> taskLogCount =
        await dbHelper.queryTaskLogByCategory(category, taskLogDate);

    // if there is no row for this category and date in tasklog,
    // insert one only if the day of week is not blacked out in task.

    if (taskLogCount.isEmpty) {
      dbHelper.insertTaskLogForCategory(category, taskLogDate, todayFmt);
    }

    // second pull now that there are rows.
    final List<Map<String, dynamic>> maps =
        await dbHelper.queryTaskLogByCategory(category, taskLogDate);

    // Convert the List<Map<String, dynamic> into a List<Task>.
    return List.generate(maps.length, (i) {
      return TaskLog(
          id: maps[i]['id'],
          category: maps[i]['category'],
          taskdescription: maps[i]['taskdescription'],
          checked: maps[i]['checked'],
          taskdate: maps[i]['taskdate']);
    });
  }

  Future<List<Task>> getTaskDetails(String cat, String desc) async {
    final List<Map<String, dynamic>> maps =
    await dbHelper.querySingleTask(cat, desc);

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


  // Using the technique from here because getTaskLog() was
  // being called after getCompletionPercentage() when flipping
  // to a new date.
  // https://stackoverflow.com/questions/68067710/using-a-futurebuilder-with-one-future-depends-on-the-results-on-the-other-future
  Future<int> combined(int days) async {
    // List<TaskLog> t = await getTaskLog();
    return dbHelper.getCompletionPercentage(category, days);
  }

  bool toBoolean(String s) {
    return s != '0' && s != 'false' && s != '';
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




class TaskLog {
  int id = 0;
  String category = '';
  String taskdescription = '';
  String checked = '';
  String taskdate = '';

  TaskLog(
      {required this.id,
      required this.category,
      required this.taskdescription,
      required this.checked,
      required this.taskdate});

  TaskLog.fromMap(dynamic obj) {
    id = obj["id"];
    category = obj["category"];
    taskdescription = obj["taskdescription"];
    checked = obj["checked"];
    taskdate = obj["taskdate"];
  }
}
