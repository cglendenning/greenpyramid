import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart' as intl;

class DatabaseHelper {
  static const _databaseName = "LifeOps.db";
  static const _databaseVersion = 4;

  // The task table. This stores the current view of tasks for each value.
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
        }
      }
    }
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
      id = await db.insert(taskTable, row);
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
      id = await db.insert(categoryTable, row);
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
      id = await db.insert(taskLogTable, row);
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
      ret = await db.query(taskTable);
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

    final intl.DateFormat formatter = intl.DateFormat('yyyy-MM-dd');

    var fromDate = formatter
        .format(DateTime.now().subtract(Duration(days: days)))
        .toString();

    var q1 = "select * from tasklog where category = '$cat'"
        " and taskdate >= '$fromDate'";
    final res1 = await db.rawQuery(q1);
    var total = res1.length;

    var q2 = "select * from tasklog where category = '$cat'"
        " and taskdate >= '$fromDate'"
        " and checked = 'true'";
    final res2 = await db.rawQuery(q2);
    var checked = res2.length;

    // do not attempt to divide by 0
    if (total == 0) {
      return -1;
    }

    var percentage = ((checked / total) * 100).toInt();

    return percentage;
  }

  // return '' if there are no tasks at all.
  Future<String> getTotalPercentage(int days) async {
    Database db = await instance.database;

    final intl.DateFormat formatter = intl.DateFormat('yyyy-MM-dd');

    var fromDate = formatter
        .format(DateTime.now().subtract(Duration(days: days)))
        .toString();

    var q1 = "select * from tasklog where "
        "taskdate >= '$fromDate'";
    final res1 = await db.rawQuery(q1);
    var total = res1.length;

    var q2 = "select * from tasklog where "
        "taskdate >= '$fromDate'"
        " and checked = 'true'";
    final res2 = await db.rawQuery(q2);
    var checked = res2.length;

    // do not attempt to divide by 0
    if (total == 0) {
      return '';
    }

    var percentage = ((checked / total) * 100).toInt();

    return percentage.toString();
  }

  Future<List<Map<String, dynamic>>> queryUncheckedTasks(String logDate) async {
    late List<Map<String, dynamic>> ret;
    try {
      Database db = await instance.database;
      List<dynamic> whereArguments = [logDate];
      ret = await db.query(taskLogTable,
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
      ret = await db.query(taskLogTable,
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
      ret = await db.query(categoryTable);
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
      ret = await db.query(categoryTable,
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
      ret = await db.query(quoteTable, where: "current = 'Y'");
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
      ret = await db.query(quoteTable);
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
      ret = await db.query(taskLogTable,
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
      ret = await db.query(taskTable);
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

      var query = "select * from tasklog where "
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
      print(s);
    }

    return await maps[0]['defaults'];
  }

  Future<List<Map<String, dynamic>>> queryTasksByCategory(String cat) async {
    late List<Map<String, dynamic>> ret;
    try {
      Database db = await instance.database;
      List<dynamic> whereArguments = [cat];
      ret = await db.query(taskTable,
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
      ret = await db.query(taskTable,
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
      id = await db.insert(quoteTable, row);
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
        .update(taskTable, row, where: '$columnId = ?', whereArgs: [id]);
  }

  // update review
  Future<int> updateReview(String upd) async {
    Database db = await instance.database;
    return await db.rawUpdate(upd);
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
    return await db.delete(taskTable, where: '$columnId = ?', whereArgs: [id]);
  }

  Future<int> deleteByTaskDescription(String taskDescription) async {
    Database db = await instance.database;
    return await db.delete(taskTable,
        where: '$columnTaskDescription = ?', whereArgs: [taskDescription]);
  }

  Future<int> deleteTasks() async {
    Database db = await instance.database;
    return await db.delete(taskTable);
  }

  Future<int> deleteTaskLog() async {
    Database db = await instance.database;
    return await db.delete(taskLogTable);
  }

  Future<int> deleteQuote() async {
    Database db = await instance.database;
    return await db.delete(quoteTable);
  }

  Future<int> deleteCategory() async {
    Database db = await instance.database;
    return await db.delete(categoryTable);
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
    await db.insert(chatTable, {
      chatColumnSender: sender,
      chatColumnContent: content,
      chatColumnTimestamp: DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getChatHistory() async {
    final db = await database;
    return await db.query(chatTable, orderBy: '$chatColumnTimestamp ASC');
  }

  Future<void> deleteOldestChatMessage(int messageId) async {
    final db = await database;
    await db
        .delete(chatTable, where: '$chatColumnId = ?', whereArgs: [messageId]);
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
