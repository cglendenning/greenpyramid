import test from 'node:test';
import assert from 'node:assert/strict';
import { taskMissStreaks, neglectedTasks, worstMissStreak } from './task_neglect.js';
import { neglectThresholdForTier } from './pyramid_tier.js';
import { evaluateIntervention } from './intervention_engine.js';

const now = new Date('2026-09-19T12:00:00.000Z');

const categories = [
  { position: 1, cat: 'Health', description: 'Body' },
  { position: 6, cat: 'Rest', description: 'Recovery' },
];

// Twelve-task shape from the debugger: one habit dropped, the rest checked.
const tasks = [
  { id: 't1', description: 'Morning walk', category: 'Health', active: true },
  ...Array.from({ length: 11 }, (_, i) => ({
    id: `t${i + 2}`, description: `Other ${i + 1}`, category: 'Health', active: true,
  })),
];

function daysOfHistory(dayCount, { droppedTask = 'Morning walk' } = {}) {
  const rows = [];
  for (let day = 0; day < dayCount; day += 1) {
    const date = `2026-09-${String(13 + day).padStart(2, '0')}`;
    for (const task of tasks) {
      const missed = task.description === droppedTask;
      rows.push({
        taskdate: date,
        taskdescription: task.description,
        category: task.category,
        checked: !missed,
        ...(missed ? { missreason: 'I never found the time' } : {}),
      });
    }
  }
  return rows;
}

test('D-175-AC-01: miss streaks are counted per task, not across the interleaved history', () => {
  const history = [
    { task: 'Morning walk', checked: false, tier: 'foundational', date: '2026-09-17' },
    { task: 'Other 1', checked: true, tier: 'foundational', date: '2026-09-17' },
    { task: 'Morning walk', checked: false, tier: 'foundational', date: '2026-09-18' },
    { task: 'Other 1', checked: true, tier: 'foundational', date: '2026-09-18' },
  ];

  const streaks = taskMissStreaks(history);
  assert.equal(streaks.find((r) => r.task === 'Morning walk').missStreak, 2);
  assert.equal(streaks.find((r) => r.task === 'Other 1').missStreak, 0);
  assert.equal(worstMissStreak(history), 2);
});

test('D-175-AC-02: the neglect threshold is tier-sensitive', () => {
  assert.equal(neglectThresholdForTier('foundational'), 2);
  assert.equal(neglectThresholdForTier('essential'), 3);
  assert.equal(neglectThresholdForTier('peak'), 4);
  assert.equal(neglectThresholdForTier(null), 3);

  const twoMisses = (tier) => ([
    { task: 'x', checked: false, tier, date: '2026-09-17' },
    { task: 'x', checked: false, tier, date: '2026-09-18' },
  ]);
  assert.equal(neglectedTasks(twoMisses('foundational')).length, 1);
  assert.equal(neglectedTasks(twoMisses('peak')).length, 0);
});

test('D-175-AC-03: a dropped foundational habit is not silenced by a high pooled rate', () => {
  // Eleven of twelve checked every day: 91.7% completion, comfortably above
  // the 80% autonomous threshold that previously returned NONE forever.
  const recentActivity = daysOfHistory(3);
  const decision = evaluateIntervention({
    accountUid: 'neglect-1',
    profile: { setupComplete: true, categories },
    tasks,
    recentActivity,
    now,
  });

  assert.ok(decision.baseline.desiredCheckboxCompletion > 0.8);
  assert.notEqual(decision.type, 'NONE');
  assert.equal(decision.rationale !== 'autonomous_completion', true);
  assert.equal(decision.target, 'Morning walk');
  assert.equal(decision.policy.derivedSignals.neglectedTasks[0].task, 'Morning walk');
  assert.equal(decision.policy.derivedSignals.neglectedTasks[0].missStreak, 3);
});

test('D-175-AC-04: sustained neglect outranks an unrelated miss recorded today', () => {
  const recentActivity = daysOfHistory(3);
  recentActivity.push({
    taskdate: '2026-09-16', taskdescription: 'Other 11', category: 'Health', checked: false,
  });

  const decision = evaluateIntervention({
    accountUid: 'neglect-2',
    profile: { setupComplete: true, categories },
    tasks,
    recentActivity,
    now,
  });

  assert.equal(decision.target, 'Morning walk');
});

test('D-175-AC-05: the support cadence escalates on the worst single task', () => {
  const decision = evaluateIntervention({
    accountUid: 'neglect-3',
    profile: { setupComplete: true, categories },
    tasks,
    recentActivity: daysOfHistory(3),
    now,
  });

  // Previously 'stable': the interleaved streak read 0 because the other
  // eleven tasks were checked after it each day.
  assert.equal(decision.policy.derivedSignals.supportTier, 'persistent');
  assert.equal(decision.policy.derivedSignals.worstTaskMissStreak, 3);
});

test('D-175-AC-06: no success language on a day something was missed', () => {
  const decision = evaluateIntervention({
    accountUid: 'neglect-4',
    profile: { setupComplete: true, categories },
    tasks,
    // A single day, one miss: not yet neglect, but not a clean day either.
    recentActivity: daysOfHistory(1),
    now,
  });

  assert.equal(decision.policy.derivedSignals.latestDayFullyChecked, false);
  assert.ok(!['CELEBRATION', 'SUCCESS_REFLECTION'].includes(decision.type));
});

test('D-175-AC-07: noticing neglect does not raise the permitted frequency', () => {
  // Step eight days of sustained neglect and count how often the engine
  // actually speaks; the cadence gates must still bound it.
  const priorInterventions = [];
  const types = [];
  for (let day = 1; day <= 8; day += 1) {
    const at = new Date(`2026-09-${String(12 + day).padStart(2, '0')}T12:00:00.000Z`);
    const decision = evaluateIntervention({
      accountUid: 'neglect-cadence',
      profile: { setupComplete: true, categories },
      tasks,
      recentActivity: daysOfHistory(day),
      priorInterventions,
      now: at,
    });
    priorInterventions.push(decision);
    types.push(decision.type);
  }

  const spoken = types.filter((type) => type !== 'NONE').length;
  assert.ok(spoken >= 1, 'sustained neglect must eventually be addressed');
  assert.ok(spoken <= 4, `cadence must still bound frequency, spoke ${spoken} times in 8 days`);
});

test('D-175-AC-06: a genuinely clean run still earns acknowledgment', () => {
  const clean = [];
  for (let day = 0; day < 3; day += 1) {
    for (const task of tasks.slice(0, 2)) {
      clean.push({
        taskdate: `2026-09-${17 + day}`,
        taskdescription: task.description,
        category: task.category,
        checked: true,
      });
    }
  }

  const decision = evaluateIntervention({
    accountUid: 'neglect-5',
    profile: { setupComplete: true, categories },
    tasks: tasks.slice(0, 2),
    recentActivity: clean,
    now,
  });

  assert.equal(decision.policy.derivedSignals.latestDayFullyChecked, true);
  assert.ok(['CELEBRATION', 'SUCCESS_REFLECTION'].includes(decision.type));
});
