import test from 'node:test';
import assert from 'node:assert/strict';
import { chooseIntervention } from './utility_policy.js';

const now = new Date('2026-09-15T12:00:00Z');

test('D-157-AC-01: decisions record candidates, lift, burden and selection mode', () => {
  const policy = chooseIntervention({
    baseline: { desiredCheckboxCompletion: 0.5, opportunity: { kind: 'completion_risk' } },
    target: 'Walk', objective: 'support_next_checkbox', now,
  });

  assert.equal(policy.selectedType, 'REMINDER');
  assert.equal(policy.candidates.length, 2);
  assert.equal(typeof policy.candidates[1].predictedCheckboxCompletion, 'number');
  assert.equal(typeof policy.candidates[1].burden, 'number');
  assert.equal(policy.selectionMode, 'deterministic_utility');
});

test('D-157-AC-02: repeated interventions raise burden and silence reduces it', () => {
  const prior = Array.from({ length: 3 }, (_, i) => ({
    type: 'REMINDER', evaluatedAt: `2026-09-${String(15 - i).padStart(2, '0')}T10:00:00Z`,
  }));
  const policy = chooseIntervention({
    baseline: { desiredCheckboxCompletion: 0.5, opportunity: { kind: 'completion_risk' } },
    target: 'Walk', objective: 'support_next_checkbox', priorInterventions: prior, now,
  });

  assert.equal(policy.selectedType, 'NONE');
  assert.equal(policy.burdenAssumptions.recentInterventionCount, 3);
  assert.equal(policy.burdenAfterSelection, 2);
  assert.equal(policy.burdenAssumptions.silenceRecovery, true);
});

test('D-157-AC-03: exploration is bounded and safety-constrained', () => {
  const policy = chooseIntervention({
    baseline: { desiredCheckboxCompletion: 0.5, opportunity: { kind: 'completion_risk' } },
    target: 'Walk', objective: 'support_next_checkbox', now,
  });

  assert.equal(policy.candidates.length <= policy.safetyBound.maxCandidates, true);
  assert.equal(policy.safetyBound.allowedTypes.includes('NONE'), true);
  assert.equal(policy.safetyBound.allowedTypes.includes('REMINDER'), true);
});

