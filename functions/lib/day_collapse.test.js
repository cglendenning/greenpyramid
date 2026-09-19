import test from 'node:test';
import assert from 'node:assert/strict';
import { latestDaySummary } from './day_collapse.js';
import { evaluateIntervention } from './intervention_engine.js';

const now = new Date('2026-09-19T12:00:00.000Z');
const categories = [{ position: 1, cat: 'Health', description: 'Body' }];
const tasks = Array.from({ length: 12 }, (_, i) => ({
  id: `t${i + 1}`, description: `Task ${i + 1}`, category: 'Health', active: true,
}));

/** `missesByDay[n]` misses on day n, the rest checked. */
function history(missesByDay) {
  const rows = [];
  missesByDay.forEach((misses, day) => {
    const date = `2026-09-${String(13 + day).padStart(2, '0')}`;
    tasks.forEach((task, index) => {
      rows.push({
        taskdate: date,
        taskdescription: task.description,
        category: task.category,
        checked: index >= misses,
        ...(index < misses ? { missreason: 'Everything fell apart today' } : {}),
      });
    });
  });
  return rows;
}

test('D-176-AC-01: the most recent day is summarized on its own terms', () => {
  const rows = [
    { task: 'a', checked: true, date: '2026-09-17' },
    { task: 'b', checked: false, date: '2026-09-18' },
    { task: 'c', checked: false, date: '2026-09-18' },
    { task: 'd', checked: true, date: '2026-09-18' },
  ];
  const summary = latestDaySummary(rows);
  assert.equal(summary.date, '2026-09-18');
  assert.equal(summary.observed, 3);
  assert.equal(summary.missed, 2);
  assert.ok(Math.abs(summary.completion - 1 / 3) < 1e-9);
  assert.equal(summary.collapse, true);
});

test('D-176-AC-02: collapse is proportional, with a floor so small days do not trip it', () => {
  const oneOfTwo = [
    { task: 'a', checked: false, date: '2026-09-18' },
    { task: 'b', checked: true, date: '2026-09-18' },
  ];
  assert.equal(latestDaySummary(oneOfTwo).collapse, false, 'one of two is not a collapse');

  const twoOfFour = [
    { task: 'a', checked: false, date: '2026-09-18' },
    { task: 'b', checked: false, date: '2026-09-18' },
    { task: 'c', checked: true, date: '2026-09-18' },
    { task: 'd', checked: true, date: '2026-09-18' },
  ];
  assert.equal(latestDaySummary(twoOfFour).collapse, true, 'half of four is a collapse');

  const fiveOfTwelve = [
    ...Array.from({ length: 5 }, (_, i) => ({ task: `m${i}`, checked: false, date: '2026-09-18' })),
    ...Array.from({ length: 7 }, (_, i) => ({ task: `c${i}`, checked: true, date: '2026-09-18' })),
  ];
  assert.equal(latestDaySummary(fiveOfTwelve).collapse, false, 'under half is not a collapse');
});

test('D-176-AC-03: a collapsed day is addressed despite a high lookback average', () => {
  // Six ordinary days then eleven of twelve missed: the pooled rate is still
  // 0.845, above the autonomous threshold that previously silenced this.
  const decision = evaluateIntervention({
    accountUid: 'collapse-1',
    profile: { setupComplete: true, categories },
    tasks,
    recentActivity: history([0, 0, 1, 0, 1, 0, 11]),
    now,
  });

  assert.ok(decision.baseline.desiredCheckboxCompletion > 0.8);
  assert.notEqual(decision.type, 'NONE');
  assert.notEqual(decision.rationale, 'autonomous_completion');
  assert.equal(decision.policy.derivedSignals.dayCollapse, true);
  assert.equal(decision.policy.derivedSignals.latestDayMissed, 11);
  assert.equal(decision.policy.derivedSignals.latestDayObserved, 12);
});

test('D-176-AC-04: a collapsed day offers RECOVERY rather than a generic reminder', () => {
  const decision = evaluateIntervention({
    accountUid: 'collapse-2',
    profile: { setupComplete: true, categories },
    tasks,
    recentActivity: history([0, 0, 1, 0, 1, 0, 11]),
    now,
  });

  assert.equal(decision.type, 'RECOVERY');
  assert.equal(decision.rationale, 'same_day_collapse');
});

test('D-176-AC-05: a collapsed day counts as credible difficulty for the cadence', () => {
  const decision = evaluateIntervention({
    accountUid: 'collapse-3',
    profile: { setupComplete: true, categories },
    tasks,
    recentActivity: history([0, 0, 0, 0, 0, 0, 11]),
    now,
  });

  // Without this a single earlier acknowledgment would have consumed the
  // stable tier's one allowance and silenced the collapse response.
  assert.equal(decision.policy.derivedSignals.supportTier, 'emerging');
});

test('D-176-AC-05: an earlier acknowledgment no longer blocks the collapse response', () => {
  const acknowledgment = evaluateIntervention({
    accountUid: 'collapse-4',
    profile: { setupComplete: true, categories },
    tasks,
    recentActivity: history([0, 0, 0]),
    now: new Date('2026-09-15T12:00:00.000Z'),
  });
  assert.ok(['CELEBRATION', 'SUCCESS_REFLECTION'].includes(acknowledgment.type));

  const decision = evaluateIntervention({
    accountUid: 'collapse-4',
    profile: { setupComplete: true, categories },
    tasks,
    recentActivity: history([0, 0, 0, 0, 11]),
    priorInterventions: [acknowledgment],
    now: new Date('2026-09-17T12:00:00.000Z'),
  });

  assert.notEqual(decision.type, 'NONE');
  assert.notEqual(decision.rationale, 'burden_limit');
});

test('D-176-AC-06: no success language on a collapsed day', () => {
  const decision = evaluateIntervention({
    accountUid: 'collapse-5',
    profile: { setupComplete: true, categories },
    tasks,
    recentActivity: history([0, 0, 0, 0, 11]),
    now,
  });

  assert.ok(!['CELEBRATION', 'SUCCESS_REFLECTION'].includes(decision.type));
});

test('D-176-AC-07: an ordinary day is unaffected', () => {
  const decision = evaluateIntervention({
    accountUid: 'collapse-6',
    profile: { setupComplete: true, categories },
    tasks,
    recentActivity: history([0, 0, 1, 0, 1]),
    now,
  });

  assert.equal(decision.policy.derivedSignals.dayCollapse, false);
  assert.equal(decision.type, 'NONE');
  assert.equal(decision.rationale, 'autonomous_completion');
});
