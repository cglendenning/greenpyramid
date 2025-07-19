import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:life_ops/radarchart.dart' as custom_radar;
import 'package:life_ops/db.dart';
import 'package:life_ops/navbar.dart';
import 'package:life_ops/secrets.dart';
import 'package:dart_openai/dart_openai.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:life_ops/paywall.dart';
import 'package:life_ops/utils.dart' as utils;

class Cat {
  int categoryid;
  String cat;
  Cat({required this.categoryid, required this.cat});
}

class VisualizationsScreen extends StatefulWidget {
  const VisualizationsScreen({Key? key}) : super(key: key);

  @override
  State<VisualizationsScreen> createState() => _VisualizationsScreenState();
}

class _VisualizationsScreenState extends State<VisualizationsScreen> {
  final dbHelper = DatabaseHelper.instance;
  late Future<void> _loadDataFuture;
  bool _checkingPaywall = true;
  bool _paywalled = false;

  // Data for charts
  List<int> radarTicks = [20, 40, 60, 80, 100];
  List<String> radarFeatures = List.filled(6, '');
  List<List<num>> radarData = [List.filled(6, 0)];

  List<FlSpot> streaksData = [];
  List<BarChartGroupData> dailyCompletionData = [];
  Map<String, List<FlSpot>> categoryTrendsData = {};
  double completedPct = 0;
  double missedPct = 0;

  // Commentary cache
  Map<String, String?> commentary = {
    'radar': null,
    'streaks': null,
    'daily': null,
    'trends': null,
    'pie': null,
  };
  Map<String, bool> loadingCommentary = {
    'radar': false,
    'streaks': false,
    'daily': false,
    'trends': false,
    'pie': false,
  };

  @override
  void initState() {
    super.initState();
    _checkPaywallAndLoad();
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
    // TODO: Load and process all data for charts
    // For now, fill with dummy data and fetch commentary
    await _loadRadarData();
    await _loadStreaksData();
    await _loadDailyCompletionData();
    await _loadCategoryTrendsData();
    await _loadPieData();
    // Fetch commentary (cached)
    _fetchAllCommentary();
  }

  Future<Cat> _getCategory(int categoryid) async {
    final List<Map<String, dynamic>> maps = await dbHelper.queryCategory(categoryid);
    return Cat(categoryid: maps[0]['categoryid'], cat: maps[0]['cat']);
  }

  Future<void> _loadRadarData() async {
    List<String> features = [];
    List<num> pctList = [];
    for (var i = 1; i <= 6; i++) {
      final cat = await _getCategory(i);
      features.add(cat.cat);
      final pct = await dbHelper.getCompletionPercentage(cat.cat, 7);
      pctList.add(pct < 0 ? 0 : pct); // -1 means no data
    }
    setState(() {
      radarFeatures = features;
      radarData = [pctList];
    });
  }

  Future<void> _loadStreaksData() async {
    List<FlSpot> spots = [];
    for (var i = 1; i <= 6; i++) {
      final cat = await _getCategory(i);
      final logs = await dbHelper.queryTaskLogs(30);
      int streak = 0;
      int maxStreak = 0;
      String lastDate = '';
      for (var log in logs.where((l) => l['category'] == cat.cat)) {
        if (log['checked'] == 'true') {
          if (lastDate == '' || log['taskdate'] == lastDate) {
            streak++;
          } else {
            streak = 1;
          }
          if (streak > maxStreak) maxStreak = streak;
        } else {
          streak = 0;
        }
        lastDate = log['taskdate'];
      }
      spots.add(FlSpot((i - 1).toDouble(), maxStreak.toDouble()));
    }
    setState(() {
      streaksData = spots;
    });
  }

