import test from 'node:test';
import assert from 'node:assert/strict';
import { deterministicFallback, INTERVENTION_TYPES, validateInterventionDecision } from './intervention_taxonomy.js';

test('D-156-AC-01: semantic decisions carry the required fields', () => {
  const decision = deterministicFallback('REMINDER', { target: 'Walk', objective: 'support_next_checkbox' });

  assert.equal(validateInterventionDecision(decision), decision);
  for (const field of ['type', 'target', 'objective', 'validityWindowHours', 'measurementWindowDays', 'surface']) {
    assert.equal(field in decision, true, field);
  }
});

test('D-156-AC-02: validation is semantic and does not accept rendered copy as policy', () => {
  const decision = deterministicFallback('VALUE_REFRAME', { target: 'Health', objective: 'reconnect_to_value' });

  assert.equal(decision.body, undefined);
  assert.equal(decision.title, undefined);
  assert.deepEqual(validateInterventionDecision({ ...decision, body: 'copy' }), { ...decision, body: 'copy' });
  assert.equal(decision.type, 'VALUE_REFRAME');
});

test('D-156-AC-03: every taxonomy type has deterministic fallback behavior', () => {
  for (const type of INTERVENTION_TYPES) {
    const fallback = deterministicFallback(type, { target: 'target', objective: 'objective' });
    assert.doesNotThrow(() => validateInterventionDecision(fallback));
    assert.equal(fallback.type, type);
    assert.equal(fallback.surface, type === 'NONE' ? 'none' : 'in_app');
  }
});
