import 'package:life_ops/services/db.dart';
import 'package:intl/intl.dart' as intl;
import 'dart:math';

class DBTools {
  final dbHelper = DatabaseHelper.instance;
  final physical = 'Physical Health';
  final mental = 'Mindset';
  final financial = 'Financial Health';
  final father = 'Father';
  final spouse = 'Spouse';
  final flow = 'Flow';

  final intl.DateFormat formatter = intl.DateFormat('yyyy-MM-dd');

// -----------------------------------------------------------------------------
//                                                               populateTasks()
// -----------------------------------------------------------------------------

  void populateTasks() async {
    // row to insert
    Map<String, dynamic> taskRow = {
      DatabaseHelper.columnCategory: physical,
      DatabaseHelper.columnTaskDescription: 'Hip Mobility',
      DatabaseHelper.columnCreateDate:
          formatter.format(DateTime.now()).toString()
    };
    await dbHelper.insertTask(taskRow);

    // row to insert
    taskRow = {
      DatabaseHelper.columnCategory: physical,
      DatabaseHelper.columnTaskDescription: 'Shoulder Mobility',
      DatabaseHelper.columnCreateDate:
          formatter.format(DateTime.now()).toString()
    };
    await dbHelper.insertTask(taskRow);

    // row to insert
    taskRow = {
      DatabaseHelper.columnCategory: physical,
      DatabaseHelper.columnTaskDescription: 'CrossFit',
      DatabaseHelper.columnCreateDate:
          formatter.format(DateTime.now()).toString()
    };
    await dbHelper.insertTask(taskRow);

    // row to insert
    taskRow = {
      DatabaseHelper.columnCategory: mental,
      DatabaseHelper.columnTaskDescription: 'Box Breathing',
      DatabaseHelper.columnCreateDate:
          formatter.format(DateTime.now()).toString()
    };
    await dbHelper.insertTask(taskRow);

    // row to insert
    taskRow = {
      DatabaseHelper.columnCategory: mental,
      DatabaseHelper.columnTaskDescription: 'Gratitude Journal',
      DatabaseHelper.columnCreateDate:
          formatter.format(DateTime.now()).toString()
    };
    await dbHelper.insertTask(taskRow);

    // row to insert
    taskRow = {
      DatabaseHelper.columnCategory: mental,
      DatabaseHelper.columnTaskDescription: 'Walk In Nature',
      DatabaseHelper.columnCreateDate:
          formatter.format(DateTime.now()).toString()
    };
    await dbHelper.insertTask(taskRow);

    // row to insert
    taskRow = {
      DatabaseHelper.columnCategory: financial,
      DatabaseHelper.columnTaskDescription: 'Review Budget',
      DatabaseHelper.columnCreateDate:
          formatter.format(DateTime.now()).toString()
    };
    await dbHelper.insertTask(taskRow);

    // row to insert
    taskRow = {
      DatabaseHelper.columnCategory: financial,
      DatabaseHelper.columnTaskDescription: 'Business Dev',
      DatabaseHelper.columnCreateDate:
          formatter.format(DateTime.now()).toString()
    };
    await dbHelper.insertTask(taskRow);

    // row to insert
    taskRow = {
      DatabaseHelper.columnCategory: financial,
      DatabaseHelper.columnTaskDescription: 'Business Ops',
      DatabaseHelper.columnCreateDate:
          formatter.format(DateTime.now()).toString()
    };
    await dbHelper.insertTask(taskRow);

    // row to insert
    taskRow = {
      DatabaseHelper.columnCategory: father,
      DatabaseHelper.columnTaskDescription: 'Play With Kids',
      DatabaseHelper.columnCreateDate:
          formatter.format(DateTime.now()).toString()
    };
    await dbHelper.insertTask(taskRow);

    // row to insert
    taskRow = {
      DatabaseHelper.columnCategory: father,
      DatabaseHelper.columnTaskDescription: 'Teach Kids',
      DatabaseHelper.columnCreateDate:
          formatter.format(DateTime.now()).toString()
    };
    await dbHelper.insertTask(taskRow);

    // row to insert
    taskRow = {
      DatabaseHelper.columnCategory: spouse,
      DatabaseHelper.columnTaskDescription: 'Send Encouraging Text',
      DatabaseHelper.columnCreateDate:
          formatter.format(DateTime.now()).toString()
    };
    await dbHelper.insertTask(taskRow);

    // row to insert
    taskRow = {
      DatabaseHelper.columnCategory: spouse,
      DatabaseHelper.columnTaskDescription: 'Quality Time',
      DatabaseHelper.columnCreateDate:
          formatter.format(DateTime.now()).toString()
    };
    await dbHelper.insertTask(taskRow);

    // row to insert
    taskRow = {
      DatabaseHelper.columnCategory: flow,
      DatabaseHelper.columnTaskDescription: 'Mountain Biking',
      DatabaseHelper.columnCreateDate:
          formatter.format(DateTime.now()).toString()
    };
    await dbHelper.insertTask(taskRow);
  }

// -----------------------------------------------------------------------------
//                                                             populateTaskLog()
// -----------------------------------------------------------------------------

