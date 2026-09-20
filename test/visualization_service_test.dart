import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/services/visualization_service.dart';

void main() {
  test('D-170: local transformation derives honest summary values', () {
    final categories = <VisualizationCategory>[
      VisualizationCategory.fromLogs('Focus', [
        {'checked': 'true'},
        {'checked': 'false'},
      ]),
      VisualizationCategory.fromLogs('Care', [
        {'checked': 'false'},
      ]),
    ];
    final now = DateTime.now();
    final data = VisualizationData(
      categories: categories,
      days: [
        VisualizationDay(
          date: now.subtract(const Duration(days: 6)),
          attempts: 2,
          completed: 1,
        ),
        VisualizationDay(
          date: now.subtract(const Duration(days: 5)),
          attempts: 0,
          completed: 0,
        ),
        VisualizationDay(
          date: now.subtract(const Duration(days: 4)),
          attempts: 1,
          completed: 0,
        ),
        VisualizationDay(
          date: now.subtract(const Duration(days: 3)),
          attempts: 0,
          completed: 0,
        ),
        VisualizationDay(
          date: now.subtract(const Duration(days: 2)),
          attempts: 1,
          completed: 1,
        ),
        VisualizationDay(
          date: now.subtract(const Duration(days: 1)),
          attempts: 1,
          completed: 1,
        ),
        VisualizationDay(date: now, attempts: 1, completed: 0),
      ],
      totalAttempts: 3,
      completedAttempts: 1,
    );

    expect(data.hasData, isTrue);
    expect(data.activeDays, 5);
    expect(data.completionRate, closeTo(33.333, 0.01));
    expect(data.strongest?.name, 'Focus');
    expect(data.careArea?.name, 'Care');
    expect(data.rhythmIsGrowing, isTrue);
  });

  test('D-170: service reads history once and groups it in memory', () {
    final source = File('lib/services/visualization_service.dart').readAsStringSync();
    expect(RegExp(r'queryCategories\(\)').allMatches(source), hasLength(1));
    expect(RegExp(r'queryTaskLogs\(30\)').allMatches(source), hasLength(1));
    expect(source, contains('logsByCategory'));
    expect(source, contains('logsByCategory[name]'));
  });
}
