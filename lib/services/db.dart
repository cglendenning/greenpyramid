import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart' as intl;
import 'package:flutter/material.dart';

class DatabaseHelper {
  static const _databaseName = "LifeOps.db";
  static const _databaseVersion = 6; // Bumped from 5 to 6 for demo tables

  // DEMO MODE FLAG
  static final ValueNotifier<bool> demoModeNotifier = ValueNotifier(false);
  static bool get isDemoMode => demoModeNotifier.value;
  static set isDemoMode(bool value) => demoModeNotifier.value = value;
  static void toggleDemoMode() => demoModeNotifier.value = !demoModeNotifier.value;

  // Real tables
  static const taskTable = 'task';
  static const columnId = 'id';
  static const columnCategory = 'category';
  static const columnTaskDescription = 'taskdescription';
  static const columnSunday = 'sunday';
  static const columnMonday = 'monday';
  static const columnTuesday = 'tuesday';
  static const columnWednesday = 'wednesday';
  static const columnThursday = 'thursday';
  static const columnFriday = 'friday';
  static const columnSaturday = 'saturday';
  static const columnCreateDate = 'createdate';

  // The tasklog table. This stores the history of each task's
  // completion for each value.
  static const taskLogTable = 'tasklog';
  static const columnTLId = 'id';
  static const columnTLCategory = 'category';
  static const columnTLTaskDescription = 'taskdescription';
  static const columnTLChecked = 'checked';
  static const columnTLTaskDate = 'taskdate';

  // The quote table. This stores quotes displayed on the notification
  // response screen.
  static const quoteTable = 'quote';
  static const columnQuoteId = 'quoteid';
  static const columnQuoteText = 'quotetext';
  static const columnCurrent = 'current';

  // The category table. This stores the categories that tasks belong to.
  static const categoryTable = 'category';
  static const columnCategoryId = 'categoryid';
  static const columnCat = 'cat';

  // The chat_messages table. This stores full chat history with timestamps.
  static const chatTable = 'chat_messages';
  static const chatColumnId = 'id';
  static const chatColumnSender = 'sender';
  static const chatColumnContent = 'content';
  static const chatColumnTimestamp = 'timestamp';

  // The vision_statement table. This stores the user's vision statement.
  static const visionStatementTable = 'vision_statement';
  static const columnVisionId = 'id';
  static const columnVisionText = 'vision_text';
  static const columnVisionCreated = 'created';

  // The commentary_countdown table. This stores the remaining free commentary count.
  static const commentaryCountdownTable = 'commentary_countdown';
  static const columnCountdownId = 'id';
  static const columnCountdownValue = 'countdown_value';

  // Demo tables
  static const demoTaskTable = 'demo_task';
  static const demoTaskLogTable = 'demo_tasklog';
  static const demoCategoryTable = 'demo_category';
  static const demoQuoteTable = 'demo_quote';
  static const demoChatTable = 'demo_chat_messages';

  // Helper to get the correct table name
  String getTaskTable() => isDemoMode ? demoTaskTable : taskTable;
  String getTaskLogTable() => isDemoMode ? demoTaskLogTable : taskLogTable;
  String getCategoryTable() => isDemoMode ? demoCategoryTable : categoryTable;
  String getQuoteTable() => isDemoMode ? demoQuoteTable : quoteTable;
  String getChatTable() => isDemoMode ? demoChatTable : chatTable;

  // make this a singleton class
  DatabaseHelper._privateConstructor();

  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  // only have a single app-wide reference to the database
  late Database _database;

  Future<Database> get database async {
    // lazily instantiate the db the first time it is accessed
    _database = await _initDatabase();
    return _database;
  }

