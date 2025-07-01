import 'package:dart_openai/dart_openai.dart';
import 'package:flutter/material.dart';
import 'package:life_ops/db.dart';
import 'package:life_ops/navbar.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:life_ops/setup/setup1.dart';
import 'package:life_ops/setup/setup2.dart';
import 'package:life_ops/setup/setup4.dart';

// add some additional behind-the-scenes directives to openAI...
String suffix = " Do not answer with a list.";

class Setup3 extends StatefulWidget {
  final List<String> categories;

  Setup3(this.categories);

  final ChatApi chatApi = ChatApi();

  @override
  State<Setup3> createState() => _Setup3State(categories);
}

class _Setup3State extends State<Setup3> {
  final List<String> categories;

  _Setup3State(this.categories);

  @override
  void initState() {
    super.initState();
  }

  final dbHelper = DatabaseHelper.instance;

  bool paywalled = false;
  bool showDropDown = true;
  String cat = '';

  final _messages = <ChatMessage>[
    ChatMessage(
        "We are creating some magic - please give us a sec. Awesome things take "
        "some time...\n\nIn a moment you will have a vision of the person you "
        "want to be; living your best life that is fully aligned "
        "with what you value most. To get where you want to go, you need to "
        "raise your standards.\n\nBalancing your life is key to acting like "
        "the kind of person that you want to become. Day in, day out, the "
        "daily actions that you execute will determine your destiny. Just "
        "another moment...",
        OpenAIChatMessageRole.assistant),
  ];

  var _awaitingResponse = false;
  FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  @override
  Widget build(BuildContext context) {
    analytics.logEvent(name: '${setupVersion}_setup3');
    // activate the spinner if this is the first display of the chat screen.
    if (_messages.length == 1) {
      _awaitingResponse = true;
    }

    return SafeArea(
        child: Scaffold(appBar: const NavBar(), body: chatScreen()));
  }

  Column chatScreen() {
    chatSetup();

    // it's complicated. I need to use reversed because of the
    // "reverse: true" for the ListView.
    var reversedMessages = _messages.reversed.toList();

    return Column(
      children: [
        LinearProgressIndicator(
            value: 2/23,
            color: Color(int.parse("#66CC5D".substring(1, 7), radix: 16) + 0xFF000000)
        ),
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
            ctx: context),
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

  Future<String> firstCompletion() async {
    final String cats = '"' +
        categories[0] +
        '"|"' +
        categories[1] +
        '"|"' +
        categories[2] +
        '"|"' +
        categories[3] +
        '"|"' +
        categories[4] +
        '"|"' +
        categories[5] +
        '"~~';

    OpenAI.apiKey = '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';

    String system = '';

    system = "You are Jocko Willink as a life coach.";

    String prompt = "Your client provided this data: $cats. "
        "The data is ranked in order of importance. "
        "Build a vision statement for this person starting with the phrase "
        "I will become the kind of person that ";

    const int timeout = 45;

    String chatResult = "Epic fail. please hit the back arrow in the upper "
        "left to try building your vision again.";

    try {
      OpenAIChatCompletionModel chatCompletion =
          await OpenAI.instance.chat.create(
        model: "gpt-4o",
        // model: "gpt-3.5-turbo",
        // My understanding of top_p and temperature:
        // https://community.openai.com/t/a-better-explanation-of-top-p/2426/10
        topP: 1,
        temperature: 1,
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
      chatResult = "We built a vision statement for you as you continue your "
              "journey of success...\n\n" +
          (chatCompletion.choices[0].message.content?.first.text ?? '');
    } catch (e, s) {
      print(e);
      print(s);
    }
    setState(() {
      _awaitingResponse = false;
    });
    return chatResult;
  }
}

class MessageComposer extends StatelessWidget {
  const MessageComposer({
    required this.onSubmitted,
    required this.awaitingResponse,
    required this.ctx,
    super.key,
  });

  final void Function(String) onSubmitted;
  final bool awaitingResponse;
  final BuildContext ctx;

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
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 24,
                          width: 24,
                        ),
                        Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Build your best life...'),
                        ),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 24,
                          width: 24,
                        ),
                        Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Thinking really hard...'),
                        ),
                      ],
                    ),
            ),
            IconButton(
              onPressed:
                  !awaitingResponse ? () => navigateToSetup4() : null,
              icon:
                  !awaitingResponse ? svgForward : const CircularProgressIndicator(),
            ),
          ],
        ),
      ),
    );
  }

  void navigateToSetup4() async {
    await Navigator.push(
      ctx,
      MaterialPageRoute(builder: (context) => Setup4(categories)),
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
  // static const _model = 'gpt-3.5-turbo';
  static const _model = 'gpt-4o';

  ChatApi() {
    OpenAI.apiKey = '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';
  }

  Future<String> completeChat(List<ChatMessage> messages) async {
    const int timeout = 60;

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
