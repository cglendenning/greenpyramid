import 'package:dart_openai/dart_openai.dart';
import 'package:flutter/material.dart';
import 'package:life_ops/db.dart';
import 'package:life_ops/paywall.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:life_ops/utils.dart' as utils;
import 'package:life_ops/navbar.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:life_ops/secrets.dart';
// import 'package:life_ops/main.dart';
// import 'package:purchases_flutter/purchases_flutter.dart';
// import 'package:timezone/timezone.dart' as tz;
// import 'package:flutter/gestures.dart';
// import 'package:life_ops/main.dart';


class Motivation extends StatefulWidget {
  const Motivation();

  @override
  _MotivationState createState() => _MotivationState();
}

class _MotivationState extends State<Motivation> {

  @override
  void initState() {
    super.initState();
  }

  _MotivationState();
  FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  final dbHelper = DatabaseHelper.instance;

  bool paywalled = false;

  @override
  Widget build(BuildContext context) {
    analytics.logEvent(name: 'motivation');
    const String back = 'images/svg/back.svg';
    final Widget svgBack = SvgPicture.asset(back,
        fit: BoxFit.scaleDown, semanticsLabel: 'back');

    return SafeArea(
        child: Scaffold(
            appBar: const NavBar(),
            body: Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
          const Icon(
            Icons.check_circle_outline,
            color: Colors.green,
            size: 60,
          ),
          const SizedBox(height: 10),
          FutureBuilder(
              future: generateCompletion(),
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
                      height: MediaQuery.of(context).size.height / 2,
                      child: Scrollbar(
                          thickness: 10,
                          radius: const Radius.circular(20),
                          scrollbarOrientation: ScrollbarOrientation.right,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: Container(
                                padding: const EdgeInsets.all(10.0),
                                child: Text(snapshot.data)),
                          )));
                }
              }),
          const SizedBox(height: 30),
                      IconButton(
                        icon: svgBack,
                        onPressed: () {
                          // adInstance.loadAndShowInterstitialAd();
                          setState(() {
                            Navigator.pop(context);
                          });
                        },
                      ),
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
        ]))));
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

  Future<String> generateCompletion() async {
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

    final List<String> categories = allTaskLogs
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

    // prompt v1
    String system =
        "You are Jocko Willink as a life coach but do not identify yourself.";

    // prompt v1
    String prompt = "Your client provided this data: $categories.  The third "
        "column is true or false, indicating whether or not the "
        "client performed the activity on that day. "
        "Some days will not have entries. That is ok. Those days were "
        "scheduled days off. Choose just one category to focus on, and provide "
        "useful commentary about that category. "
        "Keep your response to 150 words or less."
        "Conclude by asking a focusing question."
        "Speak directly to the client. "
        "Do not report or list the data provided by the client. "
        "Do not begin with a greeting or end with a sign off.";

    // debugPrint(prompt, wrapWidth: 1024);

    const int timeout = 60;

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
            role: OpenAIChatMessageRole.system,
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(system),
            ],
          ),
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.user,
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(prompt),
            ],
          ),
        ],
      ).timeout(const Duration(seconds: timeout));

      String postScript =
          " Please take 5 minutes right now to really ponder the question above. "
          "Do not take it lightly, and you will find something new that "
          "will drive you forward!";

      chatResult = (chatCompletion.choices[0].message.content?.first.text ?? '') + postScript;
    } catch (e, s) {
      print(e);
      print(s);
    }

    return chatResult;
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
