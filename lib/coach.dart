import 'package:dart_openai/dart_openai.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:life_ops/db.dart';
import 'package:life_ops/paywall.dart';
import 'package:life_ops/utils.dart' as utils;
import 'package:life_ops/navbar.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/rendering.dart';
import 'package:life_ops/secrets.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

// add some additional behind-the-scenes directives to openAI...
String suffix = " Do not answer with a list.";

class Coach extends StatefulWidget {
  final bool showAppBar;
  final String? mood;
  final String? category;
  
  Coach({super.key, this.showAppBar = true, this.mood, this.category});

  final ChatApi chatApi = ChatApi();

  @override
  _CoachState createState() => _CoachState();
}

class _CoachState extends State<Coach> with WidgetsBindingObserver {
  final dbHelper = DatabaseHelper.instance;
  bool paywalled = false;
  String cat = '';
  List<ChatMessage> _chatHistory = [];
  bool _hasLoadedHistory = false;
  late FocusNode _focusNode;
  int freeMessageLimit = 10;
  bool isSubscribed = true; // Start as true to prevent banner flash

  final _messages = <CoachMessage>[
    CoachMessage('Give me just a moment...', OpenAIChatMessageRole.assistant),
  ];

  var _awaitingResponse = false;
  FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  // Track if we've injected a mood/category message for this navigation
  bool _injectedMoodCategory = false;

