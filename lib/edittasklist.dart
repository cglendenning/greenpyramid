import 'package:flutter/material.dart';
import 'package:life_ops/db.dart';
import 'package:life_ops/edittaskdetail.dart';
import 'package:flutter/gestures.dart';
import 'package:intl/intl.dart' as intl;
import 'package:life_ops/navbar.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class EditTaskList extends StatefulWidget {
  final String category;

  const EditTaskList(this.category);

  @override
  _EditTaskListState createState() => _EditTaskListState(category);
}

class _EditTaskListState extends State<EditTaskList> {
  final String category;

  _EditTaskListState(this.category);
  FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  final dbHelper = DatabaseHelper.instance;
  final TextEditingController taskDescriptionText = TextEditingController();

  @override
  Widget build(BuildContext context) {
    analytics.logEvent(name: 'edittasklist');
    return SafeArea(
        child: Scaffold(
            appBar: const NavBar(),
            body: Center(
                child: Column(children: [
                  const SizedBox(height: 10),
                  Text(category),
                  FutureBuilder(
                  future: getTasks(),
                  builder: (context, AsyncSnapshot snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    } else {
                      return Container(
                          // constrain the scrollview to 1/3 of the height
                          // of the screen.
                          height: MediaQuery.of(context).size.height / 3,
                          child: Scrollbar(
                              child: ListView.builder(
                                  scrollDirection: Axis.vertical,
                                  shrinkWrap: true,
                                  itemCount: snapshot.data.length,
                                  itemBuilder:
                                      (BuildContext context, int index) {
                                    return ListTile(
                                      title: Text(
                                          '${snapshot.data[index].taskdescription}'),
                                      subtitle: Text(
                                          '${snapshot.data[index].category}'),
                                      trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    showDeleteAlertDialog(
                                                        context,
                                                        snapshot.data[index]
                                                            .taskdescription);
                                                  });
                                                },
                                                child: const Icon(
                                                    Icons.delete_rounded)),
                                            const SizedBox(width: 60),
                                            GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    navigateToEditTaskDetail(
                                                        snapshot.data[index]
                                                            .category,
                                                    snapshot.data[index]
                                                            .taskdescription);
                                                  });
                                                },
                                                child: const Icon(Icons.edit)),
                                          ]),
                                    );
                                  })));
                    }
                  }),
              const SizedBox(height: 10),
              RichText(
                text: TextSpan(
                    text: ' Add Task',
                    style: const TextStyle(
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                        fontSize: 16),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        setState(() {
                          showAddDialog();
                        });
                      }),
              ),
              const SizedBox(height: 10),
            ]))));
  }

  Future<List<EditTask>> getTasks() async {
    final List<Map<String, dynamic>> maps =
        await dbHelper.queryTasksByCategory(category);

    // Convert the List<Map<String, dynamic> into a List<Task>.
    return List.generate(maps.length, (i) {
      return EditTask(
          id: maps[i]['id'],
          category: maps[i]['category'],
          taskdescription: maps[i]['taskdescription'],
          createDate: maps[i]['createdate']);
    });
  }

  bool toBoolean(String s) {
    return s != '0' && s != 'false' && s != '';
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
        dbHelper.deleteByTaskDescription(taskdescription);
        Navigator.pop(context);
      },
    );
    // set up the AlertDialog
    AlertDialog alert = AlertDialog(
      title: const Text("Yo! What are you doing?!"),
      content: const Text("Are you sure you want to delete this task?"),
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

  showAddDialog() {
    // set up the buttons
    taskDescriptionText.clear();
    Widget cancelButton = TextButton(
      child: const Text("Cancel"),
      onPressed: () => {Navigator.pop(context)},
    );
    Widget continueButton = TextButton(
      child: const Text("Add Task"),
      onPressed: () {
        setState(() {});
        insertTaskAndTaskLog(taskDescriptionText.text);
        taskDescriptionText.clear();
        Navigator.pop(context);
      },
    );
    Widget taskDescriptionField = TextField(
      controller: taskDescriptionText,
      textAlign: TextAlign.left,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        hintText: 'Enter Your Task Here.',
        hintStyle: TextStyle(color: Colors.grey),
      ),
    );

    // set up the AlertDialog
    AlertDialog alert = AlertDialog(
      title: const Text("Add A Task..."),
      content: const Text("Enter A Description For Your Task Below."),
      actions: [
        taskDescriptionField,
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


  void insertTaskAndTaskLog(String desc) async {
    final intl.DateFormat formatter = intl.DateFormat('yyyy-MM-dd');

    // row to insert
    Map<String, dynamic> taskRow = {
      DatabaseHelper.columnCategory: category,
      DatabaseHelper.columnTaskDescription: desc,
      DatabaseHelper.columnCreateDate:
          formatter.format(DateTime.now()).toString()
    };
    await dbHelper.insertTask(taskRow);

    // row to insert
    Map<String, dynamic> taskLogRow = {
      DatabaseHelper.columnTLCategory: category,
      DatabaseHelper.columnTLTaskDescription: desc,
      DatabaseHelper.columnTLChecked: 'false',
      DatabaseHelper.columnTLTaskDate:
          formatter.format(DateTime.now()).toString()
    };
    await dbHelper.insertTaskLog(taskLogRow);
  }

  void navigateToEditTaskDetail(String cat, String desc) async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (context) => EditTaskDetail(cat, desc)));
    setState(() {});
  }
}

class EditTask {
  int id = 0;
  String category = '';
  String taskdescription = '';
  String createDate = '';

  EditTask(
      {required this.id,
      required this.category,
      required this.taskdescription,
      required this.createDate});

  EditTask.fromMap(dynamic obj) {
    id = obj["id"];
    category = obj["category"];
    taskdescription = obj["taskdescription"];
    createDate = obj["createdate"];
  }
}
