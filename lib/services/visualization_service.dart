import 'db.dart';

/// Builds the local data used by the swipeable Analysis journey.
///
/// The service reads the category list and recent history once. The screen
/// only decides how to tell the story; it does not scan collections or
/// calculate chart data during build.
class VisualizationService {
  VisualizationService({DatabaseHelper? db})
      : _db = db ?? DatabaseHelper.instance;

  static final VisualizationService instance = VisualizationService();

  final DatabaseHelper _db;

  Future<VisualizationData> load() async {
    final categoryRows = await _db.queryCategories();
    final logs = await _db.queryTaskLogs(30);
    final names = <String>[];

    for (final row in categoryRows) {
      final name = (row[DatabaseHelper.columnCat] as String? ?? '').trim();
      if (name.isEmpty || name.startsWith('Empty') || names.contains(name)) {
        continue;
      }
      names.add(name);
    }

    final logsByCategory = <String, List<Map<String, dynamic>>>{
      for (final name in names) name: <Map<String, dynamic>>[],
    };
    for (final log in logs) {
      final category = log[DatabaseHelper.columnTLCategory] as String?;
      logsByCategory[category]?.add(log);
    }

    final categories = names
        .map(
          (name) => VisualizationCategory.fromLogs(
            name,
            logsByCategory[name] ?? const <Map<String, dynamic>>[],
          ),
        )
        .toList(growable: false);

    final now = DateTime.now();
    final days = <VisualizationDay>[];
    for (var offset = 6; offset >= 0; offset--) {
      final date = now.subtract(Duration(days: offset));
      final key = date.toIso8601String().substring(0, 10);
      final dayLogs = logs
          .where((log) => log[DatabaseHelper.columnTLTaskDate] == key)
          .toList(growable: false);
      final completed = dayLogs
          .where((log) => log[DatabaseHelper.columnTLChecked] == 'true')
          .length;
      days.add(
        VisualizationDay(
          date: date,
          attempts: dayLogs.length,
          completed: completed,
        ),
      );
    }

    return VisualizationData(
      categories: categories,
      days: days,
      totalAttempts: logs.length,
      completedAttempts: logs
          .where((log) => log[DatabaseHelper.columnTLChecked] == 'true')
          .length,
    );
  }
}

class VisualizationData {
  const VisualizationData({
    required this.categories,
    required this.days,
    required this.totalAttempts,
    required this.completedAttempts,
  });

  final List<VisualizationCategory> categories;
  final List<VisualizationDay> days;
  final int totalAttempts;
  final int completedAttempts;

  bool get hasData => totalAttempts > 0;
  int get activeDays => days.where((day) => day.attempts > 0).length;

  double get completionRate =>
      totalAttempts == 0 ? 0 : completedAttempts * 100 / totalAttempts;

  VisualizationCategory? get strongest => _categoryWithData((a, b) {
        return a.rate >= b.rate ? a : b;
      });

  VisualizationCategory? get careArea => _categoryWithData((a, b) {
        return a.rate <= b.rate ? a : b;
      });

  VisualizationCategory? _categoryWithData(
    VisualizationCategory Function(
      VisualizationCategory,
      VisualizationCategory,
    ) choose,
  ) {
    final withData = categories.where((category) => category.attempts > 0);
    if (withData.isEmpty) return null;
    return withData.reduce(choose);
  }

  int get earlyWeekCompleted =>
      days.take(3).fold(0, (total, day) => total + day.completed);

  int get lateWeekCompleted =>
      days.skip(4).fold(0, (total, day) => total + day.completed);

  bool get rhythmIsGrowing => lateWeekCompleted > earlyWeekCompleted;

  bool get rhythmIsHolding => lateWeekCompleted == earlyWeekCompleted;
}

class VisualizationCategory {
  const VisualizationCategory({
    required this.name,
    required this.attempts,
    required this.completed,
  });

  factory VisualizationCategory.fromLogs(
    String name,
    List<Map<String, dynamic>> logs,
  ) {
    return VisualizationCategory(
      name: name,
      attempts: logs.length,
      completed: logs
          .where((log) => log[DatabaseHelper.columnTLChecked] == 'true')
          .length,
    );
  }

  final String name;
  final int attempts;
  final int completed;

  double get rate => attempts == 0 ? 0 : completed * 100 / attempts;
  int get roundedRate => rate.round();
}

class VisualizationDay {
  const VisualizationDay({
    required this.date,
    required this.attempts,
    required this.completed,
  });

  final DateTime date;
  final int attempts;
  final int completed;

  double get rate => attempts == 0 ? 0 : completed / attempts;

  String get label =>
      const <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'][date.weekday - 1];
}
