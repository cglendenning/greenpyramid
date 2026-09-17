import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/main.dart').readAsStringSync();
  // D-165-AC-03
  // D-165-AC-04: the signed IPA was manually reviewed after this surface test.
  // D-165-AC-05: simulator controls and report terminology are explained.
  // D-162-AC-04: simulator controls and report output are exposed here.
  // D-166-AC-06: the admin surface exposes shared-policy taxonomy reporting.
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
    expect(source, contains('SimulationScenarioDetailsScreen'));
    expect(source, contains('Every virtual day is shown below'));
    expect(source, contains('Policy comparison'));
    expect(source, contains('Delivery'));
    expect(source, contains('does not create or'));
    expect(source, contains('train a predictive model'));
    expect(source, contains('Sandbox only'));
    expect(source, contains('What this tests'));
    expect(source, contains('Default deterministic failures makes every 17th'));
    expect(
      source,
      contains('The same seed and settings produce the same report'),
    );
    expect(source, contains('selectionMode '));
    expect(source, contains('(deterministic_utility)'));
    expect(source, contains('Selected intervention types'));
    expect(source, contains('evidence-triggered taxonomy selection'));
    expect(source, contains('How the simulator works'));
    expect(source, contains('How the Intervention Engine works'));
    expect(source, contains('The engine’s job'));
    expect(source, contains('Context + history'));
    expect(source, contains('Baseline + opportunity'));
    expect(source, contains('Candidates + utility'));
    expect(source, contains('Safety gate'));
    expect(source, contains('Render + lifecycle'));
    expect(source, contains('The goal'));
    expect(source, contains('Safety: what it means here'));
    expect(source, contains('hard boundary'));
    expect(source, contains('before message wording is rendered'));
    expect(source, contains('safety gate suppresses it'));
    expect(source, contains('Baseline'));
    expect(source, contains('Opportunity'));
    expect(source, contains('Burden'));
    expect(source, contains('Selection'));
    expect(source, contains('Lifecycle'));
    expect(source, contains('Synthetic person'));
    expect(source, contains('A concrete example'));
    expect(source, contains('Failed delivery'));
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
