import test from 'node:test';
import assert from 'node:assert/strict';
import { assertSandboxTarget, REQUIRED_SCENARIOS, runScenario, runSimulation } from './behavioral_simulator.js';
import { INTERVENTION_TYPES } from './intervention_taxonomy.js';

// D-166-AC-06: simulator reports the selected taxonomy types from the shared policy.

test('D-162-AC-01: virtual months run without wall-clock waiting and emit a timeline/report', () => {
  const started = Date.now();
  const report = runSimulation({ months: 6, seed: 7 });

  assert.equal(report.virtualDays, 180);
  assert.equal(report.timeline.length, 180 * REQUIRED_SCENARIOS.length);
  assert.equal(report.scenarios[0].metrics.evaluations, 180);
  assert.equal(Date.now() - started < 1000, true);
  assert.deepEqual(Object.keys(report.selectedTypes), [...INTERVENTION_TYPES]);
  assert.equal(Object.values(report.selectedTypes).reduce((sum, count) => sum + count, 0), report.timeline.length);
});

test('D-162-AC-02: all required synthetic human scenarios run', () => {
  const report = runSimulation({ months: 1, seed: 3 });

  assert.deepEqual(report.scenarios.map((scenario) => scenario.name), [...REQUIRED_SCENARIOS]);
  for (const scenario of report.scenarios) assert.equal(scenario.timeline.length, 30);
  for (const scenario of report.scenarios) {
    assert.deepEqual(Object.keys(scenario.metrics.selectedTypes), [...INTERVENTION_TYPES]);
  }
});

test('D-162-AC-03: production targets and credentials are rejected; sandbox writes stay isolated', () => {
  assert.throws(() => assertSandboxTarget({ projectId: 'life-ops' }), /production_target_rejected/);
  assert.throws(() => assertSandboxTarget({ projectId: 'greenpyramid-production' }), /production_target_rejected/);
  assert.throws(() => assertSandboxTarget({ projectId: 'greenpyramid-sandbox', credentials: true }), /production_target_rejected/);
  const report = runScenario({ name: 'autonomous', days: 2 });
  assert.equal(report.timeline.every((entry) => entry.decision.accountUid === 'sim-autonomous'), true);
});

test('D-162-AC-04: selected scenarios and failure mode are deterministic', () => {
  const options = { months: 1, seed: 11, scenarios: ['autonomous', 'fatigue'], failureMode: 'none' };
  const first = runSimulation(options);
  const second = runSimulation(options);
  assert.deepEqual(first, second);
  assert.deepEqual(first.scenarios.map((scenario) => scenario.name), options.scenarios);
  assert.equal(first.failureMode, 'none');
  assert.equal(first.scenarios.every((scenario) => scenario.metrics.failedDelivery === 0), true);
  assert.throws(() => runSimulation({ months: 25 }), /months_invalid/);
  assert.throws(() => runSimulation({ scenarios: ['not-a-scenario'] }), /scenarios_invalid/);
});
