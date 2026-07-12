import 'dart:math';
import 'package:flutter/material.dart';
import 'package:life_ops/db.dart';
import 'package:life_ops/navbar.dart';
import 'package:life_ops/theme/app_colors.dart';
import 'package:life_ops/secrets.dart';
import 'package:life_ops/services/ai_guard.dart';
import 'package:dart_openai/dart_openai.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? visionStatement;
  String? newVisionStatement;
  bool isRegenerating = false;
  bool isReviewing = false;
  String? progressAnalysis;
  bool isLoadingAnalysis = false;
  final dbHelper = DatabaseHelper.instance;
  final List<String> backdropImages = [
    'images/morning_1.jpg',
    'images/afternoon_1.jpg',
    'images/evening_1.jpg',
    'images/evening_2.jpg',
  ];
  late String selectedBackdrop;

  @override
  void initState() {
    super.initState();
    selectedBackdrop = backdropImages[Random().nextInt(backdropImages.length)];
    _loadVisionStatement();
    _loadProgressAnalysis();
  }

  Future<void> _loadVisionStatement() async {
    final vision = await dbHelper.getLatestVisionStatement();
    setState(() {
      visionStatement = vision;
    });
  }

  Future<void> _regenerateVisionStatement() async {
    setState(() {
      isRegenerating = true;
      isReviewing = false;
      newVisionStatement = null;
    });
    final categories = await dbHelper.queryCategories();
    final cats = categories
            .map((c) =>
                '"' + AiGuard.sanitizeField(c['cat'] ?? '', maxChars: 60) + '"')
            .join('|') +
        '~~';
    String system =
        "You are a seasoned, wise mindset and life coach with decades of experience helping people transform their lives through the Green Pyramid methodology. You have a laid-back, approachable personality with a subtle sense of humor - you're the kind of coach who can make someone laugh while delivering profound insights. You have mastered the art of delivering profound insights in just a few powerful words. Keep your responses to 100 words or less. Your client provided this data: $cats. The data is ranked in order of importance. Speak with the wisdom of experience - be conversational, supportive, and deliver specific, actionable guidance rather than generic advice. Your words should carry weight and inspire reflection."
        "${AiGuard.untrustedDataNotice}";
    String prompt =
        "Build a vision statement for this person starting with the phrase 'I will become the kind of person that ...' and make it inspiring, concise, and personal.";
    try {
      OpenAI.apiKey = openAIApiKey;
      await AiGuard.instance.acquire();
      OpenAIChatCompletionModel chatCompletion =
          await OpenAI.instance.chat.create(
        model: "gpt-4.1-mini-2025-04-14",
        maxTokens: 350,
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
      ).timeout(const Duration(seconds: 45));
      setState(() {
        newVisionStatement =
            (chatCompletion.choices[0].message.content?.first.text ?? '')
                .trim();
        isReviewing = true;
        isRegenerating = false;
      });
    } catch (e) {
      setState(() {
        newVisionStatement = 'Failed to generate vision statement.';
        isReviewing = true;
        isRegenerating = false;
      });
    }
  }

  Future<void> _replaceVisionStatement() async {
    if (newVisionStatement != null && newVisionStatement!.isNotEmpty) {
      await dbHelper.insertVisionStatement(newVisionStatement!);
      setState(() {
        visionStatement = newVisionStatement;
        isReviewing = false;
        newVisionStatement = null;
      });
    }
  }

  Future<void> _loadProgressAnalysis() async {
    setState(() {
      isLoadingAnalysis = true;
    });
    final taskLogs = await dbHelper.queryTaskLogs(30);
    final List<String> categories = taskLogs
        .map((cat) =>
            '"${AiGuard.sanitizeField(cat['category'] ?? '', maxChars: 60)}"|'
            '"${AiGuard.sanitizeField(cat['taskdescription'] ?? '')}"|'
            '"${AiGuard.sanitizeField(cat['checked'] ?? '', maxChars: 5)}"|'
            '"${AiGuard.sanitizeField(cat['taskdate'] ?? '', maxChars: 10)}"~~')
        .toList();
    String system =
        "You are a seasoned, wise mindset and life coach with decades of experience helping people transform their lives through the Green Pyramid methodology. You have a laid-back, approachable personality with a subtle sense of humor - you're the kind of coach who can make someone laugh while delivering profound insights. You have mastered the art of delivering profound insights in just a few powerful words. Keep your responses to 100 words or less. Your client provided this data: $categories. The third column is true or false, indicating whether or not the client performed the activity on that day. Some days will not have entries. That is ok. Those days were scheduled days off. Speak with the wisdom of experience - be conversational, supportive, and deliver specific, actionable guidance rather than generic advice. Your words should carry weight and inspire reflection."
        "${AiGuard.untrustedDataNotice}";
    String prompt =
        "Review the client's progress for the past 30 days across all categories and tasks. Provide an inspiring, concise analysis that highlights strengths, areas for improvement, and encouragement.";
    try {
      OpenAI.apiKey = openAIApiKey;
      await AiGuard.instance.acquire();
      OpenAIChatCompletionModel chatCompletion =
          await OpenAI.instance.chat.create(
        model: "gpt-4.1-mini-2025-04-14",
        maxTokens: 350,
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
      ).timeout(const Duration(seconds: 45));
      setState(() {
        progressAnalysis =
            (chatCompletion.choices[0].message.content?.first.text ?? '')
                .trim();
        isLoadingAnalysis = false;
      });
    } catch (e) {
      setState(() {
        progressAnalysis = 'Failed to generate progress analysis.';
        isLoadingAnalysis = false;
      });
    }
  }

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
              image: AssetImage(selectedBackdrop),
              fit: BoxFit.cover,
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    Text(
                      'Your Vision Statement',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            blurRadius: 8.0,
                            color: Colors.black,
                            offset: Offset(2.0, 2.0),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    if (visionStatement != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.15),
                          ),
                        ),
                        child: Text(
                          visionStatement!,
                          style: const TextStyle(
                            fontSize: 18,
                            color: AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      const CircularProgressIndicator(),
                    const SizedBox(height: 20),
                    if (!isRegenerating && !isReviewing)
                      ElevatedButton(
                        onPressed: _regenerateVisionStatement,
                        child: const Text('Regenerate Vision Statement'),
                      ),
                    if (isRegenerating)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(),
                      ),
                    if (isReviewing && newVisionStatement != null)
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surface.withOpacity(0.95),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.15),
                              ),
                            ),
                            child: Text(
                              newVisionStatement!,
                              style: const TextStyle(
                                fontSize: 18,
                                color: AppColors.textPrimary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton(
                                onPressed: _replaceVisionStatement,
                                child: const Text('Replace Existing'),
                              ),
                              const SizedBox(width: 16),
                              OutlinedButton(
                                onPressed: () {
                                  setState(() {
                                    isReviewing = false;
                                    newVisionStatement = null;
                                  });
                                },
                                child: const Text('Cancel'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    const SizedBox(height: 40),
                    Text(
                      'Your Progress (Last 30 Days)',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            blurRadius: 8.0,
                            color: Colors.black,
                            offset: Offset(2.0, 2.0),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    if (isLoadingAnalysis)
                      const CircularProgressIndicator()
                    else if (progressAnalysis != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.15),
                          ),
                        ),
                        child: Text(
                          progressAnalysis!,
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
