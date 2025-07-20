import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:life_ops/radarchart.dart' as custom_radar;
import 'package:life_ops/db.dart';
import 'package:life_ops/paywall.dart';
import 'package:life_ops/utils.dart' as utils;
import 'package:life_ops/secrets.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kDebugMode;

class Cat {
  int categoryid;
  String cat;
  Cat({required this.categoryid, required this.cat});
}

class VisualizationsScreen extends StatefulWidget {
  const VisualizationsScreen({super.key});

  @override
  State<VisualizationsScreen> createState() => _VisualizationsScreenState();
}

class _VisualizationsScreenState extends State<VisualizationsScreen> {
  final dbHelper = DatabaseHelper.instance;
  late Future<void> _loadDataFuture;
  bool _checkingPaywall = true;
  bool _paywalled = false;
  bool _isSubscribed = false; // Add subscription status

  // Commentary system state
  int _freeCommentsRemaining = 30; // Start with 30 free comments
  Map<String, bool> _commentaryShown = {}; // Track which charts have shown commentary
  Map<String, String> _commentaryText = {}; // Store generated commentary
  Map<String, String> _buttonTexts = {}; // Store button text for each chart
  Map<String, bool> _isLoadingCommentary = {}; // Track loading states

  // Data for charts
  List<int> radarTicks = [20, 40, 60, 80, 100];
  List<String> radarFeatures = List.filled(6, '');
  List<List<List<num>>> radarData = [];

  List<StreakData> streaksData = [];
  List<DailyCompletionData> dailyCompletionData = [];
  Map<String, List<TrendData>> categoryTrendsData = {};
  List<PieData> pieData = [];

  // Button phrases for commentary
  final List<String> _buttonPhrases = [
    "Coach's insights",
    "Get personalized feedback",
    "See analysis",
    "Display commentary",
    "View expert thoughts",
    "Get motivational insights",
    "See trend analysis",
    "Display feedback",
    "Get personalized tips",
    "View coach's notes",
    "See smart insights",
    "Get trend commentary",
    "Display expert analysis",
    "View personalized feedback",
    "See coach's thoughts",
    "Get motivational analysis",
    "Display trend insights",
    "View expert commentary",
    "See personalized tips",
    "Get smart feedback"
  ];

  @override
  void initState() {
    super.initState();
    _checkPaywallAndLoad();
    _assignButtonTexts();
    _initializeCommentaryTracking();
    _loadCommentaryCountdown();
    _checkSubscriptionStatus();
  }

