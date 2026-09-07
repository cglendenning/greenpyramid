import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/services/db.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _TempPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _TempPathProvider(this.dir);
  final String dir;
  @override
  Future<String?> getApplicationDocumentsPath() async => dir;
}

/// D-046/D-061: regression test for the actual cause of the completion
/// screen's blank-white-screen defect. `queryCategories()` returns
/// `db.query(...)`'s result directly — on the real sqflite plugin this is
/// a read-only list, so `setup_completion_screen.dart`'s and
/// `council_category_picker.dart`'s `snapshot.data!..sort(...)` threw
/// during build, before the Scaffold ever painted a frame. Both screens
/// now copy into a mutable list first — this test pins that the raw
/// result really is unsortable in place (proving the defect was real,
/// not hypothetical) and that copying it first fixes it.
void main() {
  final db = DatabaseHelper.instance;
  late Directory tempDir;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('gp_readonly_query_test');
    PathProviderPlatform.instance = _TempPathProvider(tempDir.path);
  });
  tearDown(() async {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('queryCategories()\'s result cannot be sorted in place — the exact '
      'defect that left the completion screen blank', () async {
    // A single-row sort is a no-op that never actually writes back into
    // the list, so it doesn't trigger the read-only failure — needs at
    // least two rows genuinely out of order for .sort() to attempt a
    // real in-place swap.
    await db.insertCategory({
      DatabaseHelper.columnCategoryId: 1,
      DatabaseHelper.columnCat: 'Health',
      DatabaseHelper.columnPosition: 2,
    });
    await db.insertCategory({
      DatabaseHelper.columnCategoryId: 2,
      DatabaseHelper.columnCat: 'Craft',
      DatabaseHelper.columnPosition: 1,
    });
    final rows = await db.queryCategories();
    expect(
        () => rows.sort((a, b) =>
            (a[DatabaseHelper.columnPosition] as int)
                .compareTo(b[DatabaseHelper.columnPosition] as int)),
        throwsUnsupportedError,
        reason: 'if this ever stops throwing (a sqflite upgrade changing '
            'this behavior), the defensive copy in setup_completion_screen '
            'and council_category_picker becomes unnecessary but is still '
            'harmless — this test existing is what matters, not it passing '
            'forever');
  });

  test('copying into a mutable list first — the actual fix — allows an '
      'in-place sort with no error', () async {
    for (var i = 1; i <= 3; i++) {
      await db.insertCategory({
        DatabaseHelper.columnCategoryId: i,
        DatabaseHelper.columnCat: 'Category $i',
        DatabaseHelper.columnPosition: 4 - i, // reverse, so sort is meaningful
      });
    }
    final rows = await db.queryCategories();
    final mutable = List<Map<String, dynamic>>.from(rows)
      ..sort((a, b) => (a[DatabaseHelper.columnPosition] as int)
          .compareTo(b[DatabaseHelper.columnPosition] as int));
    expect(mutable.map((r) => r[DatabaseHelper.columnCategoryId]), [3, 2, 1]);
  });
}
