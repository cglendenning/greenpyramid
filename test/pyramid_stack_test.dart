import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/widgets/pyramid_3d.dart';
import 'package:life_ops/widgets/pyramid_stack.dart';

/// D-151: [PyramidStack] is the single place both the main pyramid screen
/// and the pyramid edit screen build their six blocks — found live, the
/// two screens used to run entirely separate rendering pipelines (the
/// edit screen's own flat, old CustomPainters, never migrated when the
/// main screen was rebuilt on [Pyramid3D]). Unlike either screen, this
/// widget takes its six futures directly and touches no Firebase/DB
/// singleton, so — unlike `pyramid.dart`/`editpyramid.dart` themselves —
/// it's genuinely widget-testable.
void main() {
  Future<dynamic> cat(String name, int pct) async =>
      _FakeCat(cat: name, pctComplete: pct);

  Widget harness({
    required List<Future> futures,
    void Function(int, dynamic)? onCategoryTap,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: PyramidStack(
          cat1Future: futures[0],
          cat2Future: futures[1],
          cat3Future: futures[2],
          cat4Future: futures[3],
          cat5Future: futures[4],
          cat6Future: futures[5],
          size: 300,
          onCategoryTap: onCategoryTap,
        ),
      ),
    );
  }

  testWidgets('before the futures resolve, renders a placeholder pyramid '
      'rather than an empty/loading screen', (tester) async {
    final futures = List.generate(6, (_) => Completer<dynamic>().future);
    await tester.pumpWidget(harness(futures: futures));

    final pyramid = tester.widget<Pyramid3D>(find.byType(Pyramid3D));
    expect(pyramid.categories, hasLength(6));
    expect(pyramid.categories.every((c) => c.label == '...'), isTrue);
  });

  testWidgets('once resolved, each block gets its category\'s real label '
      'and a color derived from its completion percentage — the same '
      'setColor the main pyramid screen uses (D-019)', (tester) async {
    final futures = [
      cat('Craft', 95), // green
      cat('Health', 50), // red
      cat('Family', 60), // yellow
      cat('Faith', -1), // blue, no tasks
      cat('Career', 10),
      cat('Community', 88),
    ];
    await tester.pumpWidget(harness(futures: futures));
    await tester.pumpAndSettle();

    final pyramid = tester.widget<Pyramid3D>(find.byType(Pyramid3D));
    expect(pyramid.categories.map((c) => c.label),
        ['Craft', 'Health', 'Family', 'Faith', 'Career', 'Community']);
    expect(pyramid.categories[0].color, setColor(95));
    expect(pyramid.categories[1].color, setColor(50));
    expect(pyramid.categories[3].color, setColor(-1));
  });

  testWidgets('onCategoryTap is not wired into Pyramid3D at all when the '
      'caller passes none — the pyramid stays non-interactive', (tester) async {
    final futures = List.generate(6, (i) => cat('Cat$i', 50));
    await tester.pumpWidget(harness(futures: futures));
    await tester.pumpAndSettle();

    final pyramid = tester.widget<Pyramid3D>(find.byType(Pyramid3D));
    expect(pyramid.onCategoryTap, isNull);
  });

  testWidgets('Pyramid3D\'s index-only tap is translated into the caller\'s '
      'richer (index, resolved category) callback', (tester) async {
    final futures = [
      cat('Craft', 95),
      cat('Health', 50),
      cat('Family', 60),
      cat('Faith', -1),
      cat('Career', 10),
      cat('Community', 88),
    ];
    int? tappedIndex;
    dynamic tappedCategory;
    await tester.pumpWidget(harness(
      futures: futures,
      onCategoryTap: (index, category) {
        tappedIndex = index;
        tappedCategory = category;
      },
    ));
    await tester.pumpAndSettle();

    final pyramid = tester.widget<Pyramid3D>(find.byType(Pyramid3D));
    expect(pyramid.onCategoryTap, isNotNull);
    pyramid.onCategoryTap!(2);

    expect(tappedIndex, 2);
    expect(tappedCategory.cat, 'Family');
  });
}

class _FakeCat {
  final String cat;
  final int pctComplete;
  const _FakeCat({required this.cat, required this.pctComplete});
}