  // this opens the database (and creates it if it doesn't exist)
  _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, _databaseName);
    return await openDatabase(path,
        version: _databaseVersion, onCreate: _onCreate, onUpgrade: _onUpgrade);
  }

  Future _onCreate(Database db, int version) async {
    // store the current version of a task
    try {
      await db.execute('''
            CREATE TABLE $taskTable (
              $columnId INTEGER PRIMARY KEY,
              $columnCategory TEXT NOT NULL,
              $columnTaskDescription TEXT NOT NULL,
              $columnSunday TEXT NOT NULL DEFAULT 'true',
              $columnMonday TEXT NOT NULL DEFAULT 'true',
              $columnTuesday TEXT NOT NULL DEFAULT 'true',
              $columnWednesday TEXT NOT NULL DEFAULT 'true',
              $columnThursday TEXT NOT NULL DEFAULT 'true',
              $columnFriday TEXT NOT NULL DEFAULT 'true',
              $columnSaturday TEXT NOT NULL DEFAULT 'true',
              $columnCreateDate TEXT NOT NULL,
              UNIQUE($columnCategory, $columnTaskDescription)
            )
            ''');
    } catch (e, s) {
      if (kDebugMode) {
        print(e);
      }
      if (kDebugMode) {
        print(s);
      }
    }

    // store the history of task executions
    try {
      await db.execute('''
            CREATE TABLE $taskLogTable (
              $columnTLId INTEGER PRIMARY KEY,
              $columnTLCategory TEXT NOT NULL,
              $columnTLTaskDescription TEXT NOT NULL,
              $columnTLChecked TEXT NOT NULL,
              $columnTLTaskDate TEXT NOT NULL,
              UNIQUE($columnTLCategory, $columnTLTaskDescription, $columnTLTaskDate)
            )
            ''');
    } catch (e, s) {
      if (kDebugMode) {
        print(e);
      }
      if (kDebugMode) {
        print(s);
      }
    }

    try {
      await db.execute('''
            CREATE TABLE $categoryTable (
              $columnCategoryId INTEGER PRIMARY KEY,
              $columnCat TEXT NOT NULL,
              UNIQUE($columnCat) ON CONFLICT IGNORE
            )
            ''');
    } catch (e, s) {
      if (kDebugMode) {
        print(e);
      }
      if (kDebugMode) {
        print(s);
      }
    }

    // store quotes
    try {
      await db.execute('''
            CREATE TABLE $quoteTable (
              $columnQuoteId INTEGER PRIMARY KEY,
              $columnQuoteText TEXT NOT NULL,
              $columnCurrent TEXT NOT NULL
            )
            ''');
    } catch (e, s) {
      if (kDebugMode) {
        print(e);
      }
      if (kDebugMode) {
        print(s);
      }
    }

    try {
      await db.execute('''
          CREATE INDEX curr_index ON $quoteTable($columnCurrent)
            ''');
    } catch (e, s) {
      if (kDebugMode) {
        print(e);
      }
      if (kDebugMode) {
        print(s);
      }
    }

    try {
      await db.execute('''
        CREATE TABLE $chatTable (
          $chatColumnId INTEGER PRIMARY KEY AUTOINCREMENT,
          $chatColumnSender TEXT NOT NULL,
          $chatColumnContent TEXT NOT NULL,
          $chatColumnTimestamp TEXT NOT NULL
        )
        ''');
    } catch (e, s) {
      if (kDebugMode) {
        print(e);
      }
      if (kDebugMode) {
        print(s);
      }
    }

    try {
      await db.execute('''
            CREATE TABLE $visionStatementTable (
              $columnVisionId INTEGER PRIMARY KEY AUTOINCREMENT,
              $columnVisionText TEXT NOT NULL,
              $columnVisionCreated TEXT NOT NULL
            )
            ''');
    } catch (e, s) {
      if (kDebugMode) {
        print(e);
      }
      if (kDebugMode) {
        print(s);
      }
    }

    // Commentary countdown table
    try {
      await db.execute('''
            CREATE TABLE $commentaryCountdownTable (
              $columnCountdownId INTEGER PRIMARY KEY,
              $columnCountdownValue INTEGER NOT NULL
            )
            ''');
    } catch (e, s) {
      if (kDebugMode) {
        print(e);
      }
      if (kDebugMode) {
        print(s);
      }
    }

    // DEMO TABLES
    await db.execute('''
          CREATE TABLE IF NOT EXISTS $demoTaskTable (
            $columnId INTEGER PRIMARY KEY,
            $columnCategory TEXT NOT NULL,
            $columnTaskDescription TEXT NOT NULL,
            $columnSunday TEXT NOT NULL DEFAULT 'true',
            $columnMonday TEXT NOT NULL DEFAULT 'true',
            $columnTuesday TEXT NOT NULL DEFAULT 'true',
            $columnWednesday TEXT NOT NULL DEFAULT 'true',
            $columnThursday TEXT NOT NULL DEFAULT 'true',
            $columnFriday TEXT NOT NULL DEFAULT 'true',
            $columnSaturday TEXT NOT NULL DEFAULT 'true',
            $columnCreateDate TEXT NOT NULL,
            UNIQUE($columnCategory, $columnTaskDescription)
          )
          ''');
    await db.execute('''
          CREATE TABLE IF NOT EXISTS $demoTaskLogTable (
            $columnTLId INTEGER PRIMARY KEY,
            $columnTLCategory TEXT NOT NULL,
            $columnTLTaskDescription TEXT NOT NULL,
            $columnTLChecked TEXT NOT NULL,
            $columnTLTaskDate TEXT NOT NULL,
            UNIQUE($columnTLCategory, $columnTLTaskDescription, $columnTLTaskDate)
          )
          ''');
    await db.execute('''
          CREATE TABLE IF NOT EXISTS $demoCategoryTable (
            $columnCategoryId INTEGER PRIMARY KEY,
            $columnCat TEXT NOT NULL,
            UNIQUE($columnCat) ON CONFLICT IGNORE
          )
          ''');
    await db.execute('''
          CREATE TABLE IF NOT EXISTS $demoQuoteTable (
            $columnQuoteId INTEGER PRIMARY KEY,
            $columnQuoteText TEXT NOT NULL,
            $columnCurrent TEXT NOT NULL
          )
          ''');
    await db.execute('''
          CREATE TABLE IF NOT EXISTS $demoChatTable (
            $chatColumnId INTEGER PRIMARY KEY AUTOINCREMENT,
            $chatColumnSender TEXT NOT NULL,
            $chatColumnContent TEXT NOT NULL,
            $chatColumnTimestamp TEXT NOT NULL
          )
          ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    for (var i = oldVersion; i <= newVersion; i++) {
      if (i > oldVersion) {
        switch (i) {
          case 2:
            if (kDebugMode) {
              print(
                  '****** in _onUpgrade(): oldversion is $oldVersion and newVersion is $newVersion');
            }
            await db.execute(
                "ALTER TABLE task ADD COLUMN sunday TEXT NOT NULL DEFAULT 'true'");
            await db.execute(
                "ALTER TABLE task ADD COLUMN monday TEXT NOT NULL DEFAULT 'true'");
            await db.execute(
                "ALTER TABLE task ADD COLUMN tuesday TEXT NOT NULL DEFAULT 'true'");
            await db.execute(
                "ALTER TABLE task ADD COLUMN wednesday TEXT NOT NULL DEFAULT 'true'");
            await db.execute(
                "ALTER TABLE task ADD COLUMN thursday TEXT NOT NULL DEFAULT 'true'");
            await db.execute(
                "ALTER TABLE task ADD COLUMN friday TEXT NOT NULL DEFAULT 'true'");
            await db.execute(
                "ALTER TABLE task ADD COLUMN saturday TEXT NOT NULL DEFAULT 'true'");
            break;
          case 3:
            if (kDebugMode) {
              print(
                  '****** in _onUpgrade(): oldversion is $oldVersion and newVersion is $newVersion');
            }
            await db.execute('''
              CREATE TABLE $chatTable (
              $chatColumnId INTEGER PRIMARY KEY AUTOINCREMENT,
              $chatColumnSender TEXT NOT NULL,
              $chatColumnContent TEXT NOT NULL,
              $chatColumnTimestamp TEXT NOT NULL
            )
            ''');
          case 4:
            if (kDebugMode) {
              print('****** in _onUpgrade(): oldversion is '
                  ' 2$oldVersion and newVersion is $newVersion');
            }
            await db.execute('''
              CREATE TABLE $visionStatementTable (
                $columnVisionId INTEGER PRIMARY KEY AUTOINCREMENT,
                $columnVisionText TEXT NOT NULL,
                $columnVisionCreated TEXT NOT NULL
              )
            ''');
          case 5:
            if (kDebugMode) {
              print('****** in _onUpgrade(): oldversion is '
                  ' 2$oldVersion and newVersion is $newVersion');
            }
            await db.execute('''
              CREATE TABLE $commentaryCountdownTable (
                $columnCountdownId INTEGER PRIMARY KEY,
                $columnCountdownValue INTEGER NOT NULL
              )
            ''');
        }
      }
    }
    // Always create demo tables if missing
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $demoCategoryTable (
        $columnCategoryId INTEGER PRIMARY KEY,
        $columnCat TEXT NOT NULL,
        UNIQUE($columnCat) ON CONFLICT IGNORE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $demoTaskTable (
        $columnId INTEGER PRIMARY KEY,
        $columnCategory TEXT NOT NULL,
        $columnTaskDescription TEXT NOT NULL,
        $columnSunday TEXT NOT NULL DEFAULT 'true',
        $columnMonday TEXT NOT NULL DEFAULT 'true',
        $columnTuesday TEXT NOT NULL DEFAULT 'true',
        $columnWednesday TEXT NOT NULL DEFAULT 'true',
        $columnThursday TEXT NOT NULL DEFAULT 'true',
        $columnFriday TEXT NOT NULL DEFAULT 'true',
        $columnSaturday TEXT NOT NULL DEFAULT 'true',
        $columnCreateDate TEXT NOT NULL,
        UNIQUE($columnCategory, $columnTaskDescription)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $demoTaskLogTable (
        $columnTLId INTEGER PRIMARY KEY,
        $columnTLCategory TEXT NOT NULL,
        $columnTLTaskDescription TEXT NOT NULL,
        $columnTLChecked TEXT NOT NULL,
        $columnTLTaskDate TEXT NOT NULL,
        UNIQUE($columnTLCategory, $columnTLTaskDescription, $columnTLTaskDate)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $demoQuoteTable (
        $columnQuoteId INTEGER PRIMARY KEY,
        $columnQuoteText TEXT NOT NULL,
        $columnCurrent TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $demoChatTable (
        $chatColumnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $chatColumnSender TEXT NOT NULL,
        $chatColumnContent TEXT NOT NULL,
        $chatColumnTimestamp TEXT NOT NULL
      )
    ''');
  }

