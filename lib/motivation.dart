import 'package:life_ops/services/ai_proxy_client.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:life_ops/db.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:life_ops/navbar.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:life_ops/services/ai_guard.dart';

class Motivation extends StatefulWidget {
  const Motivation();

  @override
  _MotivationState createState() => _MotivationState();
}

class _MotivationState extends State<Motivation> {
  // Created once: handing FutureBuilder a fresh generateCompletion() call
  // on every build meant every rebuild (like the ad button's setState)
  // fired another paid OpenAI request.
  late final Future<String> _completionFuture;

  @override
  void initState() {
    super.initState();
    _completionFuture = generateCompletion();
  }

  _MotivationState();
  FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  final dbHelper = DatabaseHelper.instance;

  @override
  Widget build(BuildContext context) {
    analytics.logEvent(name: 'motivation');
    const String back = 'images/svg/back.svg';
    final Widget svgBack =
        SvgPicture.asset(back, fit: BoxFit.scaleDown, semanticsLabel: 'back');

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
                      future: _completionFuture,
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
                                  scrollbarOrientation:
                                      ScrollbarOrientation.right,
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
                    onPressed: () async {
                      setState(() {
                        Navigator.pop(context);
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  const SizedBox(height: 10),
                ]))));
  }

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

    if (allTaskLogs.length > AiGuard.maxTaskLogRows) {
      allTaskLogs =
          allTaskLogs.sublist(allTaskLogs.length - AiGuard.maxTaskLogRows);
    }
    final List<String> categories = allTaskLogs
        .map((cat) =>
            '"${AiGuard.sanitizeField(cat.category, maxChars: 60)}"|'
            '"${AiGuard.sanitizeField(cat.taskdescription)}"|'
            '"${AiGuard.sanitizeField(cat.checked, maxChars: 5)}"|'
            '"${AiGuard.sanitizeField(cat.taskdate, maxChars: 10)}"~~')
        .toList();

    // prompt v1
    String system =
        "You are Jocko Willink as a life coach but do not identify yourself."
        "${AiGuard.untrustedDataNotice}";

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
      await AiGuard.instance.acquire();
      final reply = await AiProxy.instance.chatText(
        model: "gpt-4o-mini",
        maxTokens: 400,
        timeout: const Duration(seconds: timeout),
        messages: [
          {'role': 'system', 'content': system},
          {'role': 'user', 'content': prompt},
        ],
      );

      String postScript =
          " Please take 5 minutes right now to really ponder the question above. "
          "Do not take it lightly, and you will find something new that "
          "will drive you forward!";

      chatResult = reply + postScript;
    } on AiBudgetException catch (e) {
      chatResult = e.message;
    } on AiProxyException catch (e) {
      chatResult = e.message;
    } catch (e, s) {
      if (kDebugMode) {
        print(e);
      }
      if (kDebugMode) {
        print(s);
      }
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