  Future<void> _checkSubscriptionStatus() async {
    try {
      bool subscriptionStatus = await utils.Utils().isUserSubscribed();
      if (mounted) {
        setState(() {
          _isSubscribed = subscriptionStatus;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error checking subscription status: $e');
      }
    }
  }

  void _initializeCommentaryTracking() {
    // Initialize commentary tracking for all charts
    _commentaryShown = {
      'radar': false,
      'streaks': false,
      'daily': false,
      'trends': false,
      'pie': false,
    };
    _isLoadingCommentary = {
      'radar': false,
      'streaks': false,
      'daily': false,
      'trends': false,
      'pie': false,
    };
  }

  Future<void> _loadCommentaryCountdown() async {
    try {
      final countdown = await dbHelper.getCommentaryCountdown();
      setState(() {
        _freeCommentsRemaining = countdown;
      });
    } catch (e) {
      // If no countdown exists, start with 30
      await dbHelper.saveCommentaryCountdown(30);
    }
  }

  Future<void> _saveCommentaryCountdown() async {
    await dbHelper.saveCommentaryCountdown(_freeCommentsRemaining);
  }

  Future<String> _callOpenAI(String prompt) async {
    // Use the API key from secrets.dart
    const String apiKey = openAIApiKey;
    const String apiUrl = 'https://api.openai.com/v1/chat/completions';
    
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {
              'role': 'system',
              'content': 'You are a supportive life coach who provides encouraging, personalized insights about personal development data. Keep responses under 100 words and focus on positive reinforcement and actionable advice.'
            },
            {
              'role': 'user',
              'content': prompt
            }
          ],
          'max_tokens': 150,
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'].trim();
      } else {
        throw Exception('Failed to get commentary: ${response.statusCode}');
      }
    } catch (e) {
      // Return a meaningful error message without decrementing the counter
      return "I'm having trouble analyzing your data right now, but keep up the great work!";
    }
  }

  String _buildPromptForChart(String chartType) {
    switch (chartType) {
      case 'radar':
        return _buildRadarPrompt();
      case 'streaks':
        return _buildStreaksPrompt();
      case 'daily':
        return _buildDailyPrompt();
      case 'trends':
        return _buildTrendsPrompt();
      case 'pie':
        return _buildPiePrompt();
      default:
        return "Analyze this user's progress data and provide encouraging, personalized feedback.";
    }
  }

  String _buildRadarPrompt() {
    if (radarFeatures.isEmpty) return "The user has no category data yet.";
    
    String prompt = "Analyze this life balance radar chart data:\n";
    for (int i = 0; i < radarFeatures.length; i++) {
      if (i < radarData.length && radarData[i].isNotEmpty && radarData[i][0].isNotEmpty) {
        double value = radarData[i][0][i].toDouble();
        prompt += "${radarFeatures[i]}: ${value.round()}%\n";
      }
    }
    prompt += "\nProvide encouraging, personalized feedback about their life balance and suggest one specific improvement area.";
    return prompt;
  }

  String _buildStreaksPrompt() {
    if (streaksData.isEmpty) return "The user has no streak data yet.";
    
    String prompt = "Analyze this longest streaks data:\n";
    for (var data in streaksData) {
      prompt += "${data.category}: ${data.streak.round()} days\n";
    }
    prompt += "\nProvide encouraging feedback about their consistency and habit formation.";
    return prompt;
  }

  String _buildDailyPrompt() {
    if (dailyCompletionData.isEmpty) return "The user has no daily completion data yet.";
    
    String prompt = "Analyze this daily completion rate data:\n";
    for (var data in dailyCompletionData) {
      prompt += "${DateFormat('MMM dd').format(data.date)}: ${data.percentage.round()}%\n";
    }
    prompt += "\nProvide encouraging feedback about their daily consistency and productivity patterns.";
    return prompt;
  }

  String _buildTrendsPrompt() {
    if (categoryTrendsData.isEmpty) return "The user has no trend data yet.";
    
    String prompt = "Analyze this category trends data:\n";
    for (var entry in categoryTrendsData.entries) {
      prompt += "${entry.key}: ";
      for (var data in entry.value) {
        prompt += "${data.percentage.round()}% ";
      }
      prompt += "\n";
    }
    prompt += "\nProvide encouraging feedback about their progress trends and momentum.";
    return prompt;
  }

  String _buildPiePrompt() {
    if (pieData.isEmpty) return "The user has no completion data yet.";
    
    String prompt = "Analyze this task completion overview:\n";
    for (var data in pieData) {
      prompt += "${data.category}: ${data.value.round()} tasks\n";
    }
    prompt += "\nProvide encouraging feedback about their overall task completion effectiveness.";
    return prompt;
  }

  void _assignButtonTexts() {
    // Randomly assign button texts to charts
    List<String> shuffledPhrases = List.from(_buttonPhrases)..shuffle();
    _buttonTexts = {
      'radar': shuffledPhrases[0],
      'streaks': shuffledPhrases[1],
      'daily': shuffledPhrases[2],
      'trends': shuffledPhrases[3],
      'pie': shuffledPhrases[4],
    };
  }

  Future<void> _generateCommentary(String chartType) async {
    // If subscribed, allow unlimited commentary without checking countdown
    if (!_isSubscribed && _freeCommentsRemaining <= 0) {
      // Show paywall only for non-subscribed users
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => Paywall()),
      );
      return;
    }

    // Set loading state
    setState(() {
      _isLoadingCommentary[chartType] = true;
    });

    try {
      // Build prompt for this chart type
      String prompt = _buildPromptForChart(chartType);
      
      // Call OpenAI
      String commentary = await _callOpenAI(prompt);
      
      // Only proceed if we got a valid response (not an error message)
      if (!commentary.contains("I'm having trouble analyzing")) {
        // Update state with commentary
        setState(() {
          _commentaryText[chartType] = commentary;
          _commentaryShown[chartType] = true;
          _isLoadingCommentary[chartType] = false;
          // Only decrement countdown for non-subscribed users
          if (!_isSubscribed) {
            _freeCommentsRemaining--;
          }
        });
        
        // Save countdown to database only for non-subscribed users
        if (!_isSubscribed) {
          await _saveCommentaryCountdown();
        }
      } else {
        // Don't decrement counter on error, just show the error message
        setState(() {
          _commentaryText[chartType] = commentary;
          _commentaryShown[chartType] = true;
          _isLoadingCommentary[chartType] = false;
          // Don't decrement _freeCommentsRemaining
        });
      }
      
    } catch (e) {
      setState(() {
        _isLoadingCommentary[chartType] = false;
        // Don't decrement counter on exception either
      });
    }
  }

  Future<void> _checkPaywallAndLoad() async {
    // Check chat message count and subscription status
    final chatHistory = await dbHelper.getChatHistory();
    final userMessages = chatHistory.where((m) => m['sender'] == 'user').length;
    final isSubscribed = await utils.Utils().isUserSubscribed();
    if (!isSubscribed && userMessages >= 10) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => Paywall()),
        );
      });
      return;
    }
    setState(() {
      _paywalled = false;
      _checkingPaywall = false;
      _loadDataFuture = _loadAllData();
    });
  }

  Future<void> _loadAllData() async {
    await _loadRadarData();
    await _loadStreaksData();
    await _loadDailyCompletionData();
    await _loadCategoryTrendsData();
    await _loadPieData();
  }

  Future<Cat> _getCategory(int categoryid) async {
    try {
      final List<Map<String, dynamic>> maps = await dbHelper.queryCategory(categoryid);
      if (maps.isNotEmpty) {
        return Cat(categoryid: maps[0]['categoryid'], cat: maps[0]['cat']);
      } else {
        // Return a default category if none exists
        return Cat(categoryid: categoryid, cat: 'Category $categoryid');
      }
    } catch (e) {
      // Return a default category if there's an error
      return Cat(categoryid: categoryid, cat: 'Category $categoryid');
    }
  }

  Future<void> _loadRadarData() async {
    List<String> features = [];
    List<int> percentages = [];
    print('[RADAR] Loading radar data...');
    // Load all categories and their percentages
    for (var i = 1; i <= 6; i++) {
      final cat = await _getCategory(i);
      print('[RADAR] Category $i: id=${cat.categoryid}, name=${cat.cat}');
      features.add(cat.cat);
      final pct = await dbHelper.getCompletionPercentage(cat.cat, 7);
      print('[RADAR] Completion percentage for ${cat.cat}: $pct');
      percentages.add(pct < 0 ? 0 : pct.toInt());
    }
    print('[RADAR] Features: $features');
    print('[RADAR] Percentages: $percentages');
    // Create data structure that matches graveyard exactly
    // Each category gets its own data structure with multiple arrays
    List<List<List<num>>> data = [];
    // Category 1: [[cat1Pct, cat1Pct, 0, 0, 0, 0]]
    data.add([
      [percentages[0], percentages[0], 0, 0, 0, 0]
    ]);
    // Category 2: [[0, 0, 0, 0, 0, 0], [0, cat2Pct, cat2Pct, 0, 0, 0]]
    data.add([
      [0, 0, 0, 0, 0, 0],
      [0, percentages[1], percentages[1], 0, 0, 0]
    ]);
    // Category 3: [[0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0], [0, 0, cat3Pct, cat3Pct, 0, 0]]
    data.add([
      [0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0],
      [0, 0, percentages[2], percentages[2], 0, 0]
    ]);
    // Category 4: [[0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0], [0, 0, 0, cat4Pct, cat4Pct, 0]]
    data.add([
      [0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0],
      [0, 0, 0, percentages[3], percentages[3], 0]
    ]);
    // Category 5: [[0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0], [0, 0, 0, 0, cat5Pct, cat5Pct]]
    data.add([
      [0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, percentages[4], percentages[4]]
    ]);
    // Category 6: [[0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0], [cat6Pct, 0, 0, 0, 0, cat6Pct]]
    data.add([
      [0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0],
      [percentages[5], 0, 0, 0, 0, percentages[5]]
    ]);
    print('[RADAR] radarData: $data');
    setState(() {
      radarFeatures = features;
      radarData = data;
    });
  }

  Future<void> _loadStreaksData() async {
    List<StreakData> streaks = [];
    for (var i = 1; i <= 6; i++) {
      final cat = await _getCategory(i);
      final logs = await dbHelper.queryTaskLogs(30);
      
      // Group logs by date and check if any task was completed on each date
      Map<String, bool> dailyCompletion = {};
      for (var log in logs.where((l) => l['category'] == cat.cat)) {
        String date = log['taskdate'];
        if (!dailyCompletion.containsKey(date)) {
          dailyCompletion[date] = false;
        }
        if (log['checked'] == 'true') {
          dailyCompletion[date] = true;
        }
      }
      
      // Calculate longest streak of consecutive days with completed tasks
      int currentStreak = 0;
      int maxStreak = 0;
      List<String> sortedDates = dailyCompletion.keys.toList()..sort();
      
      for (String date in sortedDates) {
        if (dailyCompletion[date] == true) {
          currentStreak++;
          if (currentStreak > maxStreak) {
            maxStreak = currentStreak;
          }
        } else {
          currentStreak = 0;
        }
      }
      
      streaks.add(StreakData(cat.cat, maxStreak.toDouble()));
    }
    setState(() {
      streaksData = streaks;
    });
  }

  Future<void> _loadDailyCompletionData() async {
    List<DailyCompletionData> data = [];
    DateTime today = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      DateTime day = today.subtract(Duration(days: i));
      String dayStr = day.toIso8601String().substring(0, 10);
      final logs = await dbHelper.queryTaskLogs(7);
      int total = 0;
      int completed = 0;
      for (var log in logs.where((l) => l['taskdate'] == dayStr)) {
        total++;
        if (log['checked'] == 'true') completed++;
      }
      double pct = total > 0 ? (completed / total) * 100 : 0;
      data.add(DailyCompletionData(day, pct));
    }
    setState(() {
      dailyCompletionData = data;
    });
  }

  Future<void> _loadCategoryTrendsData() async {
    Map<String, List<TrendData>> trends = {};
    DateTime today = DateTime.now();
    for (var i = 1; i <= 6; i++) {
      final cat = await _getCategory(i);
      List<TrendData> trendPoints = [];
      for (int j = 6; j >= 0; j--) {
        DateTime day = today.subtract(Duration(days: j));
        String dayStr = day.toIso8601String().substring(0, 10);
        final logs = await dbHelper.queryTaskLogs(7);
        int total = 0;
        int completed = 0;
        for (var log in logs.where((l) => l['category'] == cat.cat && l['taskdate'] == dayStr)) {
          total++;
          if (log['checked'] == 'true') completed++;
        }
        double pct = total > 0 ? (completed / total) * 100 : 0;
        trendPoints.add(TrendData(day, pct));
      }
      trends[cat.cat] = trendPoints;
    }
    setState(() {
      categoryTrendsData = trends;
    });
  }

  Future<void> _loadPieData() async {
    final logs = await dbHelper.queryTaskLogs(30);
    int completed = logs.where((l) => l['checked'] == 'true').length;
    int missed = logs.where((l) => l['checked'] != 'true').length;
    int total = completed + missed;
    
    List<PieData> data = [];
    if (total > 0) {
      data.add(PieData('Completed', completed.toDouble(), Colors.green));
      data.add(PieData('Missed', missed.toDouble(), Colors.red));
    }
    setState(() {
      pieData = data;
    });
  }

  Widget _buildChartCard(String title, Widget chart, {Color? gradientStart, Color? gradientEnd, double? chartHeight, String? chartType}) {
    // Special handling for radar chart to ensure title doesn't interfere with category labels
    bool isRadarChart = title == 'Balance Across Categories';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            gradientStart ?? const Color(0xFF667eea),
            gradientEnd ?? const Color(0xFF764ba2),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isRadarChart ? 25 : 20), // Extra padding for radar chart
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: isRadarChart ? 35 : 15), // Extra spacing for radar chart
            SizedBox(height: chartHeight ?? 200, child: chart),
            
            // Commentary section
            if (chartType != null) ...[
              const SizedBox(height: 15),
              
              // Commentary button or loading state
              if (!_commentaryShown[chartType]!) ...[
                Center(
                  child: _isLoadingCommentary[chartType] == true
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              "Analyzing your data...",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ElevatedButton(
                        onPressed: () => _generateCommentary(chartType),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                        child: Text(
                          _buttonTexts[chartType] ?? "Get insights",
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                ),
              ],
              
              // Commentary text
              if (_commentaryShown[chartType] == true) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _commentaryText[chartType] ?? "",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingCountdown() {
    // Don't show countdown for subscribed users
    if (_isSubscribed) {
      return const SizedBox.shrink();
    }
    
    return Positioned(
      top: 120,
      right: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _freeCommentsRemaining > 0 
              ? [const Color(0xFF667eea), const Color(0xFF764ba2)]
              : [Colors.grey.shade400, Colors.grey.shade600],
          ),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _freeCommentsRemaining > 0 ? Icons.psychology : Icons.lock,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              _freeCommentsRemaining > 0 
                ? "$_freeCommentsRemaining free insights left"
                : "Upgrade for unlimited insights",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingPaywall) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_paywalled) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return SafeArea(
      child: Scaffold(
        body: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFf5f7fa),
                    Color(0xFFc3cfe2),
                  ],
                ),
              ),
              child: FutureBuilder(
                future: _loadDataFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF667eea)),
                      ),
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF4CAF50).withValues(alpha: 0.1),
                          const Color(0xFF66BB6A).withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.analytics,
                              color: const Color(0xFF4CAF50),
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            const Flexible(
                              child: Text(
                                'Your Green Pyramid Analysis',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2d3748),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Discover insights into your life balance, consistency patterns, and growth trends. Each chart reveals a different dimension of your personal development journey.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF4a5568),
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                      
                      // Radar Chart - Stack approach like graveyard
                      _buildChartCard(
                        'Balance Across Categories',
                        Stack(
                          children: [
                            // Category 1 overlay - renders only first category label
                            custom_radar.RadarChart(
                              ticks: radarTicks,
                              features: [radarFeatures[0], '', '', '', '', ''],
                              data: radarData[0],
                            ),
                            // Category 2 overlay - renders only second category label
                            custom_radar.RadarChart(
                              ticks: radarTicks,
                              features: ['', radarFeatures[1], '', '', '', ''],
                              data: radarData[1],
                            ),
                            // Category 3 overlay - renders only third category label
                            custom_radar.RadarChart(
                              ticks: radarTicks,
                              features: ['', '', radarFeatures[2], '', '', ''],
                              data: radarData[2],
                            ),
                            // Category 4 overlay - renders only fourth category label
                            custom_radar.RadarChart(
                              ticks: radarTicks,
                              features: ['', '', '', radarFeatures[3], '', ''],
                              data: radarData[3],
                            ),
                            // Category 5 overlay - renders only fifth category label
                            custom_radar.RadarChart(
                              ticks: radarTicks,
                              features: ['', '', '', '', radarFeatures[4], ''],
                              data: radarData[4],
                            ),
                            // Category 6 overlay - renders only sixth category label
                            custom_radar.RadarChart(
                              ticks: radarTicks,
                              features: ['', '', '', '', '', radarFeatures[5]],
                              data: radarData[5],
                            ),
                          ],
                        ),
                        gradientStart: const Color(0xFF667eea),
                        gradientEnd: const Color(0xFF764ba2),
                        chartHeight: 250, // Extra height for radar chart to accommodate labels
                        chartType: 'radar',
                      ),
                      
                      // Streaks Chart
                      _buildChartCard(
                        'Longest Streaks',
                        SfCartesianChart(
                          margin: const EdgeInsets.fromLTRB(10, 10, 10, 80), // Much more bottom margin for full names
                          primaryXAxis: CategoryAxis(
                            majorGridLines: const MajorGridLines(width: 0),
                            labelStyle: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w500,
                            ),
                            labelRotation: 45,
                            labelIntersectAction: AxisLabelIntersectAction.wrap,
                            labelAlignment: LabelAlignment.start,
                          ),
                          primaryYAxis: NumericAxis(
                            majorGridLines: const MajorGridLines(width: 0),
                            labelStyle: const TextStyle(color: Colors.white),
                          ),
                          series: <CartesianSeries>[
                            ColumnSeries<StreakData, String>(
                              dataSource: streaksData,
                              xValueMapper: (StreakData data, _) => data.category,
                              yValueMapper: (StreakData data, _) => data.streak,
                              borderRadius: BorderRadius.circular(8),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withValues(alpha: 0.9),
                                  Colors.white.withValues(alpha: 0.6),
                                ],
                              ),
                            ),
                          ],
                        ),
                        gradientStart: const Color(0xFFf093fb),
                        gradientEnd: const Color(0xFFf5576c),
                        chartHeight: 300, // Increased height to accommodate full names
                        chartType: 'streaks',
                      ),
                      
                      // Daily Completion Chart
                      _buildChartCard(
                        'Daily Completion Rate',
                        SfCartesianChart(
                          primaryXAxis: DateTimeAxis(
                            majorGridLines: const MajorGridLines(width: 0),
                            labelStyle: const TextStyle(color: Colors.white),
                            dateFormat: DateFormat('MMM dd'),
                          ),
                          primaryYAxis: NumericAxis(
                            majorGridLines: const MajorGridLines(width: 0),
                            labelStyle: const TextStyle(color: Colors.white),
                            numberFormat: NumberFormat.percentPattern(),
                          ),
                          series: <CartesianSeries>[
                            SplineAreaSeries<DailyCompletionData, DateTime>(
                              dataSource: dailyCompletionData,
                              xValueMapper: (DailyCompletionData data, _) => data.date,
                              yValueMapper: (DailyCompletionData data, _) => data.percentage / 100,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.6),
                                  Colors.white.withValues(alpha: 0.1),
                                ],
                              ),
                            ),
                          ],
                        ),
                        gradientStart: const Color(0xFF4facfe),
                        gradientEnd: const Color(0xFF00f2fe),
                        chartType: 'daily',
                      ),
                      
                      // Category Trends Chart
                      _buildChartCard(
                        'Category Trends',
                        SfCartesianChart(
                          primaryXAxis: DateTimeAxis(
                            majorGridLines: const MajorGridLines(width: 0),
                            labelStyle: const TextStyle(color: Colors.white),
                            dateFormat: DateFormat('MMM dd'),
                          ),
                          primaryYAxis: NumericAxis(
                            majorGridLines: const MajorGridLines(width: 0),
                            labelStyle: const TextStyle(color: Colors.white),
                            numberFormat: NumberFormat.percentPattern(),
                          ),
                          series: categoryTrendsData.entries.map((entry) =>
                            SplineSeries<TrendData, DateTime>(
                              dataSource: entry.value,
                              xValueMapper: (TrendData data, _) => data.date,
                              yValueMapper: (TrendData data, _) => data.percentage / 100,
                              name: entry.key,
                              color: _getCategoryColor(categoryTrendsData.keys.toList().indexOf(entry.key)),
                            )
                          ).toList().cast<CartesianSeries>(),
                        ),
                        gradientStart: const Color(0xFF43e97b),
                        gradientEnd: const Color(0xFF38f9d7),
                        chartType: 'trends',
                      ),
                      
                      // Pie Chart
                      _buildChartCard(
                        'Task Completion Overview',
                        SfCircularChart(
                          series: <CircularSeries>[
                            PieSeries<PieData, String>(
                              dataSource: pieData,
                              xValueMapper: (PieData data, _) => data.category,
                              yValueMapper: (PieData data, _) => data.value,
                              pointColorMapper: (PieData data, _) => data.color,
                              dataLabelSettings: const DataLabelSettings(
                                isVisible: true,
                                labelPosition: ChartDataLabelPosition.outside,
                                textStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        gradientStart: const Color(0xFFfa709a),
                        gradientEnd: const Color(0xFFfee140),
                        chartType: 'pie',
                      ),
                    ],
                  );
                },
              ),
            ),
            _buildFloatingCountdown(),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(int index) {
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
    ];
    return colors[index % colors.length];
  }
}

// Data classes for Syncfusion charts
class StreakData {
  final String category;
  final double streak;
  StreakData(this.category, this.streak);
}

class DailyCompletionData {
  final DateTime date;
  final double percentage;
  DailyCompletionData(this.date, this.percentage);
}

class TrendData {
  final DateTime date;
  final double percentage;
  TrendData(this.date, this.percentage);
}

class PieData {
  final String category;
  final double value;
  final Color color;
  PieData(this.category, this.value, this.color);
} 