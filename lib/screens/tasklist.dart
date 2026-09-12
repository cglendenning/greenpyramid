import 'package:flutter/material.dart';
import 'package:life_ops/services/db.dart';
import 'package:life_ops/screens/edittasklist.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:life_ops/theme/app_colors.dart';
import 'package:life_ops/widgets/category_edit_sheet.dart';
import 'package:life_ops/widgets/navbar.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:life_ops/screens/schedule_habits_screen.dart';
import 'package:life_ops/services/newsfeed_service.dart';
import 'package:life_ops/services/notification.dart';

class TaskList extends StatefulWidget {
  final String category;
  final String taskLogDate;

  const TaskList(this.category, this.taskLogDate);

  @override
  _TaskListState createState() => _TaskListState(category, taskLogDate);
}

class _TaskListState extends State<TaskList> {
  final String category;
  String taskLogDate;
  DateFormat dowFmt = DateFormat('EEEE');
  String todayFmt = '';

  _TaskListState(this.category, this.taskLogDate);
  FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  final dbHelper = DatabaseHelper.instance;

  // D-134: modernized to the app's established dark visual language
  // (AppColors, Exo2) — found live: "I don't like the aesthetics of the
  // links and the functionality within that screen." Previously unstyled
  // (default Material colors), which read as visually inconsistent with
  // the rest of the app.
  var pctCompleteTextStyle = const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      fontFamily: 'Exo2',
      color: AppColors.textSecondary);
  static const _categoryNameStyle = TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      fontFamily: 'Exo2',
      color: AppColors.textPrimary);
  static const _essenceStyle = TextStyle(
      fontSize: 15,
      fontStyle: FontStyle.italic,
      fontFamily: 'Exo2',
      color: AppColors.textSecondary,
      height: 1.4);

  static final ButtonStyle _primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: AppColors.brandGreen,
    foregroundColor: AppColors.background,
    minimumSize: const Size.fromHeight(52),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    elevation: 0,
  );

  static final ButtonStyle _secondaryButtonStyle = OutlinedButton.styleFrom(
    foregroundColor: AppColors.textPrimary,
    side: const BorderSide(color: AppColors.textSecondary),
    minimumSize: const Size.fromHeight(52),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );

  static const _buttonLabelStyle =
      TextStyle(fontFamily: 'Exo2', fontWeight: FontWeight.w600, fontSize: 16);

  Widget _card({required Widget child, EdgeInsetsGeometry? padding}) => Container(
        width: double.infinity,
        padding: padding ?? const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: child,
      );

  late Future<(int?, String?)> _essenceContext;

  @override
  void initState() {
    todayFmt = dowFmt.format(DateTime.now()).toString();
    _essenceContext = _loadEssenceContext();
    super.initState();
  }

  // D-047: the category name and its full essence, in that order, above
  // the habit checkboxes. A category with no essence yet (D-005/D-010)
  // renders neither a placeholder nor a prompt to add one — this returns
  // null and the caller skips the block entirely.
  Future<(int?, String?)> _loadEssenceContext() async {
    final categoryId = await dbHelper.getCategoryIdByName(category);
    if (categoryId == null) return (null, null);
    final essence = await dbHelper.getLatestEssenceForCategory(categoryId);
    return (categoryId, essence);
  }

  // D-113: name and description together, in the same shared sheet
  // editpyramid.dart uses — this used to be "essence" (P-12's internal
  // spec term, never meant for user-facing copy) with no way to touch
  // the category name from here at all. Found live: "wherever I can
  // edit the category, I should also be able to edit the description of
  // the category."
  Future<void> _editCategory(int categoryId, String? currentEssence) async {
    final result = await showCategoryEditSheet(
      context,
      currentName: category,
      currentDescription: currentEssence,
    );
    if (result == null) return;

    if (result.name != category) {
      await dbHelper.renameCategoryCascading(
          categoryid: categoryId, newName: result.name);
    }
    // D-127: compare against what was actually loaded, not against
    // null/empty — an intentionally-cleared description is itself a
    // change and must be persisted, not skipped because it's blank.
    if (result.description != (currentEssence ?? '')) {
      // D-061: essences are versioned, never overwritten — this appends
      // a new version rather than updating the existing row.
      await dbHelper.insertCategoryEssence(
          categoryId: categoryId, essence: result.description);
    }

    if (result.name != category) {
      // `category` drives every task/task-log query on this screen —
      // rather than live-patching every downstream reference to a new
      // name, pop back so the caller re-navigates fresh.
      if (mounted) Navigator.of(context).pop();
      return;
    }
    setState(() => _essenceContext = _loadEssenceContext());
  }

  @override
  Widget build(BuildContext context) {
    analytics.logEvent(name: 'tasklist');
    return SafeArea(
        child: Scaffold(
            backgroundColor: AppColors.background,
            appBar: const NavBar(),
            body: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  Center(child: Text(category, style: _categoryNameStyle)),
                  const SizedBox(height: 16),
                  FutureBuilder<(int?, String?)>(
                    future: _essenceContext,
                    builder: (context, snapshot) {
                      final data = snapshot.data;
                      // D-113: a category with no description yet still
                      // gets the Edit action — previously the whole block
                      // (name-editing included) was hidden whenever no
                      // essence existed, D-005/D-010's normal state for
                      // essential/peak categories.
                      if (data == null || data.$1 == null) {
                        return const SizedBox.shrink();
                      }
                      final categoryId = data.$1!;
                      final essence = data.$2;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: _card(
                          child: Column(
                            children: [
                              if (essence != null)
                                Text(essence,
                                    textAlign: TextAlign.center, style: _essenceStyle),
                              if (essence != null) const SizedBox(height: 12),
                              TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.brandGreen,
                                  padding: EdgeInsets.zero,
                                ),
                                onPressed: () => _editCategory(categoryId, essence),
                                child: const Text('Edit'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  FutureBuilder(
                      future: getTaskLog(),
                      builder: (context, AsyncSnapshot snapshot) {
                        if (!snapshot.hasData) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                                child: CircularProgressIndicator(
                                    color: AppColors.brandGreen)),
                          );
                        } else {
                          return _card(
                            padding: EdgeInsets.zero,
                            child: SizedBox(
                              // D-145: a fixed height, not just a max —
                              // found live, a jarring layout shift: with
                              // shrinkWrap the card (and everything below
                              // it, including the buttons) sized itself to
                              // however many tasks a given category had,
                              // so switching dates to a category with a
                              // different task count moved the buttons up
                              // or down the screen. A fixed height keeps
                              // every element below in exactly the same
                              // place regardless of task count; a category
                              // with too few tasks to fill it just leaves
                              // empty space in the card instead.
                              //
                              // D-147: that fixed height was one third of
                              // the *screen* — found live, this pushed the
                              // calendar (which sits below the buttons,
                              // further down this same column) off the
                              // bottom of the screen entirely on every
                              // category. A small constant is enough to
                              // show several tasks with the scrollbar
                              // handling any overflow, and leaves the
                              // calendar visible without scrolling.
                              //
                              // D-153: trimmed further, 220 -> 180 —
                              // found live again: even the D-147 constant
                              // still left the calendar requiring a
                              // scroll on typical phone screens once the
                              // essence card and both buttons were
                              // accounted for. Still comfortably shows
                              // 2-3 tasks with the scrollbar taking any
                              // overflow beyond that.
                              height: 180,
                              // D-153: an always-visible thumb, not just
                              // one that appears while actively dragging
                              // — "the card ... should display a scroll
                              // bar, if the tasks scroll beyond the
                              // screen." Scrollbar never draws a thumb at
                              // all when the content already fits, so
                              // this is a no-op for a short task list.
                              child: Scrollbar(
                                  thumbVisibility: true,
                                  child: ListView.separated(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      itemCount: snapshot.data.length,
                                      separatorBuilder: (context, index) => Divider(
                                          height: 1,
                                          color: Colors.white.withValues(alpha: 0.08)),
                                      itemBuilder:
                                          (BuildContext context, int index) {
                                        final task = snapshot.data[index];
                                        return CheckboxListTile(
                                            controlAffinity:
                                                ListTileControlAffinity.leading,
                                            activeColor: AppColors.brandGreen,
                                            checkColor: AppColors.background,
                                            title: Text(
                                                '${task.taskdescription}',
                                                style: const TextStyle(
                                                    color: AppColors.textPrimary,
                                                    fontFamily: 'Exo2')),
                                            value: toBoolean(task.checked),
                                            onChanged: (bool? value) {
                                              setState(() {
                                                task.checked = value.toString();
                                                dbHelper.setTaskLogChecked(
                                                  category: task.category,
                                                  taskDescription:
                                                      task.taskdescription,
                                                  taskDate: task.taskdate,
                                                  checked: value ?? false,
                                                );
                                              });
                                              // D-154: checking a task off
                                              // is exactly the moment a
                                              // streak can newly cross a
                                              // milestone — generate and
                                              // notify right here, rather
                                              // than only checking when
                                              // the newsfeed screen itself
                                              // happens to be opened.
                                              _notifyNewsfeed();
                                            });
                                      })),
                            ),
                          );
                        }
                      }),
                  const SizedBox(height: 16),
                  // D-153: side by side, not stacked — found live: "you
                  // could probably take the two buttons and rather than
                  // having them stack on top of each other vertically,
                  // they could align on a single row horizontally that
                  // might save some space" — frees up the vertical room
                  // that was pushing the date picker below the fold.
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            navigateToEditTaskList();
                          },
                          style: _primaryButtonStyle,
                          child: const Text('Edit Task List', style: _buttonLabelStyle),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // D-123: schedule a habit's recurring time — a
                      // separate screen since it works across every
                      // category's habits at once, not just this one.
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const ScheduleHabitsScreen()),
                            );
                          },
                          style: _secondaryButtonStyle,
                          child: const Text('Schedule Habits', style: _buttonLabelStyle),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _card(
                    child: CupertinoTheme(
                      data: const CupertinoThemeData(brightness: Brightness.dark),
                      child: SizedBox(
                        height: 80,
                        child: CupertinoDatePicker(
                          key: UniqueKey(),
                          mode: CupertinoDatePickerMode.date,
                          minimumDate:
                              DateFormat("yyyy-MM-dd").parse("2023-06-01"),
                          maximumDate: DateTime.now(),
                          showDayOfWeek: true,
                          dateOrder: DatePickerDateOrder.dmy,
                          initialDateTime:
                              DateFormat("yyyy-MM-dd").parse(taskLogDate),
                          onDateTimeChanged: (DateTime newDateTime) {
                            setState(() {
                              DateFormat formatter = DateFormat('yyyy-MM-dd');
                              taskLogDate = formatter.format(newDateTime);
                              todayFmt = dowFmt.format(newDateTime).toString();
                            });
                            // Do something
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder(
                      future: combined(7),
                      builder: (context, AsyncSnapshot snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(child: Text(''));
                        } else {
                          // if there are no tasks at all, getCompletionPercentage()
                          // will return -1.
                          if (snapshot.data == -1) {
                            return const Center(child: Text(''));
                          } else {
                            return Center(
                                child: Text(
                                    '${snapshot.data.toString()} Percent Complete (7 days)',
                                    style: pctCompleteTextStyle));
                          }
                        }
                      }),
                  const SizedBox(height: 8),
                  FutureBuilder(
                      future: combined(30),
                      builder: (context, AsyncSnapshot snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                              child: Text(
                                  'Tap "Edit Task List" to add tasks.',
                                  style: TextStyle(color: AppColors.textSecondary)));
                        } else {
                          // if there are no tasks at all, getCompletionPercentage()
                          // will return -1.
                          if (snapshot.data == -1) {
                            return const Center(
                                child: Text(
                                    'Tap "Edit Task List" to add tasks.',
                                    style: TextStyle(color: AppColors.textSecondary)));
                          } else {
                            return Center(
                                child: Text(
                                    '${snapshot.data.toString()} Percent Complete (30 days)',
                                    style: pctCompleteTextStyle));
                          }
                        }
                      }),
                ]))));
  }

  // D-154: fires a local notification for each genuinely new newsfeed
  // item (a streak milestone just reached) — never for the seeded
  // welcome cards or an already-recorded milestone, since
  // NewsfeedService.generateNewItems only returns real, new ones.
  Future<void> _notifyNewsfeed() async {
    final newItems = await NewsfeedService.instance.generateNewItems();
    for (final item in newItems) {
      await LocalNotificationService().showNewsfeedItemNotification(
        title: item.title,
        body: item.body,
        dedupeKey: item.dedupeKey,
      );
    }
  }

  void navigateToEditTaskList() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditTaskList(category)),
    );
    setState(() {
      // _taskLogFuture = getTaskLog();
    });
  }

  Future<List<TaskLog>> getTaskLog() async {
    // Is there a row for this category and date in tasklog?
    final List<Map<String, dynamic>> taskLogCount =
        await dbHelper.queryTaskLogByCategory(category, taskLogDate);

    // if there is no row for this category and date in tasklog,
    // insert one only if the day of week is not blacked out in task.

    if (taskLogCount.isEmpty) {
      dbHelper.insertTaskLogForCategory(category, taskLogDate, todayFmt);
    }

    // second pull now that there are rows.
    final List<Map<String, dynamic>> maps =
        await dbHelper.queryTaskLogByCategory(category, taskLogDate);

    // Convert the List<Map<String, dynamic> into a List<Task>.
    return List.generate(maps.length, (i) {
      return TaskLog(
          id: maps[i]['id'],
          category: maps[i]['category'],
          taskdescription: maps[i]['taskdescription'],
          checked: maps[i]['checked'],
          taskdate: maps[i]['taskdate']);
    });
  }

  Future<List<Task>> getTaskDetails(String cat, String desc) async {
    final List<Map<String, dynamic>> maps =
        await dbHelper.querySingleTask(cat, desc);

    // Convert the List<Map<String, dynamic> into a List<Task>.
    return List.generate(maps.length, (i) {
      return Task(
          id: maps[i]['id'],
          category: maps[i]['category'],
          taskdescription: maps[i]['taskdescription'],
          sunday: maps[i]['sunday'],
          monday: maps[i]['monday'],
          tuesday: maps[i]['tuesday'],
          wednesday: maps[i]['wednesday'],
          thursday: maps[i]['thursday'],
          friday: maps[i]['friday'],
          saturday: maps[i]['saturday']);
    });
  }

  // Using the technique from here because getTaskLog() was
  // being called after getCompletionPercentage() when flipping
  // to a new date.
  // https://stackoverflow.com/questions/68067710/using-a-futurebuilder-with-one-future-depends-on-the-results-on-the-other-future
  Future<int> combined(int days) async {
    // List<TaskLog> t = await getTaskLog();
    return dbHelper.getCompletionPercentage(category, days);
  }

  bool toBoolean(String s) {
    return s != '0' && s != 'false' && s != '';
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
