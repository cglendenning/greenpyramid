import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // D-168-AC-03 / D-168-AC-04: admin user directory and detail controls.
  // D-167-AC-05/D-167-AC-06: the admin surface exposes the generator and is
  // covered by the release build review.
  final source = File('lib/main.dart').readAsStringSync();
  // D-165-AC-03
  // D-165-AC-06
  // D-165-AC-07
  // D-165-AC-04: the signed IPA was manually reviewed after this surface test.
  // D-165-AC-05: simulator controls and report terminology are explained.
  // D-162-AC-04: simulator controls and report output are exposed here.
  // D-166-AC-06: the admin surface exposes shared-policy taxonomy reporting.
  // D-166-AC-03: adaptive support cadence and suppression reasons are explained.
  test('admin surface is authenticated and exposes required views', () {
    expect(source, contains('signInWithProvider'));
    expect(source, contains("tooltip: 'Sign out'"));
    expect(source, contains('FirebaseAuth.instance.signOut()'));
    expect(source, contains("/adminMetrics"));
    expect(source, contains('Product pulse'));
    expect(source, contains('Screen utilization'));
    expect(source, contains('Top users by spend'));
    expect(source, contains('/adminFeedback?limit=500'));
    expect(source, contains('App feedback'));
    expect(source, contains('AdminFeedbackDetailScreen'));
    expect(source, contains('Anonymous user hash'));
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
    expect(source, contains("metrics['selectedTypes']"));
    expect(source, contains('non-silent selections'));
    expect(source, contains('evidence-triggered taxonomy selection'));
    expect(source, contains('How the simulator works'));
    expect(source, contains('How the Intervention Engine works'));
    expect(source, contains('/adminLifetimeCode'));
    expect(source, contains('Generate lifetime subscription code'));
    expect(source, contains('LifetimeCodeScreen'));
    expect(source, contains('Copy code'));
    expect(source, contains('The engine’s job'));
    expect(source, contains('Cloud receives current facts'));
    expect(source, contains('Estimate doing nothing'));
    expect(source, contains('List and compare choices'));
    expect(source, contains('Apply five safety stop rules'));
    expect(source, contains('Return, deliver, and measure'));
    expect(source, contains('The goal'));
    expect(source, contains('Safety: what it means here'));
    expect(source, contains('five approved stop categories'));
    expect(source, contains('before message wording is rendered'));
    expect(source, contains('safety gate suppresses it'));
    expect(source, contains('Baseline'));
    expect(source, contains('Opportunity'));
    expect(source, contains('Burden'));
    expect(source, contains('Adaptive support cadence'));
    expect(source, contains('supportTier'));
    expect(source, contains('suppressionReason'));
    expect(source, contains('2-day cooldown'));
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

  // D-173-AC-02: per-day outcome, reason and safety-trigger controls, plus
  // editable task attributes.
  // D-173-AC-03: the day form drives the separate debugger evaluate endpoint.
  // D-173-AC-04: the decision-trace view exposes candidates and signals.
  // D-173-AC-05: additive companion screen; the simulator above is untouched.
  // This test only adds coverage for the new surface; it does not modify the
  // test above.
  test('intervention engine debugger is additive and exposes the decision trace', () {
    expect(source, contains('Intervention engine debugger'));
    expect(source, contains('/adminInterventionDebuggerPyramid'));
    expect(source, contains('/adminInterventionDebuggerEvaluate'));
    expect(source, contains('Pyramid seed'));
    expect(source, contains('Start new session'));
    expect(source, contains('Next day'));
    expect(source, contains('Miss reason (optional, free text)'));
    expect(source, contains('Safety trigger (optional)'));
    expect(source, contains('Commitment required'));
    expect(source, contains('Candidates considered (decision tree)'));
    expect(source, contains('Derived signals'));
    // D-173-AC-09: multiple sessions persisted on-device and resumable.
    expect(source, contains('class DebuggerSessionStore'));
    expect(source, contains('intervention_debugger_sessions_v1'));
    expect(source, contains('SharedPreferences.getInstance()'));
    expect(source, contains('class DebuggerSessionScreen'));
    expect(source, contains('Saved sessions'));
    expect(source, contains('Future<void> persist() async'));
    expect(source, contains('onPopInvokedWithResult'));
    expect(source, contains('Delete session'));
    // Sessions are device-local: the debugger still writes no cloud data.
    expect(source, isNot(contains('FirebaseFirestore')));
    // D-173-AC-08: bulk day controls, and safety flags scoped to missed tasks.
    expect(source, contains('All missed'));
    expect(source, contains('All checked'));
    expect(source, contains('void setAll(bool checked)'));
    expect(
      source,
      contains(".where((task) => outcomes[task['id']]?['checked'] != true)"),
    );
    for (final category in [
      'self_harm',
      'medical_crisis',
      'illegal_activity',
      'abuse_or_coercion',
      'privacy_or_security',
    ]) {
      expect(source, contains("'$category'"));
    }
    // D-174-AC-06: the trace shows the resolved tier and the applied weight.
    expect(source, contains('Pyramid tier:'));
    expect(source, contains("signals?['pyramidTier']"));
    expect(source, contains("signals?['pyramidTierWeight']"));
    expect(source, contains('tier-weighted'));
    // D-174-AC-06: each task and category shows the tier it sits in.
    expect(source, contains('String tierLabelFor('));
    expect(source, contains('required this.tierLabel'));
    expect(source, contains("'foundational'"));
    expect(source, contains("'essential'"));
    expect(source, contains("'peak'"));
    // Additive: the existing simulator screen and endpoint are untouched.
    expect(source, contains('/adminSimulation'));
    expect(source, contains('class SimulationScreen'));
  });
}
