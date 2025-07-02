import 'package:dart_openai/dart_openai.dart';
import 'package:flutter/material.dart';
import 'package:life_ops/db.dart';
import 'package:life_ops/paywall.dart';
import 'package:life_ops/utils.dart' as utils;
import 'package:life_ops/navbar.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:life_ops/secrets.dart';
// import 'package:life_ops/main.dart';
// import 'package:purchases_flutter/purchases_flutter.dart';
// import 'package:timezone/timezone.dart' as tz;
// import 'package:flutter/gestures.dart';

// add some additional behind-the-scenes directives to openAI...
String suffix = " Do not answer with a list.";

class Chat extends StatefulWidget {
  final String mood;
  final String cat1;
  final String cat2;
  final String cat3;
  final String cat4;
  final String cat5;
  final String cat6;

  Chat(this.mood, this.cat1, this.cat2, this.cat3, this.cat4, this.cat5,
      this.cat6);

  final ChatApi chatApi = ChatApi();

  @override
  State<Chat> createState() =>
      _ChatState(mood, cat1, cat2, cat3, cat4, cat5, cat6);
}

class _ChatState extends State<Chat> {
  final String mood;
  final String cat1;
  final String cat2;
  final String cat3;
  final String cat4;
  final String cat5;
  final String cat6;

  _ChatState(this.mood, this.cat1, this.cat2, this.cat3, this.cat4, this.cat5,
      this.cat6);

  @override
  void initState() {
    super.initState();
  }

  final dbHelper = DatabaseHelper.instance;

  bool paywalled = false;
  bool showDropDown = true;
  String cat = '';

  final _messages = <ChatMessage>[
    ChatMessage('Give me just a moment...', OpenAIChatMessageRole.assistant),
  ];

  var _awaitingResponse = false;
  FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  @override
  Widget build(BuildContext context) {
    analytics.logEvent(name: 'chat');
    // activate the spinner if this is the first display of the chat screen.
    if (_messages.length == 1) {
      _awaitingResponse = true;
    }

    return SafeArea(
        child: Scaffold(
            appBar: const NavBar(),
            body: showDropDown ? catDropDown() : chatScreen()));
  }

