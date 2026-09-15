import test from 'node:test';
import assert from 'node:assert/strict';
import { isTreatmentEligible, recoverInterventions, revalidateIntervention } from './intervention_lifecycle.js';

const decision = {
  type: 'REMINDER', target: 'Walk', evaluatedAt: '2026-09-15T10:00:00Z', validityWindowHours: 24,
};

test('D-158-AC-01: completed, changed and superseded targets are suppressed with reasons', () => {
  assert.equal(revalidateIntervention(decision, { now: new Date('2026-09-15T12:00:00Z'), completedTargetIds: ['Walk'] }).reason, 'target_completed');
  assert.equal(revalidateIntervention(decision, { now: new Date('2026-09-15T12:00:00Z'), changedTargetIds: ['Walk'] }).reason, 'target_changed');
  assert.equal(revalidateIntervention(decision, { now: new Date('2026-09-15T12:00:00Z'), superseded: true }).status, 'superseded');
});

test('D-158-AC-02: offline recovery revalidates current decisions without replaying stale work', () => {
  const recovered = recoverInterventions([
    decision,
    { ...decision, target: 'Old', evaluatedAt: '2026-09-13T10:00:00Z' },
  ], { now: new Date('2026-09-15T12:00:00Z'), completedTargetIds: ['Walk'] });

  assert.equal(recovered.length, 2);
  assert.equal(recovered[0].lifecycle.reason, 'target_completed');
  assert.equal(recovered[1].lifecycle.status, 'expired');
});

test('D-158-AC-03: undelivered decisions are not treatment-eligible', () => {
  assert.equal(isTreatmentEligible({ lifecycleStatus: 'pending', deliveryState: 'claimed' }), false);
  assert.equal(isTreatmentEligible({ lifecycleStatus: 'pending', deliveryState: 'sent' }), true);
  assert.equal(isTreatmentEligible({ lifecycleStatus: 'expired', deliveryState: 'sent' }), false);
});

