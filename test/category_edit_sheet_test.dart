import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/widgets/category_edit_sheet.dart';

/// D-113: the shared name+description editor used by both editpyramid.dart
/// and tasklist.dart — previously two separate, inconsistent dialogs that
/// only ever let the person change one field or the other.
void main() {
  testWidgets('D-113: pre-fills both fields with the current name and '
      'description', (tester) async {
    late Future<CategoryEditResult?> result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () {
            result = showCategoryEditSheet(context,
                currentName: 'Health', currentDescription: 'my body carries me');
          },
          child: const Text('Open'),
        ),
      ),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Health'), findsOneWidget);
    expect(find.text('my body carries me'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await result, isNull);
  });

  testWidgets('D-113: a category with no description yet opens with an '
      'empty description field, not a placeholder string', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showCategoryEditSheet(context, currentName: 'Craft'),
          child: const Text('Open'),
        ),
      ),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Craft'), findsOneWidget);
    expect(find.text('Why this category matters to you'), findsOneWidget,
        reason: 'the hint text, shown because the field is genuinely empty');
  });

  testWidgets('D-113: saving returns both the new name and description',
      (tester) async {
    late Future<CategoryEditResult?> result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () {
            result = showCategoryEditSheet(context,
                currentName: 'Health', currentDescription: 'old text');
          },
          child: const Text('Open'),
        ),
      ),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.text('Health'), 'Vitality');
    await tester.enterText(find.text('old text'), 'new text');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final r = await result;
    expect(r?.name, 'Vitality');
    expect(r?.description, 'new text');
  });

  testWidgets('D-113: an empty name cannot be saved — Save is a no-op, the '
      'sheet stays open', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showCategoryEditSheet(context, currentName: 'Health'),
          child: const Text('Open'),
        ),
      ),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.text('Health'), '');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsWidgets,
        reason: 'the sheet is still open — Save silently did nothing');
  });

  testWidgets(
      'D-127: clearing an existing description and saving returns an '
      'empty string, not null — a caller must be able to tell "cleared" '
      'apart from "left untouched"', (tester) async {
    late Future<CategoryEditResult?> result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () {
            result = showCategoryEditSheet(context,
                currentName: 'Health', currentDescription: 'old text');
          },
          child: const Text('Open'),
        ),
      ),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.text('old text'), '');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final r = await result;
    expect(r?.name, 'Health');
    expect(r?.description, '',
        reason: 'a cleared field must round-trip as "", never collapse to '
            'null the way "no description was ever entered" would');
  });

  testWidgets('D-113: an unambiguous DESCRIPTION label, not the internal '
      '"essence" term — found live, the owner called that term confusing: '
      '"it\'s really a subtitle or a description of the category"',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showCategoryEditSheet(context, currentName: 'Health'),
          child: const Text('Open'),
        ),
      ),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('DESCRIPTION'), findsOneWidget);
    expect(find.textContaining('essence', findRichText: true), findsNothing);
  });
}