// -----------------------------------------------------------------------------
//                                                               populateQuote()
// -----------------------------------------------------------------------------
  void populateQuote() async {
    final List<Map<String, dynamic>> maps = await queryCurrentQuote();
    if (maps.isEmpty) {
      deleteQuote();

      List quoteList = [
        '"Small habits, when done consistently, can lead to extraordinary results." - James Clear',
        '"Focus on the process, not just the outcome. Success is built on the daily actions you take." - James Clear',
        '"You do not rise to the level of your goals; you fall to the level of your systems." - James Clear',
        '"Habits are the compound interest of self-improvement. The effects of your habits multiply as you repeat them." - James Clear',
        '"Make it easy to do the things that are good for you. Design your environment to support your desired habits." - James Clear',
        '"Your habits shape your identity. If you want to change your results, you must first change your identity." - James Clear',
        '"The quality of your life depends on the quality of your habits." - James Clear',
        '"Success is not a one-time event; it is the sum of small actions repeated day in and day out." - James Clear',
        '"Habits are the invisible architecture of everyday life. Make them work for you." - James Clear',
        '"Never underestimate the power of small habits. They have the potential to transform your life." - James Clear',
        '"Your habits shape your identity. Choose them wisely and become the person you aspire to be." - James Clear',
        '"Success is not a singular event but a series of small, daily habits that compound over time." - James Clear',
        '"Habit formation is not about willpower; it is about designing an environment that makes your desired behaviors easier." - James Clear',
        '"The key to lasting change is not setting big, audacious goals, but rather focusing on the small, consistent actions that lead to progress." - James Clear',
        '"Habits are the invisible architecture of our lives. Build them intentionally, and they will shape your destiny." - James Clear',
        '"Mastery is not achieved through occasional bursts of effort, but through the relentless consistency of small habits." - James Clear',
        '"The quality of your life is determined by the quality of your habits. Make them deliberate and watch your life transform." - James Clear',
        '"Success is a product of your habits, not your goals. Focus on building the right habits, and success will follow." - James Clear',
        '"Habits are not a finish line to be crossed but a lifelong journey. Embrace the process and enjoy the progress." - James Clear',
        '"Habits are not a finish line to be crossed but a lifelong journey. Embrace the process and enjoy the progress." - James Clear',
        '"Every action you take is a vote for the type of person you wish to become." - James Clear',
        '"Success is the product of daily habits—not once-in-a-lifetime transformations." - James Clear',
        '"You don'
            't have to be great to start, but you have to start to be great." - James Clear',
        '"Small habits can make a big difference." - James Clear',
        '"Make it easy to do right and hard to go wrong." - James Clear',
        '"The secret to getting results that last is to never stop making improvements." - James Clear',
        '"Master the art of showing up consistently." - James Clear',
        '"It'
            's not about achieving overnight success; it'
            's about making progress consistently." - James Clear',
        '"Make time for the habits that will make you better." - James Clear',
        '"Fall in love with the process of improvement." - James Clear',
        '"You don'
            't need to be the best, you just need to be a little bit better today than you were yesterday." - James Clear',
        '"Focus on progress, not perfection." - James Clear',
        '"The goal is not to get rid of bad habits, but to replace them with good habits." - James Clear',
        '"Habits are the invisible architecture of our lives." - James Clear',
        '"A habit is a behavior that has been repeated enough times to become automatic." - James Clear',
        '"Small changes can have a big impact when they are consistently applied." - James Clear',
        '"The most effective way to change your habits is to focus on your identity." - James Clear',
        '"Your habits shape your identity, and your identity shapes your habits." - James Clear',
        '"Habits are the building blocks of excellence." - James Clear',
        '"The most successful people are the ones with the best habits." - James Clear',
        '"Success is not an event; it' 's a process." - James Clear',
        '"You don'
            't rise to the level of your goals; you fall to the level of your systems." - James Clear',
        '"Habits are like the atoms of our lives. Each one is a fundamental unit that contributes to your overall growth." - James Clear',
        '"Make good habits more convenient and bad habits more difficult." - James Clear',
        '"The path to success is paved with small, consistent actions." - James Clear',
        '"Become 1% better every day." - James Clear',
        '"Tiny changes can lead to remarkable results. Master the art of small habits, and you will unlock extraordinary potential." - James Clear',
        '"Habits are like financial capital – forming one today is an investment that will automatically give out returns for years to come." - Gretchen Rubin',
        '"We are what we repeatedly do. Excellence, then, is not an act but a habit." - Will Durant',
        '"Habit is the intersection of knowledge (what to do), skill (how to do), and desire (want to do)." - Stephen Covey',
        '"The chains of habit are too weak to be felt until they are too strong to be broken." - Samuel Johnson',
        '"Your net worth to the world is usually determined by what remains after your bad habits are subtracted from your good ones." - Benjamin Franklin',
        '"The best way to stop a bad habit is to never begin it." - J.C. Penney',
        '"We first make our habits, and then our habits make us." - John Dryden',
        '"The only way to break a bad habit is to replace it with a good one." - Denis Waitley',
        '"Habit is a cable; we weave a thread each day, and at last, we cannot break it." - Horace Mann',
        '"Lose no time; be always employed in something useful; cut off all unnecessary actions." - Benjamin Franklin',
        '"We cannot solve our problems with the same thinking we used when we created them." - Albert Einstein',
        '"The world as we have created it is a process of our thinking. It cannot be changed without changing our thinking." - Albert Einstein',
        '"Life is like riding a bicycle. To keep your balance, you must keep moving." -  Albert Einstein ',
        '"I write only when inspiration strikes. Fortunately it strikes every morning at nine o'
            'clock sharp." - W. Somerset Maugham',
        '"Hard choices, easy life. Easy choices, hard life." - Jerzy Gregorek'
      ];

      var i = 0;
      quoteList.forEach((quote) async {
        i++;
        // row to insert
        Map<String, dynamic> quoteRow = {
          DatabaseHelper.columnQuoteId: i,
          DatabaseHelper.columnQuoteText: quote,
          DatabaseHelper.columnCurrent: 'N'
        };
        await insertQuote(quoteRow);
      });

      // Choose a single random quote to make current.
      updateRandomCurrentQuote();

      // final List<Map<String, dynamic>> quotes = await queryAllQuotes();
    }
  }

