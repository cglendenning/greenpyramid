import 'package:flutter/material.dart';
import 'package:life_ops/db.dart';
import 'package:intl/intl.dart' as intl;
import 'package:life_ops/dbtools.dart';
import 'package:life_ops/quote.dart';
import 'package:life_ops/navbar.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:life_ops/coach.dart';

class Morning extends StatefulWidget {
  const Morning({
    Key? key,
  }) : super(key: key);

  @override
  _Morning createState() => _Morning();
}

class _Morning extends State<Morning> {
  @override
  void initState() {
    super.initState();
  }

  String taskLogDate = intl.DateFormat('yyyy-MM-dd')
      .format(DateTime.now().subtract(const Duration(days: 1)));

  _Morning();
  FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  final dbHelper = DatabaseHelper.instance;
  final DBTools dbtools = DBTools();
  bool paywalled = false;

  @override
  Widget build(BuildContext context) {
    analytics.logEvent(name: 'morning');
    var quote = Quote().randomQuote();
    return SafeArea(
        child: Scaffold(
            appBar: const NavBar(),
            floatingActionButton: FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => Coach(showAppBar: true)),
                );
              },
              backgroundColor: Colors.white,
              child: SvgPicture.asset(
                'images/svg/bottom_nav/chat.svg',
                height: 26,
                width: 26,
                fit: BoxFit.contain,
                colorFilter:
                    const ColorFilter.mode(Colors.black, BlendMode.srcIn),
                semanticsLabel: 'Chat',
              ),
            ),
            body: Container(
                decoration: BoxDecoration(
                    image: DecorationImage(
                  colorFilter: ColorFilter.mode(
                      Colors.black.withOpacity(0.5), BlendMode.dstATop),
                  image: const AssetImage("images/morning_1.jpg"),
                  fit: BoxFit.cover,
                )),
                child: Center(
                    child: Scrollbar(
                        thickness: 10,
                        radius: const Radius.circular(20),
                        scrollbarOrientation: ScrollbarOrientation.right,
                        child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                      padding: const EdgeInsets.all(10.0),
                                      child: Text(quote)),
                                  const SizedBox(height: 20),
                                  FutureBuilder(
                                      future: Quote()
                                          .getCommentary(quote, 'inspiration'),
                                      builder:
                                          (context, AsyncSnapshot snapshot) {
                                        if (!snapshot.hasData) {
                                          return const Center(
                                              child: Column(children: <Widget>[
                                            Text('Give us about 10 seconds...'),
                                            SizedBox(height: 30),
                                            CircularProgressIndicator()
                                          ]));
                                        } else {
                                          return Container(
                                              child: Scrollbar(
                                                  thickness: 10,
                                                  radius:
                                                      const Radius.circular(20),
                                                  scrollbarOrientation:
                                                      ScrollbarOrientation
                                                          .right,
                                                  child: SingleChildScrollView(
                                                    scrollDirection:
                                                        Axis.vertical,
                                                    child: Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(10.0),
                                                        child: Text(
                                                            snapshot.data)),
                                                  )));
                                        }
                                      }),
                                  FutureBuilder(
                                      future: getUncheckedTasks(),
                                      // convert to a pre-defined var.
                                      builder:
                                          (context, AsyncSnapshot snapshot) {
                                        if (!snapshot.hasData) {
                                          return const Center(
                                              child:
                                                  CircularProgressIndicator());
                                        } else {
                                          // Check if there are any tasks to display
                                          if (snapshot.data.isEmpty) {
                                            return Container(
                                              padding:
                                                  const EdgeInsets.all(20.0),
                                              child: Column(
                                                children: [
                                                  const Icon(
                                                    Icons.task_alt,
                                                    size: 64,
                                                    color: Colors.green,
                                                  ),
                                                  const SizedBox(height: 16),
                                                  const Text(
                                                    'You\'re on fire!',
                                                    style: TextStyle(
                                                      fontSize: 24,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.black,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    'You completed all your tasks for $taskLogDate, or you didn\'t have any tasks scheduled for that day.',
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      color: Colors.black,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                  const SizedBox(height: 16),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            16),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white
                                                          .withOpacity(0.9),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                      border: Border.all(
                                                        color: Colors.black
                                                            .withOpacity(0.2),
                                                      ),
                                                    ),
                                                    child: const Column(
                                                      children: [
                                                        Icon(
                                                          Icons.trending_up,
                                                          color: Colors.green,
                                                          size: 32,
                                                        ),
                                                        SizedBox(height: 8),
                                                        Text(
                                                          'Ready for today?',
                                                          style: TextStyle(
                                                            fontSize: 18,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Colors.black,
                                                          ),
                                                        ),
                                                        SizedBox(height: 4),
                                                        Text(
                                                          'Focus on today\'s priorities and build momentum for success.',
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            color:
                                                                Colors.black87,
                                                          ),
                                                          textAlign:
                                                              TextAlign.center,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }

                                          return Column(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(10.0),
                                                child: Text(
                                                    'Check off the tasks you completed on $taskLogDate:'),
                                              ),
                                              const SizedBox(height: 20),
                                              Container(
                                                  // constrain the scrollview to 1/3 of the height
                                                  // of the screen.
                                                  height: MediaQuery.of(context)
                                                          .size
                                                          .height /
                                                      3,
                                                  child: Scrollbar(
                                                      child: ListView.builder(
                                                          scrollDirection:
                                                              Axis.vertical,
                                                          shrinkWrap: true,
                                                          itemCount: snapshot
                                                              .data.length,
                                                          itemBuilder:
                                                              (BuildContext
                                                                      context,
                                                                  int index) {
                                                            return CheckboxListTile(
                                                                title: Text(
                                                                    '${snapshot.data[index].taskdescription}'),
                                                                subtitle: Text(
                                                                    '${snapshot.data[index].category}'),
                                                                value: toBoolean(
                                                                    snapshot
                                                                        .data[
                                                                            index]
                                                                        .checked),
                                                                onChanged:
                                                                    (bool?
                                                                        value) {
                                                                  setState(() {
                                                                    var v = value
                                                                        .toString();
                                                                    snapshot
                                                                        .data[
                                                                            index]
                                                                        .checked = v;
                                                                    dbHelper.rawUpdate(
                                                                        "update ${dbHelper.getTaskLogTable()} set checked = '${value.toString()}' "
                                                                        "where taskdescription = '${snapshot.data[index].taskdescription}' "
                                                                        " and category = '${snapshot.data[index].category}'"
                                                                        " and taskdate = '${snapshot.data[index].taskdate}'");
                                                                  });
                                                                });
                                                          }))),
                                            ],
                                          );
                                        }
                                      }),
                                  const SizedBox(height: 20),

                                  /*
                                  FutureBuilder(
                                      future: subscribeLink(),
                                      builder: (context,
                                          AsyncSnapshot snapshot) {
                                        if (!snapshot.hasData) {
                                          return const Center(
                                              child: Column(children: <Widget>[
                                                Text(''),
                                              ]));
                                        } else {
                                          return snapshot.data;
                                        }
                                      }),
                                  */

                                  const SizedBox(height: 10),
                                ])))))));
  }

  Future<List<UncheckedTask>> getUncheckedTasks() async {
    final List<Map<String, dynamic>> maps =
        await dbHelper.queryUncheckedTasks(taskLogDate);

    // Convert the List<Map<String, dynamic> into a List<Task>.
    return List.generate(maps.length, (i) {
      return UncheckedTask(
          id: maps[i]['id'],
          category: maps[i]['category'],
          taskdescription: maps[i]['taskdescription'],
          checked: maps[i]['checked'],
          taskdate: maps[i]['taskdate']);
    });
  }

  bool toBoolean(String s) {
    return s != '0' && s != 'false' && s != '';
  }
}

class UncheckedTask {
  int id = 0;
  String category = '';
  String taskdescription = '';
  String checked = '';
  String taskdate = '';

  UncheckedTask(
      {required this.id,
      required this.category,
      required this.taskdescription,
      required this.checked,
      required this.taskdate});

  UncheckedTask.fromMap(dynamic obj) {
    id = obj["id"];
    category = obj["category"];
    taskdescription = obj["taskdescription"];
    checked = obj["checked"];
    taskdate = obj["taskdate"];
  }
}
