import 'package:flutter/material.dart';
import 'package:life_ops/db.dart';
import 'package:intl/intl.dart' as intl;
import 'package:life_ops/dbtools.dart';
import 'package:life_ops/paywall.dart';
import 'package:life_ops/navbar.dart';
import 'package:life_ops/utils.dart' as utils;
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:life_ops/coach.dart';
// import 'package:flutter/gestures.dart';
// import 'package:purchases_flutter/purchases_flutter.dart';
// import 'package:timezone/timezone.dart' as tz;
// import 'package:life_ops/main.dart';

class Afternoon extends StatefulWidget {
  const Afternoon({
    super.key,
  });

  @override
  _Afternoon createState() => _Afternoon();
}

class _Afternoon extends State<Afternoon> {
  var _currentQuote;

  @override
  void initState() {
    super.initState();
    _currentQuote = getQuote();
  }

  String taskLogDate = intl.DateFormat('yyyy-MM-dd').format(DateTime.now());
  bool paywalled = false;

  _Afternoon();
  FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  final dbHelper = DatabaseHelper.instance;
  final DBTools dbtools = DBTools();

  @override
  Widget build(BuildContext context) {
    analytics.logEvent(name: 'afternoon');
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
                  image: const AssetImage("images/afternoon_1.jpg"),
                  fit: BoxFit.cover,
                )),
                child: Center(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                      
                      FutureBuilder(
                          future: getUncheckedTasks(),
                          // convert to a pre-defined var.
                          builder: (context, AsyncSnapshot snapshot) {
                            if (!snapshot.hasData) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            } else {
                              // Check if there are any tasks to display
                              if (snapshot.data.isEmpty) {
                                return Container(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Column(
                                    children: [
                                      const Icon(
                                        Icons.celebration,
                                        size: 64,
                                        color: Colors.orange,
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'Great progress!',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'You\'ve completed all your tasks for $taskLogDate, or you didn\'t have any tasks scheduled for today.',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Colors.black,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 16),
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.9),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color:
                                                Colors.black.withOpacity(0.2),
                                          ),
                                        ),
                                        child: const Column(
                                          children: [
                                            Icon(
                                              Icons.lightbulb,
                                              color: Colors.orange,
                                              size: 32,
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              'Keep the momentum!',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black,
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              'Use this energy to tackle tomorrow\'s challenges with confidence.',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.black87,
                                              ),
                                              textAlign: TextAlign.center,
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
                                    padding: const EdgeInsets.all(10.0),
                                    child: Text(
                                      "Here are the tasks you still need to complete today, $taskLogDate:",
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Container(
                                    // constrain the scrollview to 1/3 of the height
                                    // of the screen.
                                    height:
                                        MediaQuery.of(context).size.height / 5,
                                    child: Scrollbar(
                                      child: ListView.builder(
                                        scrollDirection: Axis.vertical,
                                        shrinkWrap: true,
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
                                                value.toString();
                                                dbHelper.rawUpdate(
                                                    "update ${dbHelper.getTaskLogTable()} set checked = '${value.toString()}' "
                                                    "where taskdescription = '${snapshot.data[index].taskdescription}' "
                                                    " and category = '${snapshot.data[index].category}'"
                                                    " and taskdate = '${snapshot.data[index].taskdate}'");
                                              });
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }
                          }),
                      FutureBuilder(
                          future: _currentQuote,
                          builder:
                              (context, AsyncSnapshot<List<Quote>> snapshot) {
                            List<Widget> children;
                            if (snapshot.data == null) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            } else if (snapshot.hasData) {
                              children = <Widget>[
                                const SizedBox(height: 10),
                                Container(
                                    // color: Colors.white.withOpacity(0.5),
                                    decoration: BoxDecoration(
                                        borderRadius: const BorderRadius.all(
                                            Radius.circular(20)),
                                        color: Colors.white.withOpacity(0.8)),
                                    padding: const EdgeInsets.all(10.0),
                                    child: Text(
                                      '${snapshot.data?[0].quotetext}',
                                    )),
                                const SizedBox(height: 10),
                              ];
                            } else if (snapshot.hasError) {
                              children = <Widget>[
                                const Icon(
                                  Icons.error_outline,
                                  color: Colors.red,
                                  size: 60,
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: Text('Error: ${snapshot.error}'),
                                ),
                              ];
                            } else {
                              children = const <Widget>[
                                SizedBox(
                                  width: 60,
                                  height: 60,
                                  child: CircularProgressIndicator(),
                                ),
                                Padding(
                                  padding: EdgeInsets.only(top: 16),
                                  child: Text('Awaiting result...'),
                                ),
                              ];
                            }
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: children,
                              ),
                            );
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
                    ])))));
  }

  void navigateToPaywall() async {
    // Check if user is already subscribed
    bool isSubscribed = await utils.Utils().isUserSubscribed();
    if (isSubscribed) {
      // Show a message that they're already subscribed
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You already have an active subscription!'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    utils.Utils().changeSystemColor(Brightness.dark);
    await Navigator.push(
        context, MaterialPageRoute(builder: (context) => Paywall()));
    paywalled = true;
    setState(() {
      utils.Utils().changeSystemColor(Brightness.light);
    });
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

  Future<List<Quote>> getQuote() async {
    await dbHelper.updateRandomCurrentQuote();

    final List<Map<String, dynamic>> maps = await dbHelper.queryCurrentQuote();

    // Convert the List<Map<String, dynamic> into a List<Task>.
    return List.generate(maps.length, (i) {
      return Quote(
          quoteid: maps[i]['quoteid'], quotetext: maps[i]['quotetext']);
    });
  }

  bool toBoolean(String s) {
    return s != '0' && s != 'false' && s != '';
  }
}

class Quote {
  int quoteid = 0;
  String quotetext = '';

  Quote({required this.quoteid, required this.quotetext});

  Quote.fromMap(dynamic obj) {
    quoteid = obj["quoteid"];
    quotetext = obj["quotetext"];
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
