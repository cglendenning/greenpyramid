import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:life_ops/services/db.dart';
import 'package:life_ops/theme/app_colors.dart';
import 'package:life_ops/widgets/crossfading_stock_images.dart';

/// Static, local-data visualizations. This screen never calls a model.
class VisualizationsScreen extends StatefulWidget {
  const VisualizationsScreen({super.key});
  @override
  State<VisualizationsScreen> createState() => _VisualizationsScreenState();
}

class _VisualizationsScreenState extends State<VisualizationsScreen> {
  final db = DatabaseHelper.instance;
  late Future<_VizData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_VizData> _load() async {
    final cats = <String>[];
    final values = <double>[];
    final missed = <double>[];
    for (var i = 1; i <= 6; i++) {
      final rows = await db.queryCategory(i);
      final name = rows.isEmpty ? 'Category $i' : rows.first['cat'] as String;
      final logs = (await db.queryTaskLogs(30))
          .where((x) => x['category'] == name)
          .toList();
      final done = logs.where((x) => x['checked'] == 'true').length;
      cats.add(name);
      values.add(logs.isEmpty ? 0 : done * 100 / logs.length);
      missed.add((logs.length - done).toDouble());
    }
    final daily = <_Point>[];
    final logs = await db.queryTaskLogs(7);
    for (var d = 6; d >= 0; d--) {
      final day = DateTime.now().subtract(Duration(days: d));
      final key = day.toIso8601String().substring(0, 10);
      final rows = logs.where((x) => x['taskdate'] == key).toList();
      final done = rows.where((x) => x['checked'] == 'true').length;
      daily.add(_Point(day, rows.isEmpty ? 0 : done * 100 / rows.length));
    }
    return _VizData(cats, values, missed, daily);
  }

  String _best(_VizData d) => d.categories.isEmpty
      ? 'your categories'
      : d.categories[
          d.values.indexOf(d.values.reduce((a, b) => a > b ? a : b))];
  String _weak(_VizData d) => d.categories.isEmpty
      ? 'a category'
      : d.categories[
          d.values.indexOf(d.values.reduce((a, b) => a < b ? a : b))];

  Widget _text(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 20),
      child: Text(text,
          style: const TextStyle(
              color: AppColors.textPrimary, fontSize: 16, height: 1.45)));
  Widget _card(String title, Widget chart) => Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 18, 12, 12),
      decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: .70),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: .05),
                blurRadius: 16,
                offset: const Offset(0, 6))
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        SizedBox(height: 220, child: chart)
      ]));

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: AppColors.background,
      body: FutureBuilder<_VizData>(
          future: _future,
          builder: (context, snap) {
            if (!snap.hasData)
              return const Center(child: CircularProgressIndicator());
            final d = snap.data!;
            return Stack(children: [
              const Positioned.fill(
                  child:
                      Opacity(opacity: .28, child: CrossfadingStockImages())),
              Positioned.fill(
                  child: DecoratedBox(
                      decoration: BoxDecoration(
                          gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                    AppColors.background.withValues(alpha: .22),
                    AppColors.background.withValues(alpha: .72),
                    AppColors.background,
                  ],
                              stops: [
                    0,
                    .38,
                    1
                  ])))),
              ListView(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                  children: [
                    const Text('See your life taking shape.',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontFamily: 'Raleway',
                            fontSize: 29,
                            height: 1.12,
                            fontWeight: FontWeight.w600)),
                    _text(
                        'Your check-ins are small acts of attention. Together, they show where your life is holding, where it is asking for care, and what is beginning to change.'),
                    _card(
                        'Consistency across the week',
                        SfCartesianChart(
                            primaryXAxis: CategoryAxis(),
                            primaryYAxis: NumericAxis(minimum: 0, maximum: 100),
                            series: [
                              SplineAreaSeries<_Point, DateTime>(
                                  dataSource: d.daily,
                                  xValueMapper: (p, _) => p.date,
                                  yValueMapper: (p, _) => p.value,
                                  color: const Color(0xFF5B67F1)
                                      .withValues(alpha: .55))
                            ])),
                    _text(
                        '${_best(d)} is carrying the most momentum right now. Let that strength remind you that change does not have to begin everywhere at once.'),
                    _card(
                        'Where your consistency is weakest',
                        SfCartesianChart(
                            primaryXAxis: CategoryAxis(labelRotation: 35),
                            primaryYAxis: NumericAxis(minimum: 0, maximum: 100),
                            series: [
                              ColumnSeries<_Bar, String>(
                                  dataSource: [
                                    for (var i = 0;
                                        i < d.categories.length;
                                        i++)
                                      _Bar(d.categories[i], d.values[i])
                                  ],
                                  xValueMapper: (p, _) => p.name,
                                  yValueMapper: (p, _) => p.value,
                                  color: const Color(0xFFE58B62),
                                  borderRadius: BorderRadius.circular(8))
                            ])),
                    _text(
                        '${_weak(d)} is asking for the gentlest experiment. Make the next return smaller, clearer, or easier to place in your day.'),
                    _card(
                        'Missed checkboxes',
                        SfCartesianChart(
                            primaryXAxis: CategoryAxis(labelRotation: 35),
                            primaryYAxis: NumericAxis(minimum: 0),
                            series: [
                              BarSeries<_Bar, String>(
                                  dataSource: [
                                    for (var i = 0;
                                        i < d.categories.length;
                                        i++)
                                      _Bar(d.categories[i], d.missed[i]),
                                  ],
                                  xValueMapper: (p, _) => p.name,
                                  yValueMapper: (p, _) => p.value,
                                  color: const Color(0xFFB96B7A),
                                  borderRadius: BorderRadius.circular(8))
                            ])),
                    _text(
                        'A missed checkbox is a useful signal. Notice the conditions around it, then adjust the habit until it supports the person you are actually being.'),
                    _card(
                        'Improvement over time',
                        SfCartesianChart(
                            primaryXAxis: DateTimeAxis(),
                            primaryYAxis: NumericAxis(minimum: 0, maximum: 100),
                            series: [
                              LineSeries<_Point, DateTime>(
                                  dataSource: d.daily,
                                  xValueMapper: (p, _) => p.date,
                                  yValueMapper: (p, _) => p.value,
                                  color: const Color(0xFF4E9B78),
                                  width: 3)
                            ])),
                    _text(
                        'Improvement rarely arrives as a dramatic leap. It appears as a few more returns, repeated often enough to become part of you.'),
                    _text(
                        'Your recent rhythm is the raw material of a life that feels more like your own. Keep choosing the next meaningful checkbox.'),
                    _card(
                        'Completion trend and momentum',
                        SfCartesianChart(
                            primaryXAxis: DateTimeAxis(),
                            primaryYAxis: NumericAxis(minimum: 0, maximum: 100),
                            series: [
                              ColumnSeries<_Point, DateTime>(
                                  dataSource: d.daily,
                                  xValueMapper: (p, _) => p.date,
                                  yValueMapper: (p, _) => p.value,
                                  color: const Color(0xFFDBB45B),
                                  borderRadius: BorderRadius.circular(8))
                            ]))
                  ]),
            ]);
          }));
}

class _VizData {
  final List<String> categories;
  final List<double> values, missed;
  final List<_Point> daily;
  _VizData(this.categories, this.values, this.missed, this.daily);
}

class _Point {
  final DateTime date;
  final double value;
  _Point(this.date, this.value);
}

class _Bar {
  final String name;
  final double value;
  _Bar(this.name, this.value);
}
