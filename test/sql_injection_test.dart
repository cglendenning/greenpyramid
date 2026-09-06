import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Codebase-wide guard against SQL built by string interpolation.
///
/// The shipped app interpolated user-entered category names and habit
/// descriptions — and model-generated task text — directly into SQL at 15
/// sites, including the daily check-off. `setup18.dart` even stripped
/// apostrophes from model output to stop the statement breaking.
///
/// All are now parameterized. This test fails if any comes back.
void main() {
  Iterable<File> allDart() => Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  test('D-024: no SQL statement interpolates a Dart expression', () {
    // A raw* call whose argument contains "${...}" is building SQL from a
    // value rather than binding it. Table and column name constants are the
    // one legitimate use, so they are allowed by name.
    final allowed = RegExp(
        r'\$\{?(get[A-Z]\w*\(\)|column\w+|\w*Table|instance)\b');
    final offenders = <String>[];

    for (final f in allDart()) {
      final lines = f.readAsStringSync().split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (!RegExp(r'\braw(Update|Insert|Delete|Query)\s*\(').hasMatch(lines[i])) {
          continue;
        }
        // Inspect the statement: this line plus the continuation lines.
        for (var j = i; j < lines.length && j < i + 20; j++) {
          final l = lines[j];
          if (!l.contains(r'${')) {
            if (l.contains(');')) break;
            continue;
          }
          final stripped = l.replaceAll(allowed, '');
          if (stripped.contains(r'${')) {
            offenders.add('${f.path}:${j + 1}: ${l.trim()}');
          }
          if (l.contains(');')) break;
        }
      }
    }

    expect(offenders, isEmpty,
        reason: 'SQL must bind its arguments, never interpolate them:\n'
            '${offenders.join('\n')}');
  });

  test('D-024: the apostrophe-stripping workaround is gone', () {
    // setup18.dart mangled model-generated habit text to dodge a quote
    // breaking the SQL. Parameterization removed the need, so the text is no
    // longer degraded.
    final setup18 = File('lib/screens/setup/setup18.dart');
    if (!setup18.existsSync()) return; // deleted by D-001 in a later release
    final body = setup18.readAsStringSync();
    expect(body.contains("replaceAll('\\''"), isFalse);
    expect(body.contains('HACK'), isFalse);
  });
}
