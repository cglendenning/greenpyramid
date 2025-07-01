import 'package:flutter/material.dart';
import 'package:life_ops/db.dart';
import 'package:intl/intl.dart' as intl;
import 'package:life_ops/dbtools.dart';
import 'package:life_ops/paywall.dart';
import 'package:life_ops/navbar.dart';
import 'package:life_ops/utils.dart' as utils;
import 'package:firebase_analytics/firebase_analytics.dart';
// import 'package:flutter/gestures.dart';
// import 'package:purchases_flutter/purchases_flutter.dart';
// import 'package:timezone/timezone.dart' as tz;
// import 'package:life_ops/main.dart';



  class Afternoon extends StatefulWidget {
  const Afternoon({
    Key? key,
  }) : super(key: key);

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

                          Container(
                              padding: const EdgeInsets.all(10.0),
                              child: Text(
                                  "Here are the tasks you still need to complete today, $taskLogDate:",
                              )),
                      const SizedBox(height: 20),
                      FutureBuilder(
                          future: getUncheckedTasks(),
                          // convert to a pre-defined var.
                          builder: (context, AsyncSnapshot snapshot) {
                            if (!snapshot.hasData) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            } else {
                              return Container(
                                  // constrain the scrollview to 1/3 of the height
                                  // of the screen.
                                  height:
                                      MediaQuery.of(context).size.height / 5,
                                  child: Scrollbar(
                                      child: ListView.builder(
                                          scrollDirection: Axis.vertical,
                                          shrinkWrap: true,
                                          itemCount: snapshot.data.length,
                                          itemBuilder: (BuildContext context,
                                              int index) {
                                            return CheckboxListTile(
                                                title: Text(
                                                    '${snapshot.data[index].taskdescription}'),
                                                subtitle: Text(
                                                    '${snapshot.data[index].category}'),
                                                value: toBoolean(snapshot
                                                    .data[index].checked),
                                                onChanged: (bool? value) {
                                                  setState(() {
                                                    var v = value.toString();
                                                    snapshot.data[index]
                                                        .checked = v;
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
                                        borderRadius: const BorderRadius.all(Radius.circular(20)),
                                      color: Colors.white.withOpacity(0.8)
                                    ),
                                    padding: const EdgeInsets.all(10.0),
                                    child: Text('${snapshot.data?[0].quotetext}',
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

    utils.Utils().changeSystemColor(Brightness.dark);
    await Navigator.push(
        context, MaterialPageRoute(builder: (context) => Paywall()));
    paywalled = true;
    setState(() {
      utils.Utils().changeSystemColor(Brightness.light);
    });
  }

  /*
  Future<Widget> subscribeLink() async {

    var link;
    CustomerInfo ci = await Purchases.getCustomerInfo();

    var daysRemaining = installDate
        .add(const Duration(days: 7))
        .difference(tz.TZDateTime.now(tz.local))
        .inDays;

    String dayString = 'days remaining';

    if (daysRemaining == 1) {
      dayString = 'day remaining!!';
    }

    // FT: No subscription and free trial days remaining > 0
    if (ci.activeSubscriptions.isEmpty && daysRemaining > 0) {
      link = RichText(
        text: TextSpan(
            text: 'Subscribe. $daysRemaining $dayString',
            style: const TextStyle(
                color: Colors.black,
                decoration: TextDecoration.underline,
                fontSize: 16),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                navigateToPaywall();
                setState(() {});
              }),
      );
      // S: Active subscription found.
    } else if (ci.activeSubscriptions.isNotEmpty) {
      link = const Text('');
      // U: No active subscription found, and daysRemaining is 0 or less.
    } else if (paywalled == false) {
      navigateToPaywall();
    } else {
      Navigator.pop(context);
    }
    return link;
  }
   */


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