  catDropDown() {
    List<String> catChoices = <String>[
      'Choose an area...',
      cat1,
      cat2,
      cat3,
      cat4,
      cat5,
      cat6,
      'Everything'
    ];

    return Container(
        decoration: BoxDecoration(
            image: DecorationImage(
          colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.5), BlendMode.dstATop),
          image: const AssetImage("images/evening_2.jpg"),
          fit: BoxFit.cover,
        )),
        child: Center(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
              Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                  ),
                  child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                                'The area of my life I am most $mood about is: '),
                            const SizedBox(height: 20), // give it width
                            Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  const SizedBox(width: 10),
                                  // give it width
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12.0),
                                    height: 40.0,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(30.0),
                                      color: Colors.grey[350]!,
                                    ),
                                    child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                      value: catChoices.first,
                                      borderRadius: BorderRadius.circular(30.0),
                                      icon: const Icon(Icons.arrow_drop_down),
                                      elevation: 16,
                                      style:
                                          const TextStyle(color: Colors.black),
                                      onChanged: (String? value) {
                                        // This is called when the user selects an item.
                                        // adInstance.loadAndShowInterstitialAd();
                                        setState(() {
                                          if (value != catChoices.first) {
                                            cat = value!;
                                            showDropDown = !showDropDown;
                                          }
                                        });
                                      },
                                      items: catChoices
                                          .map<DropdownMenuItem<String>>(
                                              (String value) {
                                        return DropdownMenuItem<String>(
                                          value: value,
                                          child: Text(value),
                                        );
                                      }).toList(),
                                    ) // your Dropdown Widget here
                                        ),
                                  )
                                ]),
                            const SizedBox(height: 40),

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
                          ]))),
            ])));
  }

  Column chatScreen() {
    chatSetup();

    // it's complicated. I need to use reversed because of the
    // "reverse: true" for the ListView.
    var reversedMessages = _messages.reversed.toList();

    return Column(
      children: [
        Expanded(
          child: ListView(
            reverse: true,
            children: [
              ...reversedMessages.map(
                (msg) => MessageBubble(
                  content: msg.content,
                  msgType: msg.msgType,
                ),
              ),
            ],
          ),
        ),
        MessageComposer(
          onSubmitted: _onSubmitted,
          awaitingResponse: _awaitingResponse,
        ),
      ],
    );
  }

  Future<void> chatSetup() async {
    // Only call if this the start of the chat session.
    if (_messages.length == 1) {
      String result = await firstCompletion();
      _messages.add(ChatMessage(result, OpenAIChatMessageRole.assistant));
      setState(() {
        _awaitingResponse = false;
      });
    }
  }

  Future<void> _onSubmitted(String message) async {
    setState(() {
      _messages.add(ChatMessage(message + suffix, OpenAIChatMessageRole.user));
      _awaitingResponse = true;
    });
    final response = await widget.chatApi.completeChat(_messages);
    setState(() {
      _messages.add(ChatMessage(response, OpenAIChatMessageRole.assistant));
      _awaitingResponse = false;
    });
  }

  void navigateToPaywall() async {
    utils.Utils().changeSystemColor(Brightness.dark);

    await Navigator.push(
        context, MaterialPageRoute(builder: (context) => Paywall()));
    // This will ensure that when someone goes back from the paywall
    // screen, the chat screen gets popped immediately.
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

  Future<String> firstCompletion() async {
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

    String system = '';

    // prompt v1
    if (cat == 'Everything') {
      system = "You are Jocko Willink and your client's mindset is $mood."
          "You always speak in a conversational style and never "
          "just give a list of things to try.";
    } else {
      system = "You are Jocko Willink and your client's mindset is $mood "
          "about $cat. You always speak in a conversational style and never "
          "just give a list of things to try.";
    }

    String prompt = "Your client provided this data: $categories.  The third "
        "column is true or false, indicating whether or not the client "
        "performed the activity on that day. Some days will not have entries. "
        "That is ok. Those days were scheduled days off. Use the data they "
        "provided combined with what they are feeling in order to encourage, "
        "motivate and inspire them toward the goal of staying consistent with "
        "their daily routine. "
        "Every response needs to be 100 words or less. "
        "When referencing dates, always use the full month and date. Do not "
        "display the year. "
        "Speak directly to the client. "
        "Do not provide lists when responding. Instead always use a conversational style."
        "Do not report or list the data provided by the client. "
        "Do not begin with a greeting or end with a sign off."
        "Conclude by asking a question related to $cat and the client's "
        "mindset of $mood to invite further conversation.";

    const int timeout = 45;

    String chatResult = "We tried to provide you with a really "
        "awesome analysis of the habit tracking data you have been recording "
        "but it was an epic fail, probably because the servers are overloaded "
        "right now. You can go back to the home screen and try again.";

    try {
      OpenAIChatCompletionModel chatCompletion =
          await OpenAI.instance.chat.create(
        model: "gpt-4o",
        messages: [
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.system,
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(system)
            ],
          ),
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.user,
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(prompt)
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

class MessageComposer extends StatelessWidget {
  MessageComposer({
    required this.onSubmitted,
    required this.awaitingResponse,
    super.key,
  });

  final TextEditingController _messageController = TextEditingController();

  final void Function(String) onSubmitted;
  final bool awaitingResponse;

  @override
  Widget build(BuildContext context) {
    const String forward = 'images/svg/forward.svg';
    final Widget svgForward = SvgPicture.asset(forward,
        fit: BoxFit.scaleDown, semanticsLabel: 'forward');

    return Container(
      padding: const EdgeInsets.all(12),
      color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.05),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: !awaitingResponse
                  ? TextField(
                      maxLines: null,
                      controller: _messageController,
                      onSubmitted: onSubmitted,
                      decoration: const InputDecoration(
                        hintText: 'Write your message here...',
                        border: InputBorder.none,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(),
                        ),
                        Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('One moment...'),
                        ),
                      ],
                    ),
            ),
            IconButton(
              onPressed: !awaitingResponse
                  ? () => onSubmitted(_messageController.text)
                  : null,
              icon: svgForward,
            ),
          ],
        ),
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    required this.content,
    required this.msgType,
    super.key,
  });

  final String content;
  final OpenAIChatMessageRole msgType;

  @override
  Widget build(BuildContext context) {
    Color bubbleColor = Colors.blue;
    String bubbleTitle = '';

    switch (msgType) {
      case OpenAIChatMessageRole.user:
        bubbleColor = const Color(0xffC35DCC).withOpacity(0.4);
        bubbleTitle = 'You';
      case OpenAIChatMessageRole.assistant:
        bubbleColor = const Color(0xff66cc5d).withOpacity(0.4);
        bubbleTitle = 'Green Pyramid';
      default:
    }

    var noSuffixContent = content.replaceAll(suffix, '');

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  bubbleTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(noSuffixContent),
          ],
        ),
      ),
    );
  }
}

class ChatMessage {
  ChatMessage(this.content, this.msgType);

  final String content;
  final OpenAIChatMessageRole msgType;
}

class ChatApi {
  static const _model = 'gpt-4.1-2025-04-14';

  ChatApi() {
    OpenAI.apiKey = openAIApiKey;
  }

  Future<String> completeChat(List<ChatMessage> messages) async {
    const int timeout = 45;

    final chatCompletion = await OpenAI.instance.chat
        .create(
          model: _model,
          messages: messages
              .map((e) => OpenAIChatCompletionChoiceMessageModel(
                    role: e.msgType,
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(e.content),
            ],
                  ))
              .toList(),
        )
        .timeout(const Duration(seconds: timeout));
    return chatCompletion.choices.first.message.content?.first.text ?? '';
  }
}
