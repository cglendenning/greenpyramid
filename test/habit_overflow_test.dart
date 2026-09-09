import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D-122: a habit that runs past the model's own length guidance is
/// truncated gracefully with an ellipsis instead of hard-clipped
/// mid-word by the chip's edge — structural, matching this repo's
/// convention for setup_screen.dart.
void main() {
  test(
      'D-122: the habit chip bounds its width and lets Text handle '
      'overflow with an ellipsis — regression test for a defect found '
      'live: a habit longer than the model\'s own length guidance was '
      'hard-clipped mid-word with no visual sign anything was cut off',
      () {
    final source = File('lib/screens/setup_screen.dart').readAsStringSync();
    final start = source.indexOf('Widget _buildHabits()');
    expect(start, greaterThan(-1));
    final end = source.indexOf('\n  Widget _buildTextInput()', start);
    expect(end, greaterThan(start));
    final body = source.substring(start, end);

    expect(body, contains('ConstrainedBox('));
    expect(body, contains('TextOverflow.ellipsis'));
    expect(body, contains('maxLines: 1'));
  });
}
