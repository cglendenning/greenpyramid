import 'package:dart_openai/dart_openai.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:life_ops/services/db.dart';
import 'package:life_ops/widgets/navbar.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:life_ops/screens/setup/setup1.dart';
import 'package:life_ops/screens/setup/setup2.dart';
import 'package:life_ops/screens/setup/setup4.dart';
import 'package:life_ops/services/ai_proxy_client.dart';
import 'package:life_ops/services/ai_guard.dart';
import 'package:life_ops/widgets/progress_bar.dart';

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
        Stack(
          children: [
            ProgressBar(currentStep: 2, totalSteps: 23),
            Positioned(
              left: (MediaQuery.of(context).size.width - 24) * (2 / 23),
              top: 0,
              child: Container(
                width: 12.0,
                height: 6.0,
                decoration: BoxDecoration(
                  color: Color(int.parse("#66CC5D".substring(1, 7), radix: 16) + 0xFF000000),
                  borderRadius: BorderRadius.circular(3.0),
                ),
              ),
            ),
          ],
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
    final clamped = AiGuard.clampMessage(message);
    if (clamped.isEmpty) return;
    setState(() {
      _messages.add(ChatMessage(clamped + suffix, OpenAIChatMessageRole.user));
      _awaitingResponse = true;
    });
    String response;
    try {
      response = await widget.chatApi.completeChat(_messages);
    } on AiBudgetException catch (e) {
      response = e.message;
    } on AiProxyException catch (e) {
      response = e.message;
    }
    setState(() {
      _messages.add(ChatMessage(response, OpenAIChatMessageRole.assistant));
      _awaitingResponse = false;
    });
  }

  Future<String> firstCompletion() async {
    final String cats = categories
            .map((c) => '"' + AiGuard.sanitizeField(c, maxChars: 60) + '"')
            .join('|') +
        '~~';
    String system =
        "You are a seasoned, wise mindset and life coach with decades of experience helping people transform their lives through the Green Pyramid methodology. You have a laid-back, approachable personality with a subtle sense of humor - you're the kind of coach who can make someone laugh while delivering profound insights. You have mastered the art of delivering profound insights in just a few powerful words. Keep your responses to 100 words or less. Your client provided this data: $cats. The data is ranked in order of importance. Speak with the wisdom of experience - be conversational, supportive, and deliver specific, actionable guidance rather than generic advice. Your words should carry weight and inspire reflection.";
    String prompt =
        "Build a vision statement for this person starting with the phrase 'I will become the kind of person that ...' and make it inspiring, concise, and personal.";
    const int timeout = 45;
    String chatResult =
        "Epic fail. please hit the back arrow in the upper left to try building your vision again.";
    try {
      await AiGuard.instance.acquire();
      chatResult = (await AiProxy.instance.chatText(
        model: "gpt-4.1-mini-2025-04-14",
        maxTokens: 350,
        topP: 1,
        temperature: 1,
        timeout: const Duration(seconds: timeout),
        messages: [
          {'role': 'system', 'content': system},
          {'role': 'user', 'content': prompt},
        ],
      ))
          .trim();
      // Store the vision statement in the database
      await dbHelper.insertVisionStatement(chatResult);
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
              onPressed: !awaitingResponse ? () => navigateToSetup4() : null,
              icon: !awaitingResponse
                  ? svgForward
                  : const CircularProgressIndicator(),
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
  static const _model = 'gpt-4.1-mini-2025-04-14';

  ChatApi();

  static String _role(OpenAIChatMessageRole r) {
    if (r == OpenAIChatMessageRole.system) return 'system';
    if (r == OpenAIChatMessageRole.assistant) return 'assistant';
    return 'user';
  }

  Future<String> completeChat(List<ChatMessage> messages) async {
    const int timeout = 60;
    await AiGuard.instance.acquire();
    return await AiProxy.instance.chatText(
      model: _model,
      maxTokens: 350,
      timeout: const Duration(seconds: timeout),
      messages: AiGuard.tailHistory(messages)
          .map((e) => {
                'role': _role(e.msgType),
                'content': AiGuard.clampMessage(e.content, maxChars: 4000),
              })
          .toList(),
    );
  }
}