  void populateTaskLog() async {
    // TODO: Modify to pull from the task table and randomly set checkboxes

    // row to insert
    Map<String, dynamic> taskLogRow = {
      DatabaseHelper.columnTLCategory: physical,
      DatabaseHelper.columnTLTaskDescription: 'Hip Mobility',
      DatabaseHelper.columnTLChecked: 'false',
      DatabaseHelper.columnTLTaskDate:
          formatter.format(DateTime.now()).toString()
    };
    await dbHelper.insertTaskLog(taskLogRow);

    // row to insert
    taskLogRow = {
      DatabaseHelper.columnTLCategory: physical,
      DatabaseHelper.columnTLTaskDescription: 'Shoulder Mobility',
      DatabaseHelper.columnTLChecked: 'true',
      DatabaseHelper.columnTLTaskDate:
          formatter.format(DateTime.now()).toString()
    };
    await dbHelper.insertTaskLog(taskLogRow);

    // row to insert
    taskLogRow = {
      DatabaseHelper.columnTLCategory: physical,
      DatabaseHelper.columnTLTaskDescription: 'CrossFit',
      DatabaseHelper.columnTLChecked: 'false',
      DatabaseHelper.columnTLTaskDate:
          formatter.format(DateTime.now()).toString()
    };
    await dbHelper.insertTaskLog(taskLogRow);

    // row to insert
    taskLogRow = {
      DatabaseHelper.columnTLCategory: physical,
      DatabaseHelper.columnTLTaskDescription: 'Hip Mobility',
      DatabaseHelper.columnTLChecked: 'true',
      DatabaseHelper.columnTLTaskDate: formatter
          .format(DateTime.now().subtract(const Duration(days: 2)))
          .toString()
    };
    await dbHelper.insertTaskLog(taskLogRow);

    // row to insert
    taskLogRow = {
      DatabaseHelper.columnTLCategory: physical,
      DatabaseHelper.columnTLTaskDescription: 'Hip Mobility',
      DatabaseHelper.columnTLChecked: 'false',
      DatabaseHelper.columnTLTaskDate: formatter
          .format(DateTime.now().subtract(const Duration(days: 1)))
          .toString()
    };
    await dbHelper.insertTaskLog(taskLogRow);

    // row to insert
    taskLogRow = {
      DatabaseHelper.columnTLCategory: physical,
      DatabaseHelper.columnTLTaskDescription: 'Shoulder Mobility',
      DatabaseHelper.columnTLChecked: 'false',
      DatabaseHelper.columnTLTaskDate: formatter
          .format(DateTime.now().subtract(const Duration(days: 1)))
          .toString()
    };
    await dbHelper.insertTaskLog(taskLogRow);

    // row to insert
    taskLogRow = {
      DatabaseHelper.columnTLCategory: physical,
      DatabaseHelper.columnTLTaskDescription: 'Shoulder Mobility',
      DatabaseHelper.columnTLChecked: 'false',
      DatabaseHelper.columnTLTaskDate: formatter
          .format(DateTime.now().subtract(const Duration(days: 2)))
          .toString()
    };
    await dbHelper.insertTaskLog(taskLogRow);

    // row to insert
    taskLogRow = {
      DatabaseHelper.columnTLCategory: physical,
      DatabaseHelper.columnTLTaskDescription: 'CrossFit',
      DatabaseHelper.columnTLChecked: 'true',
      DatabaseHelper.columnTLTaskDate: formatter
          .format(DateTime.now().subtract(const Duration(days: 2)))
          .toString()
    };
    await dbHelper.insertTaskLog(taskLogRow);

    // row to insert
    taskLogRow = {
      DatabaseHelper.columnTLCategory: mental,
      DatabaseHelper.columnTLTaskDescription: 'Box Breathing',
      DatabaseHelper.columnTLChecked: 'true',
      DatabaseHelper.columnTLTaskDate:
          formatter.format(DateTime.now()).toString()
    };
    await dbHelper.insertTaskLog(taskLogRow);

    // row to insert
    taskLogRow = {
      DatabaseHelper.columnTLCategory: mental,
      DatabaseHelper.columnTLTaskDescription: 'Gratitude Journal',
      DatabaseHelper.columnTLChecked: 'true',
      DatabaseHelper.columnTLTaskDate:
          formatter.format(DateTime.now()).toString()
    };
    await dbHelper.insertTaskLog(taskLogRow);

    // row to insert
    taskLogRow = {
      DatabaseHelper.columnTLCategory: mental,
      DatabaseHelper.columnTLTaskDescription: 'Walk In Nature',
      DatabaseHelper.columnTLChecked: 'false',
      DatabaseHelper.columnTLTaskDate:
          formatter.format(DateTime.now()).toString()
    };
    await dbHelper.insertTaskLog(taskLogRow);

    // row to insert
    taskLogRow = {
      DatabaseHelper.columnTLCategory: mental,
      DatabaseHelper.columnTLTaskDescription: 'Box Breathing',
      DatabaseHelper.columnTLChecked: 'false',
      DatabaseHelper.columnTLTaskDate: formatter
          .format(DateTime.now().subtract(const Duration(days: 2)))
          .toString()
    };
    await dbHelper.insertTaskLog(taskLogRow);

    // row to insert
    taskLogRow = {
      DatabaseHelper.columnTLCategory: mental,
      DatabaseHelper.columnTLTaskDescription: 'Gratitude Journal',
      DatabaseHelper.columnTLChecked: 'true',
      DatabaseHelper.columnTLTaskDate: formatter
          .format(DateTime.now().subtract(const Duration(days: 2)))
          .toString()
    };
    await dbHelper.insertTaskLog(taskLogRow);

    // row to insert
    taskLogRow = {
      DatabaseHelper.columnTLCategory: mental,
      DatabaseHelper.columnTLTaskDescription: 'Walk In Nature',
      DatabaseHelper.columnTLChecked: 'true',
      DatabaseHelper.columnTLTaskDate: formatter
          .format(DateTime.now().subtract(const Duration(days: 2)))
          .toString()
    };
    await dbHelper.insertTaskLog(taskLogRow);

    // row to insert
    taskLogRow = {
      DatabaseHelper.columnTLCategory: financial,
      DatabaseHelper.columnTLTaskDescription: 'Review Budget',
      DatabaseHelper.columnTLChecked: 'false',
      DatabaseHelper.columnTLTaskDate:
          formatter.format(DateTime.now()).toString()
    };
    await dbHelper.insertTaskLog(taskLogRow);

    // row to insert
    taskLogRow = {
      DatabaseHelper.columnTLCategory: financial,
      DatabaseHelper.columnTLTaskDescription: 'Business Dev',
      DatabaseHelper.columnTLChecked: 'true',
      DatabaseHelper.columnTLTaskDate:
          formatter.format(DateTime.now()).toString()
    };
    await dbHelper.insertTaskLog(taskLogRow);

    // row to insert
    taskLogRow = {
      DatabaseHelper.columnTLCategory: financial,
      DatabaseHelper.columnTLTaskDescription: 'Business Ops',
      DatabaseHelper.columnTLChecked: 'true',
      DatabaseHelper.columnTLTaskDate:
          formatter.format(DateTime.now()).toString()
    };
    await dbHelper.insertTaskLog(taskLogRow);

    // row to insert
    taskLogRow = {
      DatabaseHelper.columnTLCategory: father,
      DatabaseHelper.columnTLTaskDescription: 'Throw The Football',
      DatabaseHelper.columnTLChecked: 'true',
      DatabaseHelper.columnTLTaskDate:
          formatter.format(DateTime.now()).toString()
    };
    await dbHelper.insertTaskLog(taskLogRow);

    // row to insert
    taskLogRow = {
      DatabaseHelper.columnTLCategory: father,
      DatabaseHelper.columnTLTaskDescription: 'Teach Kids',
      DatabaseHelper.columnTLChecked: 'false',
      DatabaseHelper.columnTLTaskDate:
          formatter.format(DateTime.now()).toString()
    };
    await dbHelper.insertTaskLog(taskLogRow);

    // row to insert
    taskLogRow = {
      DatabaseHelper.columnTLCategory: spouse,
      DatabaseHelper.columnTLTaskDescription: 'Text spouse',
      DatabaseHelper.columnTLChecked: 'false',
      DatabaseHelper.columnTLTaskDate:
          formatter.format(DateTime.now()).toString()
    };
    await dbHelper.insertTaskLog(taskLogRow);
  }

