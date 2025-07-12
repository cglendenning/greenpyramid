import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:life_ops/db.dart';
import 'package:life_ops/dbtools.dart';
import 'package:life_ops/pyramid.dart';
import 'package:life_ops/setup/setup1.dart';
import 'package:life_ops/main.dart';
import 'package:life_ops/navbar.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class Setup18 extends StatefulWidget {
  final String dd1Value;
  final String dd2Value;
  final String dd3Value;
  final String dd4Value;
  final String dd5Value;
  final String dd6Value;

  const Setup18(this.dd1Value, this.dd2Value, this.dd3Value, this.dd4Value,
      this.dd5Value, this.dd6Value);

  @override
  State<Setup18> createState() =>
      _Setup18State(dd1Value, dd2Value, dd3Value, dd4Value, dd5Value, dd6Value);
}

class _Setup18State extends State<Setup18> {
  String dd1Value;
  String dd2Value;
  String dd3Value;
  String dd4Value;
  String dd5Value;
  String dd6Value;

  @override
  void initState() {
    super.initState();
  }

  _Setup18State(this.dd1Value, this.dd2Value, this.dd3Value, this.dd4Value,
      this.dd5Value, this.dd6Value);
  FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  final DBTools dbtools = DBTools();
  final dbHelper = DatabaseHelper.instance;

  @override
  Widget build(BuildContext context) {
    analytics.logEvent(name: '${setupVersion}_setup18');
    Color green =
    Color(int.parse("#66CC5D".substring(1, 7), radix: 16) + 0xFF000000);

    final lg = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [green, green],
    );

    double pyramidWidth = MediaQuery
        .of(context)
        .size
        .width * 0.87;
    double pyramidHeight = MediaQuery
        .of(context)
        .size
        .width * 0.82;

    var mainTextStyle = const TextStyle(
        fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'SourceSans3');


    return Container(
        color: Colors.black,
        child: SafeArea(
            child: Scaffold(
          appBar: const NavBar(),
          body: Column(
              children: [
                LinearProgressIndicator(
                    value: 23/23,
                    color: Color(int.parse("#66CC5D".substring(1, 7), radix: 16) + 0xFF000000)
                ),

                const SizedBox(height: 10),
                Text(
                  'Setup Complete',
                  style: mainTextStyle,
                ),
                Container(
                    padding: const EdgeInsets.all(10.0),
                    child: const Text(
                        "Setup is now complete! You will receive notifications "
                        "to remind you to track your daily actions. Once "
                        "you click Done, you will still have the ability "
                        "to edit your categories by tapping the Edit icon "
                        "in the bottom navigation bar from the home "
                        "screen. You will also be able to edit your "
                        "tasks by tapping a category on the pyramid "
                        "which will navigate to the edit task section.")),
                const SizedBox(height: 20),
                Stack(children: <Widget>[
                  CustomPaint(
                      size: Size(pyramidWidth, pyramidHeight),
                      painter: DrawCat1(lg, dd1Value, 0)),
                  CustomPaint(
                      size: Size(pyramidWidth, pyramidHeight),
                      painter: DrawCat2(lg, dd2Value, 0)),
                  CustomPaint(
                      size: Size(pyramidWidth, pyramidHeight),
                      painter: DrawCat3(lg, dd3Value, 0)),
                  CustomPaint(
                      size: Size(pyramidWidth, pyramidHeight),
                      painter: DrawCat4(lg, dd4Value, 0)),
                  CustomPaint(
                      size: Size(pyramidWidth, pyramidHeight),
                      painter: DrawCat5(lg, dd5Value, 0)),
                  CustomPaint(
                      size: Size(pyramidWidth, pyramidHeight),
                      painter: DrawCat6(lg, dd6Value, 0)),
                ]),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: () {
                    completeSetup();
                  },
                  child: const Text('Done'),
                ),
              ]),
        )));
  }

  void completeSetup() async {
    // nuke everything first.
    dbHelper.deleteCategory();
    dbHelper.deleteTasks();
    dbHelper.deleteTaskLog();

    // re-set these to default values, in case setup is entered again.
    currentCatId = 1;
    currentTaskId = 0;

    for (var category in cats) {
      // populate the category table...
      await dbHelper.rawInsert("insert into category(categoryid, cat) values "
          "(${category.categoryid}, '${category.cat}') "
          " on conflict (categoryid) do update set cat = '${category.cat}'");
      for (var task in tasks) {
        if (kDebugMode) {
          print ('task.id: ${task.id} task.category: ${task.category} '
            'task.taskdescription: ${task.taskdescription}');
        }
        // HACK: This is a very simple sanitization because chatGPT can not
        // guarantee that it will not produce single quotes in it's output.
        task.taskdescription = task.taskdescription.replaceAll('\'', '');
        // failsafe: only insert tasks for existing categories.
        if (task.category == category.cat) {
          await dbHelper.rawInsert("insert into task ("
              "id, category, taskdescription, sunday, monday, tuesday, "
              "wednesday, thursday, friday, saturday, createdate) "
              "values ( "
              "${task.id},"
              "'${task.category}',"
              "'${task.taskdescription}',"
              "'${task.sunday}',"
              "'${task.monday}',"
              "'${task.tuesday}',"
              "'${task.wednesday}',"
              "'${task.thursday}',"
              "'${task.friday}',"
              "'${task.saturday}',"
              "'${task.createDate}'"
              ") "
              "on conflict (category, taskdescription) do update set "
              "category = '${task.category}',"
              "taskdescription = '${task.taskdescription}',"
              "sunday = '${task.sunday}',"
              "monday = '${task.monday}',"
              "tuesday = '${task.tuesday}',"
              "wednesday = '${task.wednesday}',"
              "thursday = '${task.thursday}',"
              "friday = '${task.friday}',"
              "saturday = '${task.saturday}',"
              "createdate = '${task.createDate}'");
        }
      }
    }

    // clear the Lists, in case "Setup" is run again.
    cats = [];
    tasks = [];

    // popAndPush back to the homescreen, but do not "penalize" users with
    // a red triangle due to the last 7 days being populated with false
    // for every day by default.
    populateGap = false;
    // I was originally using popAndPushNamed() but once I added the NavBar()
    // to setup, I was getting a black leading back arrow on the homescreen
    // that I did not want. pushNamedAndRemoveUntil() removed the leading back
    // arrow after completing setup.
    // Navigator.popAndPushNamed(context, Navigator.defaultRouteName);
    Navigator.pushNamedAndRemoveUntil(context, Navigator.defaultRouteName, (_) => false);
  }

  Future<Cat> getPctComplete(int categoryid) async {
    final cat = await getCategory(categoryid);
    cat.pctComplete = await dbHelper.getCompletionPercentage(cat.cat, 7);
    return cat;
  }

  Future<Cat> getCategory(int categoryid) async {
    final List<Map<String, dynamic>> maps =
        await dbHelper.queryCategory(categoryid);

    return Cat(categoryid: maps[0]['categoryid'], cat: maps[0]['cat']);
  }
}

class Cat {
  int categoryid = 0;
  String cat = '';
  int pctComplete = 0;

  Cat({required this.categoryid, required this.cat});

  Cat.fromMap(dynamic obj) {
    categoryid = obj["categoryid"];
    cat = obj["cat"];
  }
}