  Future<void> _loadDailyCompletionData() async {
    // For the last 7 days, calculate % of completed tasks per day
    List<BarChartGroupData> bars = [];
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
      bars.add(BarChartGroupData(x: 6 - i, barRods: [BarChartRodData(toY: pct, color: Colors.blue)]));
    }
    setState(() {
      dailyCompletionData = bars;
    });
  }

  Future<void> _loadCategoryTrendsData() async {
    Map<String, List<FlSpot>> trends = {};
    DateTime today = DateTime.now();
    for (var i = 1; i <= 6; i++) {
      final cat = await _getCategory(i);
      List<FlSpot> spots = [];
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
        spots.add(FlSpot((6 - j).toDouble(), pct));
      }
      trends[cat.cat] = spots;
    }
    setState(() {
      categoryTrendsData = trends;
    });
  }

  Future<void> _loadPieData() async {
    // Calculate total completed vs missed tasks in last 30 days
    final logs = await dbHelper.queryTaskLogs(30);
    int completed = logs.where((l) => l['checked'] == 'true').length;
    int missed = logs.where((l) => l['checked'] != 'true').length;
    int total = completed + missed;
    setState(() {
      completedPct = total > 0 ? completed / total : 0;
      missedPct = total > 0 ? missed / total : 0;
    });
  }

  Future<void> _fetchAllCommentary() async {
    _fetchCommentary('radar', 'Analyze the user\'s balance across categories as shown in the radar chart.');
    _fetchCommentary('streaks', 'Analyze the user\'s habit streaks.');
    _fetchCommentary('daily', 'Analyze the user\'s daily completion rates.');
    _fetchCommentary('trends', 'Analyze the user\'s category trends.');
    _fetchCommentary('pie', 'Analyze the user\'s missed vs completed tasks.');
  }

  Future<void> _fetchCommentary(String key, String prompt) async {
    setState(() { loadingCommentary[key] = true; });
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'viz_commentary_$key';
    final cacheTimeKey = 'viz_commentary_time_$key';
    final now = DateTime.now().millisecondsSinceEpoch;
    final cacheExpiry = 1000 * 60 * 60 * 6; // 6 hours
    final cached = prefs.getString(cacheKey);
    final cachedTime = prefs.getInt(cacheTimeKey) ?? 0;
    if (cached != null && (now - cachedTime) < cacheExpiry) {
      setState(() {
        commentary[key] = cached;
        loadingCommentary[key] = false;
      });
      return;
    }
    // Fetch from OpenAI
    try {
      OpenAI.apiKey = openAIApiKey;
      final response = await OpenAI.instance.chat.create(
        model: "gpt-4o",
        messages: [
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.system,
            content: [OpenAIChatCompletionChoiceMessageContentItemModel.text(prompt)],
          ),
        ],
      );
      final text = response.choices[0].message.content?.first.text ?? '';
      await prefs.setString(cacheKey, text);
      await prefs.setInt(cacheTimeKey, now);
      setState(() {
        commentary[key] = text;
        loadingCommentary[key] = false;
      });
    } catch (e) {
      setState(() {
        commentary[key] = 'Unable to load commentary.';
        loadingCommentary[key] = false;
      });
    }
  }

  Widget _buildCommentary(String key) {
    if (loadingCommentary[key] == true) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(commentary[key] ?? '', style: const TextStyle(fontStyle: FontStyle.italic)),
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
      // Should never be visible, as we navigate away
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return SafeArea(
      child: Scaffold(
        appBar: const NavBar(),
        body: FutureBuilder(
          future: _loadDataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Your Habit Visualizations', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                // 1. Radar Chart
                const Text('Balance Across Categories', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(
                  height: 220,
                  child: custom_radar.RadarChart(
                    ticks: radarTicks,
                    features: radarFeatures,
                    data: radarData,
                  ),
                ),
                _buildCommentary('radar'),
                const Divider(),
                // 2. Streaks Chart
                const Text('Longest Streaks by Category', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(
                  height: 180,
                  child: LineChart(
                    LineChartData(
                      lineBarsData: [
                        LineChartBarData(
                          spots: streaksData,
                          isCurved: true,
                          color: Colors.green,
                          barWidth: 4,
                          dotData: FlDotData(show: true),
                        ),
                      ],
                      titlesData: FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                    ),
                  ),
                ),
                _buildCommentary('streaks'),
                const Divider(),
                // 3. Daily Completion Bar Chart
                const Text('Daily Completion % (Last 7 Days)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(
                  height: 180,
                  child: BarChart(
                    BarChartData(
                      barGroups: dailyCompletionData,
                      titlesData: FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                    ),
                  ),
                ),
                _buildCommentary('daily'),
                const Divider(),
                // 4. Category Trends
                const Text('Category Trends', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(
                  height: 180,
                  child: LineChart(
                    LineChartData(
                      lineBarsData: categoryTrendsData.entries.map((e) =>
                        LineChartBarData(
                          spots: e.value,
                          isCurved: true,
                          color: Colors.primaries[categoryTrendsData.keys.toList().indexOf(e.key) % Colors.primaries.length],
                          barWidth: 3,
                          dotData: FlDotData(show: false),
                        )
                      ).toList(),
                      titlesData: FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                    ),
                  ),
                ),
                _buildCommentary('trends'),
                const Divider(),
                // 5. Pie Chart
                const Text('Completed vs Missed Tasks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(
                  height: 180,
                  child: PieChart(
                    PieChartData(
                      sections: [
                        PieChartSectionData(
                          value: completedPct,
                          color: Colors.green,
                          title: 'Completed',
                        ),
                        PieChartSectionData(
                          value: missedPct,
                          color: Colors.red,
                          title: 'Missed',
                        ),
                      ],
                      sectionsSpace: 2,
                      centerSpaceRadius: 30,
                    ),
                  ),
                ),
                _buildCommentary('pie'),
              ],
            );
          },
        ),
      ),
    );
  }
} 