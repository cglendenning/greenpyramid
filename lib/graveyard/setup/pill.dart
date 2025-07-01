import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:life_ops/db.dart';
import 'package:life_ops/dbtools.dart';
import 'package:life_ops/main.dart';
import 'package:life_ops/setup/setup12.dart';


List<BluePillCat> cats = <BluePillCat>[];
List<BluePillTask> tasks = <BluePillTask>[];

class Pill extends StatefulWidget {
  const Pill({super.key});

  @override
  _PillState createState() => _PillState();
}

class _PillState extends State<Pill> {
  @override
  void initState() {
    super.initState();
  }

  _PillState();

  final DBTools dbtools = DBTools();
  final dbHelper = DatabaseHelper.instance;

  final TextEditingController otherText = TextEditingController();

  @override
  Widget build(BuildContext context) {
    double glassesWidth = MediaQuery.of(context).size.width * 0.5;
    double glassesHeight = MediaQuery.of(context).size.width * 0.5;

    const String back = 'images/svg/back.svg';
    final Widget svgBack =
        SvgPicture.asset(back, fit: BoxFit.scaleDown, semanticsLabel: 'back');

    const String forward = 'images/svg/forward.svg';
    final Widget svgForward = SvgPicture.asset(forward,
        fit: BoxFit.scaleDown, semanticsLabel: 'forward');

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                width: glassesWidth,
                height: glassesHeight,
                color: Colors.white,
                alignment: Alignment.center,
                child:
                    Image.asset('images/morpheus.jpg', height: 100, width: 100),
              ),
              Row(children: <Widget>[
                Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Container(
                        width: glassesWidth - 1,
                        height: glassesHeight,
                        color: Colors.white,
                        alignment: Alignment.topRight,
                        child: Image.asset('images/blue.jpg',
                            height: glassesHeight * 0.77,
                            width: glassesWidth * 0.77),
                      ),
                      Container(
                          width: glassesWidth - 1,
                          height: glassesHeight,
                          color: Colors.white,
                          alignment: Alignment.center,
                          child: const Padding(
                            padding: EdgeInsets.all(15),
                            //apply padding to all four sides
                            child: Text(
                                "Just build me something fast, RIGHT NOW."),
                          )),
                      IconButton(
                        icon: svgBack,
                        onPressed: () {
                          setState(() {
                            populateCatsAndTasks();
                            completeBluePill();
                          });
                        },
                      ),
                    ]),
                Container(
                    width: 2,
                    height: glassesHeight * 0.9,
                    color: Colors.grey,
                    alignment: Alignment.center),
                Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Container(
                        width: glassesWidth - 1,
                        height: glassesHeight,
                        color: Colors.white,
                        alignment: Alignment.topLeft,
                        child: Image.asset('images/red.jpg',
                            height: glassesHeight * 0.8,
                            width: glassesWidth * 0.8),
                      ),
                      Container(
                          width: glassesWidth - 1,
                          height: glassesHeight,
                          color: Colors.white,
                          alignment: Alignment.center,
                          child: const Padding(
                            padding: EdgeInsets.all(15),
                            //apply padding to all four sides
                            child: Text("Let’s hop down the rabbit hole…"),
                          )),
                      IconButton(
                        icon: svgForward,
                        onPressed: () {
                          setState(() {
                            navigateToSetup12();
                          });
                        },
                      ),
                    ])
              ]),
            ]),
      ),
    );
  }

  void populateCatsAndTasks() {
    cats.add(BluePillCat(categoryid: 1, cat: 'Physical Health'));
    cats.add(BluePillCat(categoryid: 2, cat: 'Mindset'));
    cats.add(BluePillCat(categoryid: 3, cat: 'Financial Health'));
    cats.add(BluePillCat(categoryid: 4, cat: 'Spouse'));
    cats.add(BluePillCat(categoryid: 5, cat: 'Parent'));
    cats.add(BluePillCat(categoryid: 6, cat: 'Travel'));
  }

  void completeBluePill() async {

    // nuke everything first.
    dbHelper.deleteCategory();
    dbHelper.deleteTasks();
    dbHelper.deleteTaskLog();

    for (var category in cats) {
      // populate the category table...
      await dbHelper.rawInsert("insert into category(categoryid, cat) values "
          "(${category.categoryid}, '${category.cat}') "
          " on conflict (categoryid) do update set cat = '${category.cat}'");
      for (var task in tasks) {
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
              "on conflict (id) do update set "
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
    Navigator.popAndPushNamed(context, Navigator.defaultRouteName);
  }

  void navigateToSetup12() async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (context) => const Setup12())).then((value) {
    });
    setState(() {});
  }
}

class BluePillCat {
  int categoryid = 0;
  String cat = '';

  BluePillCat({required this.categoryid, required this.cat});
}

class BluePillTask {
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
  String createDate = '';

  BluePillTask(
      {required this.id,
      required this.category,
      required this.taskdescription,
      required this.sunday,
      required this.monday,
      required this.tuesday,
      required this.wednesday,
      required this.thursday,
      required this.friday,
      required this.saturday,
      required this.createDate});
}
