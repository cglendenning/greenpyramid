import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('D-151-AC-04: time-scale labels cannot wrap', () {
    final source = File('lib/widgets/pyramid.dart').readAsStringSync();
    expect(source, contains('BoxFit.scaleDown'));
    expect(source, contains('maxLines: 1'));
    expect(source, contains('softWrap: false'));
    for (final label in ['Day', 'Week', 'Month', 'Year']) {
      expect(source, contains("_timeScaleLabel('$label'"));
    }
  });
}
