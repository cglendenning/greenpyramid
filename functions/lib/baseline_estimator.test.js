import test from 'node:test';
import assert from 'node:assert/strict';
import { estimateBaseline } from './baseline_estimator.js';

test('D-155-AC-01: baseline persists the no-intervention completion estimate', () => {
  const baseline = estimateBaseline({
    recentActivity: [{ checked: 'true' }, { checked: 'false' }, { checked: 'true' }],
  });

  assert.equal(baseline.desiredCheckboxCompletion, 2 / 3);
  assert.equal(baseline.observedCount, 3);
  assert.equal(baseline.completedCount, 2);
});

test('D-155-AC-02: high autonomous success produces no opportunity', () => {
  const baseline = estimateBaseline({
    recentActivity: [{ checked: true }, { checked: true }, { checked: true }, { checked: false }],
  });

  assert.equal(baseline.desiredCheckboxCompletion, 0.75);
  assert.deepEqual(baseline.opportunity, { kind: 'completion_risk', reason: 'recent_completion_risk' });
  assert.equal(estimateBaseline({ recentActivity: [{ checked: true }, { checked: true }, { checked: true }, { checked: true }] }).opportunity, null);
});

test('D-155-AC-03: baseline detection is semantic and has no rendering copy', () => {
  const baseline = estimateBaseline({ recentActivity: [{ checked: false }] });

  assert.equal(baseline.opportunity.kind, 'completion_risk');
  assert.equal(Object.hasOwn(baseline, 'title'), false);
  assert.equal(Object.hasOwn(baseline, 'body'), false);
});

