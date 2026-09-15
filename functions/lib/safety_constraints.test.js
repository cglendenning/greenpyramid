import test from 'node:test';
import assert from 'node:assert/strict';
import { applySafetyConstraints, APPROVED_TRIGGER_CATEGORIES } from './safety_constraints.js';

const decision = { type: 'REMINDER', target: 'Walk', objective: 'support_next_checkbox', surface: 'in_app' };

test('D-161-AC-01: every approved trigger category blocks the prohibited path', () => {
  for (const type of APPROVED_TRIGGER_CATEGORIES) {
    const result = applySafetyConstraints({ decision, decisionId: 'decision-1', triggers: [{ type, text: 'private trigger details' }] });
    assert.equal(result.allowed, false);
    assert.equal(result.decision.type, 'NONE');
    assert.equal(result.audit.triggerType, type);
  }
});

test('D-161-AC-02: safety audit contains policy metadata but no sensitive trigger content', () => {
  const result = applySafetyConstraints({ decision, decisionId: 'decision-1', triggers: [{ type: 'self_harm', text: 'sensitive details' }] });

  assert.equal(result.audit.action, 'suppress');
  assert.equal(result.audit.policyVersion, 'safety-v1');
  assert.equal('text' in result.audit, false);
  assert.equal(JSON.stringify(result.audit).includes('sensitive'), false);
});

test('D-161-AC-03: retries, duplicates and renderer failure use the same deterministic constraint', () => {
  const args = { decision, decisionId: 'decision-1', triggers: [{ type: 'medical_crisis' }], now: new Date('2026-09-15T12:00:00Z') };
  const first = applySafetyConstraints(args);
  const retry = applySafetyConstraints(args);

  assert.deepEqual(retry, first);
  assert.equal(first.decision.safetySuppressed, true);
  assert.equal(applySafetyConstraints({ ...args, triggers: [] }).allowed, true);
});

