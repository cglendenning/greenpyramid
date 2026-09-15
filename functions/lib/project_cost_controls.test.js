import test from 'node:test';
import assert from 'node:assert/strict';
import { ProjectCostLedger, scheduleSlotKey, validateCostConfiguration, validateScheduleConfig } from './project_cost_controls.js';

const request = {
  accountUid: 'account-1', reservationId: 'reservation-1', logicalInterventionId: 'decision-1', slotKey: 'slot-1',
  provider: 'anthropic', model: 'claude-sonnet-5', functionName: 'intervention', reason: 'evaluation',
  maxOutputTokens: 320, maxCostUsd: 2, billingPeriod: '2026-09',
};

test('D-164-AC-01: project and account allowances reject before dispatch and concurrent claims dedupe', async () => {
  const ledger = new ProjectCostLedger({ projectAllowanceUsd: 2, accountAllowanceUsd: 2 });
  const results = await Promise.all([Promise.resolve(ledger.reserve(request)), Promise.resolve(ledger.reserve(request))]);
  assert.deepEqual(results.map((result) => result.outcome), ['reserved', 'duplicate']);
  assert.throws(() => ledger.reserve({ ...request, reservationId: 'reservation-2', slotKey: 'slot-2', accountUid: 'account-2' }), /cost_allowance_exceeded/);
});

test('D-164-AC-02: reservations retain provider metadata and settle exactly once', () => {
  const ledger = new ProjectCostLedger();
  ledger.reserve(request);
  assert.deepEqual(ledger.settle({ reservationId: request.reservationId, outcome: 'timeout', actualCostUsd: 0 }), { reservationId: request.reservationId, outcome: 'settled' });
  assert.deepEqual(ledger.settle({ reservationId: request.reservationId, outcome: 'retry' }), { reservationId: request.reservationId, outcome: 'already_settled' });
  assert.equal(ledger.telemetry().byProvider.anthropic, 1);
});

test('D-164-AC-03: timezone-aware scheduler slots allow at most one reservation', () => {
  const slot = scheduleSlotKey({ accountUid: 'a', logicalInterventionId: 'd', timezone: 'America/Los_Angeles', occurrenceDate: '2026-09-15', slot: '09:00' });
  const ledger = new ProjectCostLedger();
  ledger.reserve({ ...request, accountUid: 'a', reservationId: 'r1', logicalInterventionId: 'd', slotKey: slot });
  assert.equal(ledger.reserve({ ...request, accountUid: 'a', reservationId: 'r2', logicalInterventionId: 'd', slotKey: slot }).outcome, 'duplicate');
});

test('D-164-AC-04: kill switch blocks external calls while telemetry remains readable', () => {
  const ledger = new ProjectCostLedger({ killSwitch: true });
  assert.throws(() => ledger.reserve(request), /project_cost_kill_switch/);
  assert.deepEqual(ledger.telemetry().firebase, 0);
});

test('D-164-AC-05: allowlists, bounds and required guards reject unsafe configuration', () => {
  assert.throws(() => validateCostConfiguration({ ...request, provider: 'unknown' }), /not_allowlisted/);
  assert.throws(() => validateCostConfiguration({ ...request, maxOutputTokens: 0 }), /cost_guard_missing/);
  assert.throws(() => validateScheduleConfig({ intervalMinutes: 61, concurrency: 1, timeoutSeconds: 30, maxOutbound: 10 }), /schedule_unbounded/);
  assert.throws(() => new ProjectCostLedger().reserve({ ...request, model: 'gpt-9' }), /not_allowlisted/);
});

