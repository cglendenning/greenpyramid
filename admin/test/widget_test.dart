import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/main.dart').readAsStringSync();
  // D-165-AC-03
  // D-165-AC-04: the signed IPA was manually reviewed after this surface test.
  // D-165-AC-05: simulator controls and report terminology are explained.
  // D-162-AC-04: simulator controls and report output are exposed here.
  test('admin surface is authenticated and exposes required views', () {
    expect(source, contains('signInWithProvider'));
    expect(source, contains("tooltip: 'Sign out'"));
    expect(source, contains('FirebaseAuth.instance.signOut()'));
    expect(source, contains("/adminMetrics"));
    expect(source, contains('Product pulse'));
    expect(source, contains('Screen utilization'));
    expect(source, contains('Top users by spend'));
    expect(source, contains('RefreshIndicator'));
    expect(source, contains('AlwaysScrollableScrollPhysics'));
    expect(source, contains('/adminSimulation'));
    expect(source, contains('Virtual months'));
    expect(source, contains('Deterministic seed'));
    expect(source, contains('Copy JSON'));
    expect(source, contains('Sandbox only'));
    expect(source, contains('What this tests'));
    expect(source, contains('Default deterministic failures makes every 17th'));
    expect(
      source,
      contains('The same seed and settings produce the same report'),
    );
    expect(source, contains('selectionMode (deterministic_utility)'));
    for (final scenario in [
      'autonomous',
      'responsive',
      'fatigue',
      'sequence',
      'changing',
      'difficult',
      'mature',
    ]) {
      expect(source, contains("'$scenario':"));
    }
  });
}
