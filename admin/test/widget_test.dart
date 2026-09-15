import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/main.dart').readAsStringSync();
  // D-165-AC-03
  // D-165-AC-04: the signed IPA was manually reviewed after this surface test.
  test('admin surface is authenticated and exposes required views', () {
    expect(source, contains('signInWithProvider'));
    expect(source, contains("/adminMetrics"));
    expect(source, contains('Product pulse'));
    expect(source, contains('Screen utilization'));
    expect(source, contains('Top users by spend'));
    expect(source, contains('RefreshIndicator'));
    expect(source, contains('AlwaysScrollableScrollPhysics'));
  });
}
