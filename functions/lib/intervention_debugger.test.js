import test from 'node:test';
import assert from 'node:assert/strict';
import { generateStockPyramid, evaluateDebuggerDay, DEBUGGER_ACCOUNT_UID } from './intervention_debugger.js';

const now = new Date('2026-09-19T12:00:00.000Z');

test('D-173-AC-01: stock pyramid generation is deterministic and shaped like a real pyramid', () => {
  const first = generateStockPyramid({ seed: 5 });
  const second = generateStockPyramid({ seed: 5 });
  assert.deepEqual(first, second);

  assert.equal(first.categories.length, 6);
  for (const category of first.categories) {
    assert.equal(typeof category.cat, 'string');
    assert.ok(category.cat.length > 0);
  }

  const byCategory = new Map();
  for (const task of first.tasks) {
    byCategory.set(task.categoryId, (byCategory.get(task.categoryId) || 0) + 1);
    assert.equal(typeof task.description, 'string');
    assert.equal(task.active, true);
    assert.equal(task.commitmentRequired, false);
  }
  assert.equal(byCategory.size, 6);
  for (const count of byCategory.values()) assert.ok(count === 2 || count === 3);

  assert.throws(() => generateStockPyramid({ seed: 1.5 }), /seed_invalid/);
});

test('D-173-AC-01: a different seed can change the generated pyramid', () => {
  const seeds = [1, 2, 3, 4, 5, 6, 7, 8].map((seed) => generateStockPyramid({ seed }).tasks.length);
  assert.ok(new Set(seeds).size > 1);
});

test('D-173-AC-03/D-173-AC-04: a free-text miss reason drives the same candidate selection the production policy uses', () => {
  const pyramid = generateStockPyramid({ seed: 1 });
  const target = pyramid.tasks[0];
  const result = evaluateDebuggerDay({
    profile: { categories: pyramid.categories },
    tasks: pyramid.tasks,
    recentActivity: [{
      taskdate: now.toISOString(),
      taskdescription: target.description,
      checked: false,
      missreason: 'The equipment was not available',
    }],
    priorInterventions: [],
    now,
  });

  assert.equal(result.type, 'ENVIRONMENT_PROMPT');
  assert.equal(result.accountUid, DEBUGGER_ACCOUNT_UID);
  assert.ok(Array.isArray(result.policy.candidates) && result.policy.candidates.length > 1);
  assert.ok(result.policy.candidates.every((candidate) => Number.isFinite(candidate.utilityScore)));
  assert.equal(result.policy.derivedSignals.reasonClass, 'environment');
  assert.equal(result.safety.action, 'allow');
  assert.equal(result.lifecycle.status, 'pending');
  assert.equal(result.rendered.renderedBy, 'deterministic_fallback');
  assert.ok(result.rendered.body.length > 0);
});

test('D-173-AC-03: a flagged safety trigger suppresses the intervention and is audited without storing trigger text', () => {
  const pyramid = generateStockPyramid({ seed: 1 });
  const target = pyramid.tasks[0];
  const result = evaluateDebuggerDay({
    profile: { categories: pyramid.categories },
    tasks: pyramid.tasks,
    recentActivity: [{
      taskdate: now.toISOString(),
      taskdescription: target.description,
      checked: false,
      missreason: 'The equipment was not available',
    }],
    safetyTriggers: [{ type: 'self_harm' }],
    now,
  });

  assert.equal(result.type, 'NONE');
  assert.equal(result.safetySuppressed, true);
  assert.equal(result.safety.action, 'suppress');
  assert.equal(result.safety.triggerType, 'self_harm');
  assert.equal(result.rendered.title, '');
});

test('D-173-AC-03: full completion produces NONE with autonomous_completion, not a fabricated intervention', () => {
  // Below the 3-day streak that would otherwise earn a CELEBRATION candidate,
  // so this isolates the autonomous_completion gate itself.
  const pyramid = generateStockPyramid({ seed: 1 });
  const target = pyramid.tasks[0];
  const result = evaluateDebuggerDay({
    profile: { categories: pyramid.categories },
    tasks: pyramid.tasks,
    recentActivity: [
      { taskdate: '2026-09-18', taskdescription: target.description, checked: true },
      { taskdate: now.toISOString(), taskdescription: target.description, checked: true },
    ],
    now,
  });

  assert.equal(result.type, 'NONE');
  assert.equal(result.rationale, 'autonomous_completion');
});

test('D-173-AC-03/D-173-AC-04: a three-day completion streak earns a deliberate CELEBRATION, not silence', () => {
  const pyramid = generateStockPyramid({ seed: 1 });
  const target = pyramid.tasks[0];
  const result = evaluateDebuggerDay({
    profile: { categories: pyramid.categories },
    tasks: pyramid.tasks,
    recentActivity: [
      { taskdate: '2026-09-17', taskdescription: target.description, checked: true },
      { taskdate: '2026-09-18', taskdescription: target.description, checked: true },
      { taskdate: now.toISOString(), taskdescription: target.description, checked: true },
    ],
    now,
  });

  assert.equal(result.type, 'CELEBRATION');
  assert.equal(result.policy.derivedSignals.completedStreak, 3);
});

test('D-173-AC-06: oversized or malformed input is rejected rather than silently truncated', () => {
  const pyramid = generateStockPyramid({ seed: 1 });
  assert.throws(() => evaluateDebuggerDay({ tasks: pyramid.tasks, recentActivity: 'not-an-array', now }), /recentActivity_invalid/);
  const tooManyTasks = Array.from({ length: 25 }, (_, i) => ({ id: `t${i}`, description: `Task ${i}`, active: true }));
  assert.throws(() => evaluateDebuggerDay({ tasks: tooManyTasks, now }), /tasks_invalid/);
});
