import test from 'node:test';
import assert from 'node:assert/strict';
import { buildOperationalMetrics, createAuditRecord, replayAudit } from './audit_trail.js';

function decision(id, type = 'REMINDER') {
  return { decisionId: id, type, target: 'Walk', objective: 'support_next_checkbox', context: { categories: ['Health'] }, policy: { candidates: [{ type }], selectedType: type }, rationale: null };
}

test('D-163-AC-01: audit records explain context, alternatives, selection, suppression and outcomes', () => {
  const record = createAuditRecord({ accountUid: 'account-1', decision: decision('d1'), lifecycle: { status: 'pending' }, outcome: { completed: 1 } });

  assert.deepEqual(record.decision.context, { categories: ['Health'] });
  assert.equal(record.decision.alternatives.length, 1);
  assert.equal(record.decision.selection, 'REMINDER');
  assert.deepEqual(record.outcome, { completed: 1 });
  assert.equal(record.retained, true);
});

test('D-163-AC-02: identical replay inputs produce an identical fingerprint', () => {
  const records = [createAuditRecord({ accountUid: 'account-1', decision: decision('d2') })];
  assert.equal(replayAudit(records, { version: 'v1', seed: 4 }).fingerprint, replayAudit(records, { version: 'v1', seed: 4 }).fingerprint);
  assert.notEqual(replayAudit(records, { version: 'v1', seed: 4 }).fingerprint, replayAudit(records, { version: 'v1', seed: 5 }).fingerprint);
});

test('D-163-AC-03: operational metrics cover evaluation, delivery, suppression, duplicates, outcomes and safety', () => {
  const records = [
    createAuditRecord({ accountUid: 'a', decision: decision('d1', 'NONE'), deliveryState: 'not_sent' }),
    createAuditRecord({ accountUid: 'a', decision: decision('d2'), lifecycle: { status: 'suppressed' }, safety: { action: 'suppress' }, deliveryState: 'sent', outcome: { completed: 0 }, duplicate: true }),
  ];
  const metrics = buildOperationalMetrics(records);

  assert.deepEqual(metrics, { evaluations: 2, none: 1, delivery: 1, expiry: 0, suppression: 1, duplicates: 1, outcomes: 1, safety: 1 });
});

test('D-163-AC-04: audit records expose no deletion operation', async () => {
  const source = await import('./audit_trail.js');
  assert.equal('deleteAuditRecord' in source, false);
});

