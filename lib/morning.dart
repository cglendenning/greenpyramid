import 'package:flutter/material.dart';
import 'package:life_ops/db.dart';
import 'package:intl/intl.dart' as intl;
import 'package:life_ops/dbtools.dart';
import 'package:life_ops/quote.dart';
import 'package:life_ops/paywall.dart';
import 'package:life_ops/navbar.dart';
import 'package:life_ops/utils.dart' as utils;
import 'package:firebase_analytics/firebase_analytics.dart';
// import 'package:purchases_flutter/purchases_flutter.dart';
// import 'package:timezone/timezone.dart' as tz;
// import 'package:life_ops/main.dart';
// import 'package:flutter/gestures.dart';



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
                                      future: Quote().getCommentary(quote, 'inspiration'),
                                      builder:
                                          (context, AsyncSnapshot snapshot) {
                                        if (!snapshot.hasData) {
                                          return const Center(
                                              child: Column(children: <Widget>[
                                                Text(
                                                    'Give us about 10 seconds...'),
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
                                                          snapshot.data
                                                        )),
                                                  )));
                                        }
                                      }),
                                  Container(
                                      padding: const EdgeInsets.all(10.0),
                                      child: Text(
                                        'Check off the tasks you completed on $taskLogDate:'
                                      )),
                                  const SizedBox(height: 20),
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
                                          return Container(
                                            // constrain the scrollview to 1/3 of the height
                                            // of the screen.
                                              height: MediaQuery
                                                  .of(context)
                                                  .size
                                                  .height /
                                                  3,
                                              child: Scrollbar(
                                                  child: ListView.builder(
                                                      scrollDirection:
                                                      Axis.vertical,
                                                      shrinkWrap: true,
                                                      itemCount:
                                                      snapshot.data.length,
                                                      itemBuilder:
                                                          (BuildContext context,
                                                          int index) {
                                                        return CheckboxListTile(
                                                            title: Text(
                                                                '${snapshot
                                                                    .data[index]
                                                                    .taskdescription}'),
                                                            subtitle: Text(
                                                                '${snapshot
                                                                    .data[index]
                                                                    .category}'),
                                                            value: toBoolean(
                                                                snapshot
                                                                    .data[index]
                                                                    .checked),
                                                            onChanged:
                                                                (bool? value) {
                                                              setState(() {
                                                                var v = value
                                                                    .toString();
                                                                snapshot
                                                                    .data[index]
                                                                    .checked =
                                                                    v;
                                                                dbHelper
                                                                    .rawUpdate(
                                                                    "update tasklog set checked = '${value
                                                                        .toString()}' "
                                                                        "where taskdescription = '${snapshot
                                                                        .data[index]
                                                                        .taskdescription}' "
                                                                        " and category = '${snapshot
                                                                        .data[index]
                                                                        .category}'"
                                                                        " and taskdate = '${snapshot
                                                                        .data[index]
                                                                        .taskdate}'");
                                                              });
                                                            });
                                                      })));
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

  void navigateToPaywall() async {

    utils.Utils().changeSystemColor(Brightness.dark);

    await Navigator.push(
        context, MaterialPageRoute(builder: (context) => Paywall()));
    paywalled = true;

    setState(() {});
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