// -----------------------------------------------------------------------------
//                                                          populateTaskLogGap()
// -----------------------------------------------------------------------------

  void populateTaskLogGap() async {
    // for every task in every category, make sure that there is a tasklog
    // entry for the past 7 days for the days of week that are available
    // for that task.

    Database db = await instance.database;

    final intl.DateFormat formatter = intl.DateFormat('yyyy-MM-dd');
    intl.DateFormat dowFmt = intl.DateFormat('EEEE');
    String taskDate;
    String dow;
    // A zero-indexed for loop and increment the days before now().
    for (var i = 0; i <= 6; i++) {
      taskDate = formatter
          .format(DateTime.now().subtract(Duration(days: i)))
          .toString();

      dow =
          dowFmt.format(DateTime.now().subtract(Duration(days: i))).toString();

      // consider the task's day of week blackouts when deciding to
      // insert into tasklog.
      try {
        String query = "insert or ignore into tasklog "
            "(category, taskdescription, checked, taskdate) "
            "select category, taskdescription, 'false', '$taskDate' "
            "from task where $dow = 'true'";
        await db.execute(query);
      } catch (e, s) {
        if (kDebugMode) {
          print(e);
        }
        if (kDebugMode) {
          print(s);
        }
      }
    }
  }

// -----------------------------------------------------------------------------
//                                                            populateCategory()
// -----------------------------------------------------------------------------
  void populateCategory() async {
    await rawInsert("insert into category(categoryid, cat) values"
        "(1, 'Empty1') "
        " on conflict (categoryid) do nothing");

    await rawInsert("insert into category(categoryid, cat) values"
        "(2, 'Empty2') "
        " on conflict (categoryid) do nothing");

    await rawInsert("insert into category(categoryid, cat) values"
        "(3, 'Empty3') "
        " on conflict (categoryid) do nothing");

    await rawInsert("insert into category(categoryid, cat) values"
        "(4, 'Empty4') "
        " on conflict (categoryid) do nothing");

    await rawInsert("insert into category(categoryid, cat) values"
        "(5, 'Empty5') "
        " on conflict (categoryid) do nothing");

    await rawInsert("insert into category(categoryid, cat) values"
        "(6, 'Empty6') "
        " on conflict (categoryid) do nothing");
  }

