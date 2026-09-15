import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { evaluateIntervention } from './intervention_engine.js';

const now = new Date('2026-09-15T12:00:00.000Z');
const task = { id: 'habit-1', description: 'Walk for ten minutes', active: true };

test('D-152-AC-01: current account state produces an auditable decision', () => {
  const decision = evaluateIntervention({
    accountUid: 'account-1',
    profile: { setupComplete: true },
    tasks: [task],
    recentActivity: [{ taskdate: '2026-09-14', checked: 'false', taskdescription: task.description }],
    now,
  });

  assert.equal(decision.type, 'REMINDER');
  assert.equal(decision.accountUid, 'account-1');
  assert.match(decision.decisionId, /^[a-f0-9]{32}$/);
  assert.equal(decision.outcome.primary, 'checkbox_completion_quantity');
});

test('D-152-AC-01: safe NONE is returned when current state has no usable history', () => {
  const decision = evaluateIntervention({
    accountUid: 'account-1',
    profile: { setupComplete: true },
    tasks: [task],
    recentActivity: [],
    now,
  });

  assert.equal(decision.type, 'NONE');
  assert.equal(decision.rationale, 'insufficient_history');
});

test('D-152-AC-02: completion quantity is the primary outcome', () => {
  const decision = evaluateIntervention({
    accountUid: 'account-1',
    profile: { setupComplete: true },
    tasks: [task],
    recentActivity: [
      { taskdate: '2026-09-14', checked: 'true' },
      { taskdate: '2026-09-13', checked: 'true' },
      { taskdate: '2026-09-12', checked: 'false' },
    ],
    now,
  });

  assert.equal(decision.outcome.primary, 'checkbox_completion_quantity');
  assert.equal(decision.outcome.observedCount, 3);
  assert.equal(decision.outcome.completedCount, 2);
});

test('D-152-AC-03: client requests cannot bypass the server policy boundary', async () => {
  const indexSource = await readFile(new URL('../index.js', import.meta.url), 'utf8');

  assert.match(indexSource, /app\.post\('\/evaluateIntervention', requireFirebaseAuth/);
  assert.match(indexSource, /evaluateIntervention\(\{/);
  assert.match(indexSource, /interventionDecisions/);
});
