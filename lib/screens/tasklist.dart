import 'package:flutter/material.dart';
import 'package:life_ops/services/db.dart';
import 'package:life_ops/screens/edittasklist.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:life_ops/widgets/navbar.dart';
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

  _TaskListState(this.category, this.taskLogDate);
  FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  final dbHelper = DatabaseHelper.instance;

  var pctCompleteTextStyle = const TextStyle(
      fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Exo2');
  static const _categoryNameStyle =
      TextStyle(fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Exo2');
  static const _essenceStyle = TextStyle(fontSize: 15, fontStyle: FontStyle.italic);

  late Future<(int?, String?)> _essenceContext;

  @override
  void initState() {
    todayFmt = dowFmt.format(DateTime.now()).toString();
    _essenceContext = _loadEssenceContext();
    super.initState();
  }

  // D-047: the category name and its full essence, in that order, above
  // the habit checkboxes. A category with no essence yet (D-005/D-010)
  // renders neither a placeholder nor a prompt to add one — this returns
  // null and the caller skips the block entirely.
  Future<(int?, String?)> _loadEssenceContext() async {
    final categoryId = await dbHelper.getCategoryIdByName(category);
    if (categoryId == null) return (null, null);
    final essence = await dbHelper.getLatestEssenceForCategory(categoryId);
    return (categoryId, essence);
  }

  Future<void> _editEssence(int categoryId, String currentEssence) async {
    final controller = TextEditingController(text: currentEssence);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your essence'),
        content: TextField(controller: controller, maxLines: 4, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (saved != true) return;
    final text = controller.text.trim();
    if (text.isEmpty) return;
    // D-061: essences are versioned, never overwritten — this appends a
    // new version rather than updating the existing row.
    await dbHelper.insertCategoryEssence(categoryId: categoryId, essence: text);
    setState(() => _essenceContext = _loadEssenceContext());
  }

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
                  Text(category, style: _categoryNameStyle),
                  FutureBuilder<(int?, String?)>(
                    future: _essenceContext,
                    builder: (context, snapshot) {
                      final data = snapshot.data;
                      if (data == null || data.$1 == null || data.$2 == null) {
                        return const SizedBox.shrink();
                      }
                      final categoryId = data.$1!;
                      final essence = data.$2!;
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
                        child: Column(
                          children: [
                            Text(essence,
                                textAlign: TextAlign.center, style: _essenceStyle),
                            TextButton(
                              onPressed: () => _editEssence(categoryId, essence),
                              child: const Text('Edit'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
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
                                                dbHelper.setTaskLogChecked(
                                                  category: snapshot
                                                      .data[index].category,
                                                  taskDescription: snapshot
                                                      .data[index]
                                                      .taskdescription,
                                                  taskDate: snapshot
                                                      .data[index].taskdate,
                                                  checked: value ?? false,
                                                );
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
                          return const Center(child: Text(''));
                        } else {
                          // if there are no tasks at all, getCompletionPercentage()
                          // will return -1.
                          if (snapshot.data == -1) {
                            return const Center(child: Text(''));
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
