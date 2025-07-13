import 'package:life_ops/db.dart';
import 'package:intl/intl.dart' as intl;

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
}