  /// Populates the database with compelling demo data for all categories and tasks, and 30 days of random completion logs.
  Future<void> populateDemoData() async {
    print('[DEMO] populateDemoData called. isDemoMode=${DatabaseHelper.isDemoMode}');
    final db = dbHelper;
    final now = DateTime.now();
    final categories = [
      {'id': 1, 'cat': 'Health'},
      {'id': 2, 'cat': 'Mindset'},
      {'id': 3, 'cat': 'Wealth'},
      {'id': 4, 'cat': 'Parent'},
      {'id': 5, 'cat': 'Spouse'},
      {'id': 6, 'cat': 'Business'},
    ];
    final tasks = {
      'Health': [
        'Morning Yoga',
        'Drink 2L Water',
        '10,000 Steps',
      ],
      'Mindset': [
        'Meditate 10 min',
        'Gratitude Journal',
        'Read 10 pages',
      ],
      'Wealth': [
        'Invest \$10',
        'Track Expenses',
        'Review Budget',
      ],
      'Parent': [
        'Family Dinner',
        'Help with Homework',
        'Read to Kids',
      ],
      'Spouse': [
        'Date Night',
        'Compliment Spouse',
        'Share a Meal',
      ],
      'Business': [
        'Plan Tomorrow',
        'Email Follow-ups',
        'Review Goals',
      ],
    };

    // 1. Clear existing data
    await db.deleteCategory();
    await db.deleteTasks();
    await db.deleteTaskLog();

    // 2. Insert categories
    for (var cat in categories) {
      print('[DEMO] Inserting demo category: id=${cat['id']} cat=${cat['cat']}');
      await db.insertCategory({
        DatabaseHelper.columnCategoryId: cat['id'],
        DatabaseHelper.columnCat: cat['cat'],
      });
    }
    print('[DEMO] Finished inserting demo categories.');

    // 3. Insert tasks
    int taskId = 1;
    for (var cat in categories) {
      final catName = cat['cat'] as String;
      for (var taskDesc in tasks[catName]!) {
        await db.insertTask({
          DatabaseHelper.columnId: taskId,
          DatabaseHelper.columnCategory: catName,
          DatabaseHelper.columnTaskDescription: taskDesc,
          DatabaseHelper.columnSunday: 'true',
          DatabaseHelper.columnMonday: 'true',
          DatabaseHelper.columnTuesday: 'true',
          DatabaseHelper.columnWednesday: 'true',
          DatabaseHelper.columnThursday: 'true',
          DatabaseHelper.columnFriday: 'true',
          DatabaseHelper.columnSaturday: 'true',
          DatabaseHelper.columnCreateDate: now.toIso8601String(),
        });
        taskId++;
      }
    }
    print('[DEMO] Finished inserting demo tasks.');

    // 4. Insert 30 days of random completion logs for each task
    final allTasks = await db.queryAllTasks();
    final rand = Random();
    for (int dayOffset = 0; dayOffset < 60; dayOffset++) {
      final date = now.subtract(Duration(days: dayOffset));
      final dateStr = intl.DateFormat('yyyy-MM-dd').format(date);
      for (var task in allTasks) {
        final completed = rand.nextDouble() < 0.75;
        await db.insertTaskLog({
          DatabaseHelper.columnTLCategory: task[DatabaseHelper.columnCategory],
          DatabaseHelper.columnTLTaskDescription: task[DatabaseHelper.columnTaskDescription],
          DatabaseHelper.columnTLChecked: completed ? 'true' : 'false',
          DatabaseHelper.columnTLTaskDate: dateStr,
        });
      }
    }
    print('[DEMO] Finished inserting demo task logs.');
    // Print out the demo categories for verification
    final demoCats = await db.queryCategories();
    print('[DEMO] Demo categories in table: $demoCats');
  }
}