// Helper methods

  // Inserts a row in the database where each key in the Map is a column name
  // and the value is the column value. The return value is the id of the
  // inserted row.
  Future<int> insertTask(Map<String, dynamic> row) async {
    int id = 0;
    try {
      Database db = await instance.database;
      id = await db.insert(getTaskTable(), row);
    } catch (e, s) {
      if (kDebugMode) {
        print(e);
      }
      if (kDebugMode) {
        print(s);
      }
    }
    return id;
  }

  // Inserts a row in the database where each key in the Map is a column name
  // and the value is the column value. The return value is the id of the
  // inserted row.
  Future<int> insertCategory(Map<String, dynamic> row) async {
    int id = 0;
    try {
      Database db = await instance.database;
      id = await db.insert(getCategoryTable(), row);
    } catch (e, s) {
      if (kDebugMode) {
        print(e);
      }
      if (kDebugMode) {
        print(s);
      }
    }
    return id;
  }

  // Inserts a row in the database where each key in the Map is a column name
  // and the value is the column value. The return value is the id of the
  // inserted row.
  Future<int> insertTaskLog(Map<String, dynamic> row) async {
    int id = 0;
    try {
      Database db = await instance.database;
      id = await db.insert(getTaskLogTable(), row);
    } catch (e, s) {
      if (kDebugMode) {
        print(e);
      }
      if (kDebugMode) {
        print(s);
      }
    }
    return id;
  }

  // All of the rows are returned as a list of maps, where each map is
  // a key-value list of columns.
  Future<List<Map<String, dynamic>>> query() async {
    late List<Map<String, dynamic>> ret;
    try {
      Database db = await instance.database;
      ret = await db.query(getTaskTable());
    } catch (e, s) {
      if (kDebugMode) {
        print(e);
      }
      if (kDebugMode) {
        print(s);
      }
    }
    return ret;
  }

  // return -1 if there are no tasks at all for this category.
  Future<int> getCompletionPercentage(String cat, int days) async {
    Database db = await instance.database;
    // First, check if there are any tasks for this category
    final taskTable = getTaskTable();
    final taskRes = await db.query(taskTable, where: '$columnCategory = ?', whereArgs: [cat]);
    if (taskRes.isEmpty) {
      return -1; // No tasks defined for this category
    }
    final intl.DateFormat formatter = intl.DateFormat('yyyy-MM-dd');
    var fromDate = formatter
        .format(DateTime.now().subtract(Duration(days: days)))
        .toString();
    final table = getTaskLogTable();
    print('[RADAR][PCT] Using table: $table for category: $cat');
    var q1 = "select * from $table where category = ? and taskdate >= ?";
    final res1 = await db.rawQuery(q1, [cat, fromDate]);
    var total = res1.length;
    print('[RADAR][PCT] Total logs for $cat: $total');
    var q2 = "select * from $table where category = ? and taskdate >= ? and checked = 'true'";
    final res2 = await db.rawQuery(q2, [cat, fromDate]);
    var checked = res2.length;
    print('[RADAR][PCT] Checked logs for $cat: $checked');
    if (total == 0) {
      return 0; // Tasks exist, but no logs in range
    }
    var percentage = ((checked / total) * 100).toInt();
    print('[RADAR][PCT] Percentage for $cat: $percentage');
    return percentage;
  }

  // return '' if there are no tasks at all.
  Future<String> getTotalPercentage(int days) async {
    await instance.database;
    // Get all categories (1-6)
    List<String> cats = [];
    try {
      final catMaps = await queryCategories();
      for (var i = 1; i <= 6; i++) {
        final match = catMaps.firstWhere(
          (c) => c['categoryid'] == i,
          orElse: () => <String, dynamic>{},
        );
        if (match.isNotEmpty && match['cat'] != null) cats.add(match['cat']);
      }
    } catch (e) {
      print('[TOTAL PCT] Error loading categories: $e');
    }
    if (cats.isEmpty) return '0';
    int sum = 0;
    int count = 0;
    for (final cat in cats) {
      final pct = await getCompletionPercentage(cat, days);
      if (pct >= 0) {
        sum += pct;
        count++;
      }
    }
    if (count == 0) return '0';
    final avg = (sum / count).round();
    print('[TOTAL PCT] Per-category: $cats, avg: $avg');
    return avg.toString();
  }

  Future<List<Map<String, dynamic>>> queryUncheckedTasks(String logDate) async {
    late List<Map<String, dynamic>> ret;
    try {
      Database db = await instance.database;
      List<dynamic> whereArguments = [logDate];
      ret = await db.query(getTaskLogTable(),
          where: "checked = 'false' and ${DatabaseHelper.columnTLTaskDate} = ?",
          whereArgs: whereArguments);
    } catch (e, s) {
      print(e);
      print(s);
    }
    return ret;
  }

  Future<List<Map<String, dynamic>>> queryCheckedTasks(String logDate) async {
    late List<Map<String, dynamic>> ret;
    try {
      Database db = await instance.database;
      List<dynamic> whereArguments = [logDate];
      ret = await db.query(getTaskLogTable(),
          where: "checked = 'true' and ${DatabaseHelper.columnTLTaskDate} = ?",
          whereArgs: whereArguments);
    } catch (e, s) {
      if (kDebugMode) {
        print(e);
      }
      print(s);
    }
    return ret;
  }

  Future<List<Map<String, dynamic>>> queryCategories() async {
    late List<Map<String, dynamic>> ret;
    try {
      Database db = await instance.database;
      ret = await db.query(getCategoryTable());
    } catch (e, s) {
      print(e);
      print(s);
    }
    return ret;
  }

  Future<List<Map<String, dynamic>>> queryCategory(int categoryid) async {
    late List<Map<String, dynamic>> ret;
    try {
      Database db = await instance.database;
      List<dynamic> whereArguments = [categoryid];
      ret = await db.query(getCategoryTable(),
          where: "${DatabaseHelper.columnCategoryId} = ?",
          whereArgs: whereArguments);
    } catch (e, s) {
      if (kDebugMode) {
        print(e);
      }
      print(s);
    }
    return ret;
  }

  Future<List<Map<String, dynamic>>> queryCurrentQuote() async {
    late List<Map<String, dynamic>> ret;
    try {
      Database db = await instance.database;
      ret = await db.query(getQuoteTable(), where: "current = 'Y'");
    } catch (e, s) {
      print(e);
      print(s);
    }
    return ret;
  }

  Future<List<Map<String, dynamic>>> queryAllQuotes() async {
    late List<Map<String, dynamic>> ret;
    try {
      Database db = await instance.database;
      ret = await db.query(getQuoteTable());
    } catch (e, s) {
      print(e);
      print(s);
    }
    return ret;
  }

  Future<List<Map<String, dynamic>>> queryTaskLogByCategory(
      String cat, String logDate) async {
    late List<Map<String, dynamic>> ret;
    try {
      Database db = await instance.database;
      List<dynamic> whereArguments = [cat, logDate];
      ret = await db.query(getTaskLogTable(),
          where:
              '${DatabaseHelper.columnCategory} = ? and ${DatabaseHelper.columnTLTaskDate} = ?',
          whereArgs: whereArguments);
    } catch (e, s) {
      print(e);
      print(s);
    }
    return ret;
  }

  Future<List<Map<String, dynamic>>> queryAllTasks() async {
    late List<Map<String, dynamic>> ret;
    try {
      Database db = await instance.database;
      ret = await db.query(getTaskTable());
    } catch (e, s) {
      print(e);
      print(s);
    }
    return ret;
  }

  Future<List<Map<String, dynamic>>> queryTaskLogs(int days) async {
    late List<Map<String, dynamic>> ret;

    final intl.DateFormat formatter = intl.DateFormat('yyyy-MM-dd');

    var fromDate = formatter
        .format(DateTime.now().subtract(Duration(days: days)))
        .toString();

    var toDate = formatter.format(DateTime.now()).toString();

    try {
      Database db = await instance.database;

      var query = "select * from ${getTaskLogTable()} where "
          "taskdate >= '$fromDate' and "
          "taskdate < '$toDate'"
          "order by taskdate";
      ret = await db.rawQuery(query);
    } catch (e, s) {
      print(e);
      print(s);
    }
    return ret;
  }

  Future<List<Map<String, dynamic>>> queryAllTaskLogs() async {
    late List<Map<String, dynamic>> ret;
    try {
      Database db = await instance.database;
      ret = await db.query(getTaskLogTable());
    } catch (e, s) {
      print(e);
      print(s);
    }
    return ret;
  }

  Future<List<Map<String, dynamic>>> queryForProfile() async {
    late List<Map<String, dynamic>> ret;

    try {
      Database db = await instance.database;

      var query = "select distinct category, taskdescription  "
          "from tasklog";
      ret = await db.rawQuery(query);
    } catch (e, s) {
      print(e);
      print(s);
    }
    return ret;
  }

  Future<int> queryLaunchSetup() async {
    late List<Map<String, dynamic>> maps;

    try {
      Database db = await instance.database;

      var query = "select count(*) as defaults from category where "
          "cat like 'Empty%'";
      maps = await db.rawQuery(query);
    } catch (e, s) {
      print(e);
      if (kDebugMode) {
        print(s);
      }
    }

    return await maps[0]['defaults'];
  }

  Future<List<Map<String, dynamic>>> queryTasksByCategory(String cat) async {
    late List<Map<String, dynamic>> ret;
    try {
      Database db = await instance.database;
      List<dynamic> whereArguments = [cat];
      ret = await db.query(getTaskTable(),
          where: '${DatabaseHelper.columnCategory} = ?',
          whereArgs: whereArguments);
    } catch (e, s) {
      print(e);
      print(s);
    }
    return ret;
  }

  Future<List<Map<String, dynamic>>> querySingleTask(
      String cat, String desc) async {
    late List<Map<String, dynamic>> ret;
    try {
      Database db = await instance.database;
      List<dynamic> whereArguments = [cat, desc];
      ret = await db.query(getTaskTable(),
          where:
              '${DatabaseHelper.columnCategory} = ? and ${DatabaseHelper.columnTaskDescription} = ?',
          whereArgs: whereArguments);
    } catch (e, s) {
      print(e);
      print(s);
    }
    return ret;
  }

  insertTaskLogForCategory(String cat, String logDate, String dow) async {
    Database db = await instance.database;

    // consider the task's day of week blackouts when deciding to
    // insert into tasklog.
    try {
      String query = "insert into tasklog "
          "(category, taskdescription, checked, taskdate) "
          "select category, taskdescription, 'false', '$logDate' "
          "from task where category = '$cat' and $dow = 'true'";
      await db.execute(query);
    } catch (e, s) {
      print(e);
      print(s);
    }
  }

  Future<int> insertQuote(Map<String, dynamic> row) async {
    int id = 0;
    try {
      Database db = await instance.database;
      id = await db.insert(getQuoteTable(), row);
    } catch (e, s) {
      print(e);
      print(s);
    }
    return id;
  }

  Future<int> updateRandomCurrentQuote() async {
    // update all rows to current = 'N';
    await _database
        .rawUpdate("update quote set current = 'N' where current = 'Y'");

    // grab a random row id.
    var q1 = 'select quoteid from quote order by random() limit 1';
    var rs = await _database.rawQuery(q1);
    var randomRow = rs.first;
    var currentQuoteId = randomRow['quoteid'];

    // set the random row to current.
    await _database.rawUpdate(
        "update quote set current = 'Y' where quoteid = $currentQuoteId");

    final List<Map<String, dynamic>> maps = await queryCurrentQuote();

    return await maps[0]['quoteid'];
  }

  // We are assuming here that the id column in the map is set. The other
  // column values will be used to update the row.
  Future<int> update(Map<String, dynamic> row) async {
    Database db = await instance.database;
    int id = row[columnId];
    return await db
        .update(getTaskTable(), row, where: '$columnId = ?', whereArgs: [id]);
  }

  // update review
  Future<int> updateReview(String upd) async {
    Database db = await instance.database;
    return await db.rawUpdate(upd);
  }

  /// Sets one day-of-week flag on a task. Parameterized: [day] is validated
  /// against a fixed allowlist so it can never carry injected SQL, and the
  /// user-entered category and description are bound, never interpolated.
  ///
  /// D-024: extracted from lib/screens/edittaskdetail.dart, which built this
  /// statement by string interpolation of user input.
  static const Set<String> dayColumns = {
    'sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'
  };

  Future<int> setTaskDayFlag({
    required String category,
    required String taskDescription,
    required String day,
    required bool value,
  }) async {
    if (!dayColumns.contains(day)) {
      throw ArgumentError.value(day, 'day', 'not a day-of-week column');
    }
    final db = await instance.database;
    return db.update(
      getTaskTable(),
      {day: value.toString()},
      where: '$columnCategory = ? AND $columnTaskDescription = ?',
      whereArgs: [category, taskDescription],
    );
  }

  /// Renames a task within a category. Parameterized.
  ///
  /// D-024: extracted from lib/screens/edittaskdetail.dart.
  Future<int> renameTask({
    required String category,
    required String oldDescription,
    required String newDescription,
  }) async {
    final db = await instance.database;
    return db.update(
      getTaskTable(),
      {columnTaskDescription: newDescription},
      where: '$columnCategory = ? AND $columnTaskDescription = ?',
      whereArgs: [category, oldDescription],
    );
  }

  /// Creates or renames a category at a fixed pyramid slot. Parameterized.
  ///
  /// D-024: extracted from lib/screens/editpyramid.dart, which interpolated
  /// the user-entered name straight into SQL.
  ///
  /// D-084 will extend this to cascade the rename into `task` and `task_log`,
  /// which key on the category *name*. Until then, renaming still orphans a
  /// category's habits — see II-N.
  Future<int> upsertCategoryAt(int categoryid, String cat) async {
    final db = await instance.database;
    return db.rawInsert(
      'INSERT INTO ${getCategoryTable()} ($columnCategoryId, $columnCat) '
      'VALUES (?, ?) '
      'ON CONFLICT ($columnCategoryId) DO UPDATE SET $columnCat = ?',
      [categoryid, cat, cat],
    );
  }

  /// Marks a habit checked or unchecked for a given date. Parameterized.
  ///
  /// D-024: extracted from lib/screens/tasklist.dart. This is the core daily
  /// interaction and was previously built by interpolating user-entered text
  /// into a SQL string.
  Future<int> setTaskLogChecked({
    required String category,
    required String taskDescription,
    required String taskDate,
    required bool checked,
  }) async {
    final db = await instance.database;
    return db.update(
      getTaskLogTable(),
      {columnTLChecked: checked.toString()},
      where: '$columnTLCategory = ? AND $columnTLTaskDescription = ? '
          'AND $columnTLTaskDate = ?',
      whereArgs: [category, taskDescription, taskDate],
    );
  }

  /// Deletes every log row for one habit. Parameterized.
  ///
  /// D-024: extracted from lib/screens/edittaskdetail.dart.
  Future<int> deleteTaskLogsForTask({
    required String category,
    required String taskDescription,
  }) async {
    final db = await instance.database;
    return db.delete(
      getTaskLogTable(),
      where: '$columnTLCategory = ? AND $columnTLTaskDescription = ?',
      whereArgs: [category, taskDescription],
    );
  }

  /// Deletes every task and log row belonging to a category. Parameterized.
  ///
  /// D-024: extracted from lib/screens/editpyramid.dart.
  Future<void> deleteCategoryContents(String category) async {
    final db = await instance.database;
    await db.delete(getTaskLogTable(),
        where: '$columnTLCategory = ?', whereArgs: [category]);
    await db.delete(getTaskTable(),
        where: '$columnCategory = ?', whereArgs: [category]);
  }

  Future<int> rawUpdate(String upd) async {
    Database db = await instance.database;
    return await db.rawUpdate(upd);
  }

  Future<int> rawInsert(String ins) async {
    Database db = await instance.database;
    return await db.rawInsert(ins);
  }

  Future<int> rawDelete(String del) async {
    Database db = await instance.database;
    return await db.rawDelete(del);
  }

  Future<List<Map>> rawQuery(String qry) async {
    Database db = await instance.database;
    return await db.rawQuery(qry);
  }

  // Deletes the row specified by the id. The number of affected rows is
  // returned. This should be 1 as long as the row exists.
  Future<int> delete(int id) async {
    Database db = await instance.database;
    return await db.delete(getTaskTable(), where: '$columnId = ?', whereArgs: [id]);
  }

  // Deletes a task and every task-log entry it produced — including the
  // current day's already-generated entry — in a single transaction, scoped
  // to [category] so an identically named task in another category is left
  // untouched. Previously only the task row was removed, so today's log
  // entry survived and the deleted task kept appearing in the day's Log
  // (it can't regenerate once the task row is gone, since the day's log is
  // rebuilt from the task table).
  Future<void> deleteTaskAndLog(String category, String taskDescription) async {
    Database db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete(getTaskTable(),
          where: '$columnCategory = ? and $columnTaskDescription = ?',
          whereArgs: [category, taskDescription]);
      await txn.delete(getTaskLogTable(),
          where: '$columnTLCategory = ? and $columnTLTaskDescription = ?',
          whereArgs: [category, taskDescription]);
    });
  }

  Future<int> deleteTasks() async {
    Database db = await instance.database;
    return await db.delete(getTaskTable());
  }

  Future<int> deleteTaskLog() async {
    Database db = await instance.database;
    return await db.delete(getTaskLogTable());
  }

  Future<int> deleteQuote() async {
    Database db = await instance.database;
    return await db.delete(getQuoteTable());
  }

  Future<int> deleteCategory() async {
    Database db = await instance.database;
    return await db.delete(getCategoryTable());
  }

  Future<int> insertVisionStatement(String visionText) async {
    int id = 0;
    try {
      Database db = await instance.database;
      id = await db.insert(visionStatementTable, {
        columnVisionText: visionText,
        columnVisionCreated: DateTime.now().toIso8601String(),
      });
    } catch (e, s) {
      if (kDebugMode) {
        print(e);
      }
      if (kDebugMode) {
        print(s);
      }
    }
    return id;
  }

  Future<String?> getLatestVisionStatement() async {
    try {
      Database db = await instance.database;
      final result = await db.query(
        visionStatementTable,
        orderBy: '$columnVisionCreated DESC',
        limit: 1,
      );
      if (result.isNotEmpty) {
        return result.first[columnVisionText] as String;
      }
    } catch (e, s) {
      if (kDebugMode) {
        print(e);
      }
      if (kDebugMode) {
        print(s);
      }
    }
    return null;
  }

  Future<void> insertChatMessage(String sender, String content) async {
    final db = await database;
    await db.insert(getChatTable(), {
      chatColumnSender: sender,
      chatColumnContent: content,
      chatColumnTimestamp: DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getChatHistory() async {
    final db = await database;
    return await db.query(getChatTable(), orderBy: '$chatColumnTimestamp ASC');
  }

  Future<void> deleteOldestChatMessage(int messageId) async {
    final db = await database;
    await db
        .delete(getChatTable(), where: '$chatColumnId = ?', whereArgs: [messageId]);
  }

  // Commentary countdown methods
  Future<void> saveCommentaryCountdown(int countdown) async {
    try {
      Database db = await instance.database;
      // Delete existing countdown
      await db.delete(commentaryCountdownTable);
      // Insert new countdown
      await db.insert(commentaryCountdownTable, {
        columnCountdownId: 1,
        columnCountdownValue: countdown,
      });
    } catch (e, s) {
      if (kDebugMode) {
        print(e);
      }
      if (kDebugMode) {
        print(s);
      }
    }
  }

  Future<int> getCommentaryCountdown() async {
    try {
      Database db = await instance.database;
      final result = await db.query(
        commentaryCountdownTable,
        where: '$columnCountdownId = ?',
        whereArgs: [1],
      );
      if (result.isNotEmpty) {
        return result.first[columnCountdownValue] as int;
      }
    } catch (e, s) {
      if (kDebugMode) {
        print(e);
      }
      if (kDebugMode) {
        print(s);
      }
    }
    return 30; // Default value if not found
  }
}

class Task {
  int id = 0;
  String category = '';
  String taskdescription = '';
  String sunday = '';
  String monday = '';
  String tuesday = '';
  String wednesday = '';
  String thursday = '';
  String friday = '';
  String saturday = '';

  Task(
      {required this.id,
      required this.category,
      required this.taskdescription,
      required this.sunday,
      required this.monday,
      required this.tuesday,
      required this.wednesday,
      required this.thursday,
      required this.friday,
      required this.saturday});

  Task.fromMap(dynamic obj) {
    id = obj["id"];
    category = obj["category"];
    taskdescription = obj["taskdescription"];
    sunday = obj["sunday"];
    monday = obj["monday"];
    tuesday = obj["tuesday"];
    wednesday = obj["wednesday"];
    thursday = obj["thursday"];
    friday = obj["friday"];
    saturday = obj["saturday"];
  }
}

class ChatMessage {
  final int? id;
  final String role; // 'user' or 'assistant'
  final String content;

  ChatMessage({this.id, required this.role, required this.content});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sender': role,
      'content': content,
    };
  }

  static ChatMessage fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'],
      role: map['sender'],
      content: map['content'],
    );
  }
}