  @override
  void initState() {
    super.initState();
    print('🚀 [COACH SCREEN] initState() - Triggering initial subscription check');
    _checkSubscriptionStatus();
    WidgetsBinding.instance.addObserver(this);
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
    _loadChatHistory().then((_) async {
      // Always inject a new message if mood and category are provided, but only once per navigation
      if (!_injectedMoodCategory && widget.mood != null && widget.category != null && widget.mood!.isNotEmpty && widget.category!.isNotEmpty) {
        _injectedMoodCategory = true;
        String prompt = "The area of my life I am most ${widget.mood} about is: ${widget.category}.";
        _messages.add(CoachMessage(prompt, OpenAIChatMessageRole.user));
        await _saveMessage(prompt, 'user');
        setState(() {
          _awaitingResponse = true;
        });
        final response = await widget.chatApi.completeChat(_messages);
        _messages.add(CoachMessage(response, OpenAIChatMessageRole.assistant));
        await _saveMessage(response, 'assistant');
        setState(() {
          _awaitingResponse = false;
        });
      } else if (_chatHistory.isEmpty) {
        // Only call chatSetup if there's no existing history and no mood/category injection
        _awaitingResponse = true;
        chatSetup();
      } else {
        _awaitingResponse = false;
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      // Reload chat history and check subscription when screen gains focus
      print('🎯 [COACH SCREEN] Screen gained focus - Triggering subscription check');
      _loadChatHistory();
      _checkSubscriptionStatus();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reload chat history and check subscription when app becomes visible
      print('📱 [COACH SCREEN] App resumed - Triggering subscription check');
      _loadChatHistory();
      _checkSubscriptionStatus();
    }
  }

  Future<void> _loadChatHistory() async {
    try {
      final chatHistory = await dbHelper.getChatHistory();
      _chatHistory = chatHistory.map((map) => ChatMessage.fromMap(map)).toList();
      
      // Convert ChatMessage to CoachMessage for UI display
      _messages.clear();
      for (var chatMsg in _chatHistory) {
        OpenAIChatMessageRole role = chatMsg.role == 'user' 
            ? OpenAIChatMessageRole.user 
            : OpenAIChatMessageRole.assistant;
        _messages.add(CoachMessage(chatMsg.content, role));
      }
      
      // Only add initial message if there's no history AND no existing messages
      if (_messages.isEmpty && !_hasLoadedHistory) {
        _messages.add(CoachMessage('Give me just a moment...', OpenAIChatMessageRole.assistant));
      }
      
      _hasLoadedHistory = true;
      setState(() {});
    } catch (e) {
      print('Error loading chat history: $e');
      // Only add initial message on error if we haven't loaded history yet
      if (!_hasLoadedHistory) {
        _messages.clear();
        _messages.add(CoachMessage('Give me just a moment...', OpenAIChatMessageRole.assistant));
        _hasLoadedHistory = true;
        setState(() {});
      }
    }
  }

  Future<void> _saveMessage(String content, String role) async {
    try {
      // Check if we have 200 or more messages, delete the oldest one first
      final currentHistory = await dbHelper.getChatHistory();
      if (currentHistory.length >= 200) {
        // Delete the oldest message (first in the list since it's ordered by timestamp ASC)
        if (currentHistory.isNotEmpty) {
          final oldestMessage = currentHistory.first;
          await dbHelper.deleteOldestChatMessage(oldestMessage['id']);
        }
      }
      
      // Now insert the new message
      await dbHelper.insertChatMessage(role, content);
    } catch (e) {
      print('Error saving message: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    analytics.logEvent(name: 'chat');
    print('🏗️ [COACH SCREEN] Building UI - isSubscribed: $isSubscribed');

    return SafeArea(
      child: Focus(
        focusNode: _focusNode,
        child: Scaffold(
          appBar: widget.showAppBar ? const NavBar() : null,
          body: Stack(
            children: [
              chatScreen(),
              if (!isSubscribed)
                Positioned(
                  left: -30,
                  top: 20,
                  child: Transform.rotate(
                    angle: -0.785398, // -45 degrees in radians
                    child: Container(
                      width: 140,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      color: Colors.redAccent,
                      child: const Center(
                        child: Text(
                          'FREE TIER',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Column chatScreen() {
    // Remove the automatic chatSetup call - it should only happen in initState

    // it's complicated. I need to use reversed because of the
    // "reverse: true" for the ListView.
    var reversedMessages = _messages.reversed.toList();

    return Column(
      children: [
        Expanded(
          child: Scrollbar(
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
        ),
        MessageComposer(
          onSubmitted: (msg) {
            _onSubmitted(msg);
          },
          awaitingResponse: _awaitingResponse,
        ),
      ],
    );
  }

  Future<void> chatSetup() async {
    // Only call if there's no existing chat history
    if (_chatHistory.isEmpty) {
      // Check if categories and tasks have been set up
      final categoriesList = await dbHelper.queryCategories();
      final tasksList = await dbHelper.queryAllTasks();
      if (categoriesList.isNotEmpty && tasksList.isEmpty) {
        _messages.add(CoachMessage(
          "I see you've set up your categories, but you haven't added any habits to track yet. Once you add and start tracking habits, I can give you much more personalized and helpful coaching! But let's get a conversation started anyway—what's on your mind today?",
          OpenAIChatMessageRole.assistant,
        ));
        await _saveMessage(
          "I see you've set up your categories, but you haven't added any habits to track yet. Once you add and start tracking habits, I can give you much more personalized and helpful coaching! But let's get a conversation started anyway—what's on your mind today?",
          'assistant',
        );
        setState(() {
          _awaitingResponse = false;
        });
        return;
      }
      // If mood and category are provided, use them to build the initial prompt
      if (widget.mood != null && widget.category != null && widget.mood!.isNotEmpty && widget.category!.isNotEmpty) {
        String prompt = "The area of my life I am most ${widget.mood} about is: ${widget.category}.";
        _messages.add(CoachMessage(prompt, OpenAIChatMessageRole.user));
        await _saveMessage(prompt, 'user');
      }
      String result = await firstCompletion();
      _messages.add(CoachMessage(result, OpenAIChatMessageRole.assistant));
      await _saveMessage(result, 'assistant');
      setState(() {
        _awaitingResponse = false;
      });
    }
  }

  Future<void> _onSubmitted(String message) async {
    // Check subscription status before processing message
    print('💬 [COACH SCREEN] Message submitted - Triggering subscription check');
    await _checkSubscriptionStatus();
    
    // Count user messages (excluding assistant messages)
    int userMessageCount = _messages.where((m) => m.msgType == OpenAIChatMessageRole.user).length;
    if (!isSubscribed && userMessageCount >= freeMessageLimit) {
      // Show paywall before allowing the 11th message
      await navigateToPaywall();
      return;
    }
    setState(() {
      _messages.add(CoachMessage(message + suffix, OpenAIChatMessageRole.user));
      _awaitingResponse = true;
    });
    await _saveMessage(message + suffix, 'user');
    await _sendAssistantResponse();
  }

  Future<void> navigateToPaywall() async {
    utils.Utils().changeSystemColor(Brightness.dark);
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => Paywall()),
    );
    // Check subscription status after returning from paywall
    print('💰 [COACH SCREEN] Returning from paywall - Triggering subscription check');
    await _checkSubscriptionStatus();
    setState(() {
      utils.Utils().changeSystemColor(Brightness.light);
    });
  }

  Future<void> _sendAssistantResponse() async {
    // Get current habit data to include in context
    final List<Map<String, dynamic>> maps = await dbHelper.queryTaskLogs(60);
    List<TaskLog> allTaskLogs = List.generate(maps.length, (i) {
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

    // Create messages with categories data always included
    List<CoachMessage> messagesWithContext = [
      CoachMessage(
        "You are a seasoned, wise mindset and life coach with decades of experience helping people transform their lives through the Green Pyramid methodology. You have a laid-back, approachable personality with a subtle sense of humor - you're the kind of coach who can make someone laugh while delivering profound insights. You have mastered the art of delivering profound insights in just a few powerful words. Keep your responses to 100 words or less. Your client provided this data: $categories. The third column is true or false, indicating whether or not the client performed the activity on that day. Some days will not have entries. That is ok. Those days were scheduled days off. Speak with the wisdom of experience - be conversational, supportive, and deliver specific, actionable guidance rather than generic advice. Your words should carry weight and inspire reflection.",
        OpenAIChatMessageRole.system
      ),
      ..._messages
    ];
    
    final response = await widget.chatApi.completeChat(messagesWithContext);
    setState(() {
      _messages.add(CoachMessage(response, OpenAIChatMessageRole.assistant));
      _awaitingResponse = false;
    });
    
    // Save assistant response to database
    await _saveMessage(response, 'assistant');
  }

  Future<String> firstCompletion() async {
    final List<Map<String, dynamic>> maps = await dbHelper.queryTaskLogs(60);

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

    String system =
        "You are an empathetic life coach with a deep background in health, "
        "mindset and finances. You help entrepreneurs to fix problems in these "
        "domains in their lives. You are well versed in the work of Dr. David "
        "Burns and TEAM-CBT, Dan Sullivan, Simon Sinek, James Clear, Greg "
        "Glassman and other deep thinkers in the areas of mindset, "
        "self-improvement, fitness and entrepreneurship. You have an informal "
        "style and are genuinely inquisitive about your client's needs.";

    String prompt = "Your client provided this data: $categories.  The third "
        "column is true or false, indicating whether or not the client "
        "performed the activity on that day. Some days will not have entries. "
        "That is ok. Those days were scheduled days off.";

    const int timeout = 25;

    String chatResult = "We tried to provide you with a really "
        "awesome analysis of the habit tracking data you have been recording "
        "but it was an epic fail, probably because the servers are overloaded "
        "right now. You can go back to the home screen and try again.";

    try {
      OpenAIChatCompletionModel chatCompletion =
          await OpenAI.instance.chat.create(
        model: "gpt-4.1-2025-04-14",
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

  Future<void> _checkSubscriptionStatus() async {
    print('🔄 [SUBSCRIPTION CHECK] Starting RevenueCat verification...');
    try {
      CustomerInfo ci = await Purchases.getCustomerInfo();
      
      // Log detailed subscription information
      print('📱 [SUBSCRIPTION CHECK] Customer ID: ${ci.originalAppUserId}');
      print('📱 [SUBSCRIPTION CHECK] Active Subscriptions: ${ci.activeSubscriptions}');
      print('📱 [SUBSCRIPTION CHECK] All Purchased Product IDs: ${ci.allPurchasedProductIdentifiers}');
      print('📱 [SUBSCRIPTION CHECK] Latest Expiration Date: ${ci.latestExpirationDate}');
      
      bool newSubscriptionStatus = ci.activeSubscriptions.isNotEmpty;
      print('📱 [SUBSCRIPTION CHECK] Subscription Status: ${newSubscriptionStatus ? "SUBSCRIBED" : "NOT SUBSCRIBED"}');
      
      if (mounted) {
        setState(() {
          isSubscribed = newSubscriptionStatus;
        });
        print('📱 [SUBSCRIPTION CHECK] UI updated - isSubscribed: $isSubscribed');
      } else {
        print('📱 [SUBSCRIPTION CHECK] Widget not mounted, skipping UI update');
      }
    } catch (e) {
      print('❌ [SUBSCRIPTION CHECK] Error checking subscription: $e');
      // If error, default to not subscribed
      if (mounted) {
        setState(() {
          isSubscribed = false;
        });
        print('📱 [SUBSCRIPTION CHECK] Error fallback - isSubscribed set to false');
      }
    }
    print('🔄 [SUBSCRIPTION CHECK] Verification complete');
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

class MessageComposer extends StatefulWidget {
  MessageComposer({
    required this.onSubmitted,
    required this.awaitingResponse,
    super.key,
  });

  final void Function(String) onSubmitted;
  final bool awaitingResponse;

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<MessageComposer> {
  final TextEditingController _messageController = TextEditingController();
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _messageController.dispose();
    super.dispose();
  }

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
              child: !widget.awaitingResponse
                  ? Container(
                      constraints: const BoxConstraints(
                        maxHeight: 200, // Limit maximum height of text field
                      ),
                      child: TextField(
                        focusNode: _focusNode,
                        maxLines: null,
                        controller: _messageController,
                        onSubmitted: widget.onSubmitted,
                        decoration: const InputDecoration(
                          hintText: 'Write your message here...',
                          border: InputBorder.none,
                        ),
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
              onPressed: !widget.awaitingResponse
                  ? () => widget.onSubmitted(_messageController.text)
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

    return GestureDetector(
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: noSuffixContent));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message copied to clipboard'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.all(8),
        constraints: const BoxConstraints(
          maxWidth: 300, // Limit maximum width to prevent overflow
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
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
              Text(
                noSuffixContent,
                softWrap: true,
                overflow: msgType == OpenAIChatMessageRole.assistant 
                    ? TextOverflow.visible 
                    : TextOverflow.ellipsis,
                maxLines: msgType == OpenAIChatMessageRole.assistant 
                    ? null 
                    : 15, // Allow assistant messages to expand, limit user messages
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CoachMessage {
  CoachMessage(this.content, this.msgType);

  final String content;
  final OpenAIChatMessageRole msgType;
}

class ChatApi {
  static const _model = 'gpt-4.1-2025-04-14';

  ChatApi() {
    OpenAI.apiKey = openAIApiKey;
  }

  Future<String> completeChat(List<CoachMessage> messages) async {
    const int timeout = 25;

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
