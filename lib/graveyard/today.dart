import 'package:dart_openai/dart_openai.dart';
import 'package:flutter/material.dart';
import 'package:life_ops/db.dart';
import 'package:life_ops/paywall.dart';
import 'package:life_ops/quote.dart';
import 'package:life_ops/navbar.dart';
import 'package:life_ops/utils.dart' as utils;
import 'package:life_ops/secrets.dart';
// import 'package:purchases_flutter/purchases_flutter.dart';
// import 'package:timezone/timezone.dart' as tz;
// import 'package:flutter/gestures.dart';
// import 'package:life_ops/main.dart';

class Today extends StatefulWidget {
  final String needType;

  const Today(this.needType);

  @override
  _TodayState createState() => _TodayState(needType);
}

class _TodayState extends State<Today> {
  final String needType;

  @override
  void initState() {
    super.initState();
  }

  _TodayState(this.needType);

  final dbHelper = DatabaseHelper.instance;

  bool paywalled = false;

  var quote = Quote().randomQuote();

  @override
  Widget build(BuildContext context) {
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
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(quote),

                          const SizedBox(height: 10),
                      FutureBuilder(
                          future: Quote().getCommentary(quote, needType),
                          builder: (context, AsyncSnapshot snapshot) {
                            if (!snapshot.hasData) {
                              return const Center(
                                  child: Column(children: <Widget>[
                                Text('Give us about 10 seconds...'),
                                SizedBox(height: 30),
                                CircularProgressIndicator()
                              ]));
                            } else {
                              return Container(
                                  // constrain the scrollview to 1/3 of the height
                                  // of the screen.
                                  height:
                                      MediaQuery.of(context).size.height / 2,
                                  child: Scrollbar(
                                      thickness: 10,
                                      radius: const Radius.circular(20),
                                      scrollbarOrientation:
                                          ScrollbarOrientation.right,
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.vertical,
                                        child: Container(
                                            padding: const EdgeInsets.all(10.0),
                                            child: Text(
                                              snapshot.data,
                                            )),
                                      )));
                            }
                          }),
                      const SizedBox(height: 20),
                      /*
                      FutureBuilder(
                          future: subscribeLink(),
                          builder: (context, AsyncSnapshot snapshot) {
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
    // This will ensure that when someone goes back from the paywall
    // screen, the motivation screen gets popped immediately.
    paywalled = true;
    setState(() {
      utils.Utils().changeSystemColor(Brightness.light);
    });
  }

  /*
  Future<Widget> subscribeLink() async {
    // Purchases.invalidateCustomerInfoCache();

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
                color: Colors.blue,
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

  Future<String> generateCompletion(String responseType) async {
    final List<Map<String, dynamic>> profileMaps =
        await dbHelper.queryForProfile();

    // Convert the List<Map<String, dynamic> into a List<TaskLog>.
    List<CatAndTask> catsAndTasks;
    catsAndTasks = List.generate(profileMaps.length, (i) {
      return CatAndTask(
          category: profileMaps[i]['category'],
          taskdescription: profileMaps[i]['taskdescription']);
    });

    final List<String> csvCatsAndTasks = catsAndTasks
        .map((cat) =>
            '"' + cat.category + '"|' + '"' + cat.taskdescription + '"~~')
        .toList();

    final List<Map<String, dynamic>> maps = await dbHelper.queryTaskLogs(7);

    // Convert the List<Map<String, dynamic> into a List<TaskLog>.
    List<TaskLog> allTaskLogs;
    allTaskLogs = List.generate(maps.length, (i) {
      return TaskLog(
          id: maps[i]['id'],
          category: maps[i]['category'],
          taskdescription: maps[i]['taskdescription'],
          checked: maps[i]['checked'],
          taskdate: maps[i]['taskdate']);
    });

    final List<String> taskLog = allTaskLogs
        .map((cat) =>
            '"' +
            cat.category +
            '"|' +
            '"' +
            cat.taskdescription +
            '"|' +
            '"' +
            cat.checked +
            '"|' +
            '"' +
            cat.taskdate +
            '"~~')
        .toList();

    OpenAI.apiKey = openAIApiKey;

    String system = '';

    String prompt = '';

    String taskLogDescription =
        "The first field is either a role that the client enjoys being in, "
        "or some general topic they value. The second field is a task that "
        "they should perform daily to support that role or value. "
        "The third field is true or false indicating whether or not they "
        "performed the activity on that day. Some days will not have entries. "
        "That is ok. Those days were scheduled days off. The last field is "
        "the date that they performed the task.";

    switch (responseType) {
      case 'inspiration':
        system = "You are Tony Robbins.";
        prompt = "You have been provided this data: $taskLog. "
            "$taskLogDescription "
            "Deliver an inspiring message for the high achiever "
            "who provided the data. Use the trends found in the data to "
            "maximize the relevance of the message. "
            "Do not identify yourself as Tony Robbins. "
            "Keep your response to 100 words or less";
      case 'motivation':
        system = "You are Brandon Turner of biggerpockets fame.";
        prompt = "You have been provided this data: $csvCatsAndTasks. "
            "$taskLogDescription "
            "Deliver a motivational message for the high achiever "
            "who provided the data. "
            "Do not identify yourself or mention biggerpockets. "
            "Keep your response to 100 words or less";
      case 'information':
        system = "You are a wise zen master";
        prompt = "Your student provided this data: $csvCatsAndTasks."
            "$taskLogDescription "
            "Deliver a wise suggestion based on the data provided. "
            "Keep your response to 50 words or less";
      case 'encouragement':
        system = "You are a Tony Blauer, the fear management expert";
        prompt = "Your client provided this data: $csvCatsAndTasks."
            "$taskLogDescription "
            "Deliver a powerful message about overcoming fear based on the "
            "data that they have provided."
            "Keep Response to 100 words or less";
    }

    const int timeout = 45;

    String chatResult = "We tried to provide you with a really "
        "awesome analysis of the habit tracking data you have been recording "
        "but it was an epic fail, probably because the servers are overloaded "
        "right now. You can go back to the home screen and hit the Motivation "
        "link to try again.";

    try {
      OpenAIChatCompletionModel chatCompletion =
          await OpenAI.instance.chat.create(
        model: "gpt-4o",
        messages: [
          OpenAIChatCompletionChoiceMessageModel(
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(system),
            ],
            role: OpenAIChatMessageRole.system,
          ),
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.user,
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(prompt),
            ],
          ),
        ],
      ).timeout(const Duration(seconds: timeout));

      chatResult = chatCompletion.choices[0].message.content?.first.text ?? '';
    } catch (e, s) {
      print(e);
      print(s);
    }

    return chatResult;
  }
}

class CatAndTask {
  String category = '';
  String taskdescription = '';

  CatAndTask({required this.category, required this.taskdescription});

  CatAndTask.fromMap(dynamic obj) {
    category = obj["category"];
    taskdescription = obj["taskdescription"];
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
