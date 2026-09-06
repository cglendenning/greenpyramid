import 'package:flutter/material.dart';
import 'package:life_ops/services/db.dart';
import 'package:intl/intl.dart' as intl;
import 'package:life_ops/services/dbtools.dart';
import 'package:life_ops/widgets/navbar.dart';
import 'package:life_ops/theme/app_colors.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:life_ops/screens/coach.dart';
import 'package:sqflite/sqflite.dart';

class Evening extends StatefulWidget {
  const Evening({
    Key? key,
  }) : super(key: key);

  @override
  _Evening createState() => _Evening();
}

class _Evening extends State<Evening> {
  // var _currentQuote;
  Future<List<Quote>>? _currentQuote;

  @override
  void initState() {
    super.initState();
    _currentQuote = getQuote();
  }

  String taskLogDate = intl.DateFormat('yyyy-MM-dd').format(DateTime.now());

  _Evening();

  final dbHelper = DatabaseHelper.instance;
  final DBTools dbtools = DBTools();
  FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  @override
  Widget build(BuildContext context) {
    analytics.logEvent(name: 'evening');
    return SafeArea(
        child: Scaffold(
            appBar: const NavBar(),
            floatingActionButton: FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => Coach(showAppBar: true)),
                );
              },
              backgroundColor: AppColors.surfaceHigh,
              child: SvgPicture.asset(
                'images/svg/bottom_nav/chat.svg',
                height: 26,
                width: 26,
                fit: BoxFit.contain,
                colorFilter:
                    const ColorFilter.mode(AppColors.textPrimary, BlendMode.srcIn),
                semanticsLabel: 'Chat',
              ),
            ),
            body: Container(
                decoration: BoxDecoration(
                    image: DecorationImage(
                  colorFilter: ColorFilter.mode(
                      Colors.black.withOpacity(0.5), BlendMode.dstATop),
                  image: const AssetImage("images/evening_1.jpg"),
                  fit: BoxFit.cover,
                )),
                child: Center(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                      // Flexible bounds the summary's SingleChildScrollView to
                      // the space left in this Column: without it the scroll
                      // view sizes to its content and overflows on days with
                      // many completed tasks.
                      Flexible(
                          child: FutureBuilder(
                              future: getCheckedTasks(),
                              builder: (context, AsyncSnapshot snapshot) {
                                if (!snapshot.hasData) {
                                  return const Center(
                                      child: CircularProgressIndicator());
                                } else {
                                  return _buildEveningSummary(snapshot.data);
                                }
                              })),
                      FutureBuilder(
                          future: _currentQuote,
                          builder:
                              (context, AsyncSnapshot<List<Quote>> snapshot) {
                            List<Widget> children;
                            if (snapshot.data == null) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            } else if (snapshot.hasData) {
                              children = <Widget>[
                                Container(
                                    decoration: BoxDecoration(
                                        borderRadius: const BorderRadius.all(
                                            Radius.circular(20)),
                                        color: AppColors.surface.withOpacity(0.85)),
                                    padding: const EdgeInsets.all(10.0),
                                    child: Text(
                                      '${snapshot.data?[0].quotetext}',
                                    )),
                                const SizedBox(height: 10),
                              ];
                            } else if (snapshot.hasError) {
                              children = <Widget>[
                                const Icon(
                                  Icons.error_outline,
                                  color: Colors.red,
                                  size: 60,
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: Text('Error: ${snapshot.error}'),
                                ),
                              ];
                            } else {
                              children = const <Widget>[
                                SizedBox(
                                  width: 60,
                                  height: 60,
                                  child: CircularProgressIndicator(),
                                ),
                                Padding(
                                  padding: EdgeInsets.only(top: 16),
                                  child: Text('Awaiting result...'),
                                ),
                              ];
                            }
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: children,
                              ),
                            );
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

  Widget _buildEveningSummary(List<CheckedTask> checkedTasks) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getAllTasksForToday(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        
        List<Map<String, dynamic>> allTasks = snapshot.data!;
        
        // Check if there were any tasks scheduled for today
        if (allTasks.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                const Icon(
                  Icons.nightlight_round,
                  size: 64,
                  color: Colors.purple,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Rest and reflect',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'You didn\'t have any tasks scheduled for today, or you\'re taking a well-deserved break.',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.15),
                    ),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.self_improvement,
                        color: Colors.purple,
                        size: 32,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Tomorrow is a new day',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Use this time to recharge and prepare for what\'s ahead.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        
        // If there were tasks scheduled but none completed, show a different message
        if (checkedTasks.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                const Icon(
                  Icons.lightbulb,
                  size: 64,
                  color: Colors.orange,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Tomorrow is a new opportunity',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'You had tasks scheduled for today but didn\'t complete any of them. That\'s okay - every day is a fresh start.',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.orange.withOpacity(0.3),
                    ),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.schedule,
                        color: Colors.orange,
                        size: 32,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Plan for tomorrow',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Take a moment to think about what you want to accomplish tomorrow.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // Separate tasks by category
        List<CheckedTask> category1Tasks = checkedTasks.where((task) => task.category == '1').toList();
        List<CheckedTask> category2Tasks = checkedTasks.where((task) => task.category == '2').toList();
        List<CheckedTask> category3Tasks = checkedTasks.where((task) => task.category == '3').toList();
        List<CheckedTask> otherTasks = checkedTasks.where((task) => !['1', '2', '3'].contains(task.category)).toList();

        // Check if all foundational categories (1, 2, 3) are completed
        bool allFoundationalCompleted = category1Tasks.isNotEmpty && category2Tasks.isNotEmpty && category3Tasks.isNotEmpty;

        return FutureBuilder<List<String>>(
          future: _getCategoryDescriptions(),
          builder: (context, categorySnapshot) {
            if (!categorySnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            
            List<String> categoryDescriptions = categorySnapshot.data!;
            String cat1Desc = categoryDescriptions.isNotEmpty ? categoryDescriptions[0] : 'Foundation';
            String cat2Desc = categoryDescriptions.length > 1 ? categoryDescriptions[1] : 'Growth';
            String cat3Desc = categoryDescriptions.length > 2 ? categoryDescriptions[2] : 'Connection';
            
            // Build the missing categories message
            List<String> missingCategories = [];
            if (category1Tasks.isEmpty) missingCategories.add(cat1Desc);
            if (category2Tasks.isEmpty) missingCategories.add(cat2Desc);
            if (category3Tasks.isEmpty) missingCategories.add(cat3Desc);
            
            String missingCategoriesText = '';
            if (missingCategories.isNotEmpty) {
              if (missingCategories.length == 1) {
                missingCategoriesText = missingCategories[0];
              } else if (missingCategories.length == 2) {
                missingCategoriesText = '${missingCategories[0]} and ${missingCategories[1]}';
              } else {
                missingCategoriesText = '${missingCategories[0]}, ${missingCategories[1]}, and ${missingCategories[2]}';
              }
            }

            return SingleChildScrollView(
              child: Column(
                children: [
                  // Header with celebration or encouragement
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(
                          allFoundationalCompleted ? Icons.celebration : Icons.lightbulb,
                          size: 48,
                          color: allFoundationalCompleted ? Colors.amber : Colors.orange,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          allFoundationalCompleted ? '🎉 You Won Today! 🎉' : 'Good work today!',
                          style: TextStyle(
                            fontSize: allFoundationalCompleted ? 28 : 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          allFoundationalCompleted 
                            ? 'You completed all your foundational tasks. This is what winning looks like!'
                            : 'You made progress today. Here\'s what you accomplished:',
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  // Category 1 - Most Important
                  if (category1Tasks.isNotEmpty) _buildCategorySection('Foundation', category1Tasks, Colors.red, Icons.favorite),
                  
                  // Category 2 - Second Most Important
                  if (category2Tasks.isNotEmpty) _buildCategorySection('Growth', category2Tasks, Colors.orange, Icons.trending_up),
                  
                  // Category 3 - Third Most Important
                  if (category3Tasks.isNotEmpty) _buildCategorySection('Connection', category3Tasks, Colors.blue, Icons.people),
                  
                  // Other categories
                  if (otherTasks.isNotEmpty) _buildCategorySection('Wins', otherTasks, Colors.green, Icons.star),

                  // Bottom message based on completion
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: allFoundationalCompleted ? Colors.amber : Colors.orange,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            allFoundationalCompleted ? Icons.star : Icons.schedule,
                            color: allFoundationalCompleted ? Colors.amber : Colors.orange,
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            allFoundationalCompleted 
                              ? 'Tomorrow will be even better!'
                              : 'Plan for tomorrow',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            allFoundationalCompleted
                              ? 'You\'ve built a strong foundation. Keep this momentum going!'
                              : missingCategoriesText.isNotEmpty 
                                ? 'Focus on $missingCategoriesText tomorrow. These are your foundation for success.'
                                : 'Focus on your foundational categories tomorrow. These are your foundation for success.',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCategorySection(String title, List<CheckedTask> tasks, Color color, IconData icon) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const Spacer(),
                Text(
                  '${tasks.length} completed',
                  style: TextStyle(
                    fontSize: 12,
                    color: color.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: color,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        tasks[index].taskdescription,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getAllTasksForToday() async {
    try {
      Database db = await dbHelper.database;
      return await db.query(DatabaseHelper.taskLogTable,
          where: '${DatabaseHelper.columnTLTaskDate} = ?',
          whereArgs: [taskLogDate]);
    } catch (e) {
      return [];
    }
  }

  Future<List<String>> _getCategoryDescriptions() async {
    List<String> descriptions = [];
    try {
      for (int i = 1; i <= 3; i++) {
        final List<Map<String, dynamic>> maps = await dbHelper.queryCategory(i);
        if (maps.isNotEmpty) {
          descriptions.add(maps[0]['cat']);
        }
      }
    } catch (e) {
      // If there's an error, return default descriptions
      descriptions = ['Foundation', 'Growth', 'Connection'];
    }
    return descriptions;
  }

  Future<List<CheckedTask>> getCheckedTasks() async {
    final List<Map<String, dynamic>> maps =
        await dbHelper.queryCheckedTasks(taskLogDate);

    // Convert the List<Map<String, dynamic> into a List<Task>.
    return List.generate(maps.length, (i) {
      return CheckedTask(
          id: maps[i]['id'],
          category: maps[i]['category'],
          taskdescription: maps[i]['taskdescription'],
          checked: maps[i]['checked'],
          taskdate: maps[i]['taskdate']);
    });
  }

  Future<List<Quote>> getQuote() async {
    await dbHelper.updateRandomCurrentQuote();

    final List<Map<String, dynamic>> maps = await dbHelper.queryCurrentQuote();

    // Convert the List<Map<String, dynamic> into a List<Task>.
    return List.generate(maps.length, (i) {
      return Quote(
          quoteid: maps[i]['quoteid'], quotetext: maps[i]['quotetext']);
    });
  }

  bool toBoolean(String s) {
    return s != '0' && s != 'false' && s != '';
  }
}

class Quote {
  int quoteid = 0;
  String quotetext = '';

  Quote({required this.quoteid, required this.quotetext});

  Quote.fromMap(dynamic obj) {
    quoteid = obj["quoteid"];
    quotetext = obj["quotetext"];
  }
}

class CheckedTask {
  int id = 0;
  String category = '';
  String taskdescription = '';
  String checked = '';
  String taskdate = '';

  CheckedTask(
      {required this.id,
      required this.category,
      required this.taskdescription,
      required this.checked,
      required this.taskdate});

  CheckedTask.fromMap(dynamic obj) {
    id = obj["id"];
    category = obj["category"];
    taskdescription = obj["taskdescription"];
    checked = obj["checked"];
    taskdate = obj["taskdate"];
  }
}
