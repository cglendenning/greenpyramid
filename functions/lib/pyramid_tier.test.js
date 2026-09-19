import test from 'node:test';
import assert from 'node:assert/strict';
import { tierForPosition, tierWeight, tierRank, resolveTier } from './pyramid_tier.js';
import { evaluateIntervention } from './intervention_engine.js';

const now = new Date('2026-09-19T12:00:00.000Z');

const categories = [
  { position: 1, cat: 'Health', description: 'Body' },
  { position: 4, cat: 'Finances', description: 'Stability' },
  { position: 6, cat: 'Rest', description: 'Recovery' },
];

const tasks = [
  { id: 't1', description: 'Morning walk', category: 'Health', active: true },
  { id: 't2', description: 'Review spending', category: 'Finances', active: true },
  { id: 't3', description: 'One screen-free hour', category: 'Rest', active: true },
];

test('D-174-AC-01: tier comes only from user-assigned category position', () => {
  assert.equal(tierForPosition(1), 'foundational');
  assert.equal(tierForPosition(3), 'foundational');
  assert.equal(tierForPosition(4), 'essential');
  assert.equal(tierForPosition(5), 'essential');
  assert.equal(tierForPosition(6), 'peak');
  assert.equal(tierForPosition(0), null);
  assert.equal(tierForPosition(7), null);
  assert.equal(tierForPosition(undefined), null);

  // Resolves by category name alone, which is all the consumer app syncs.
  const resolved = resolveTier({
    categoryName: 'Rest',
    categories: [{ position: 6, name: 'Rest' }],
  });
  assert.equal(resolved, 'peak');
});

test('D-174-AC-02: among same-day misses the strongest tier is targeted first', () => {
  // Peak listed last, exactly the ordering that previously always won.
  const decision = evaluateIntervention({
    accountUid: 'tier-1',
    profile: { setupComplete: true, categories },
    tasks,
    recentActivity: [
      { taskdate: '2026-09-19', taskdescription: 'Review spending', category: 'Finances', checked: false },
      { taskdate: '2026-09-19', taskdescription: 'Morning walk', category: 'Health', checked: false },
      { taskdate: '2026-09-19', taskdescription: 'One screen-free hour', category: 'Rest', checked: false },
    ],
    now,
  });

  assert.equal(decision.target, 'Morning walk');
  assert.equal(decision.policy.derivedSignals.pyramidTier, 'foundational');
});

test('D-174-AC-02: recency still outranks tier', () => {
  const decision = evaluateIntervention({
    accountUid: 'tier-2',
    profile: { setupComplete: true, categories },
    tasks,
    recentActivity: [
      { taskdate: '2026-09-17', taskdescription: 'Morning walk', category: 'Health', checked: false },
      { taskdate: '2026-09-19', taskdescription: 'One screen-free hour', category: 'Rest', checked: false },
    ],
    now,
  });

  // The foundational miss is older, so today's peak miss is still the target.
  assert.equal(decision.target, 'One screen-free hour');
  assert.equal(decision.policy.derivedSignals.pyramidTier, 'peak');
});

test('D-174-AC-03: an identical candidate scores lower for a peak target', () => {
  const history = (category, taskdescription) => [
    { taskdate: '2026-09-18', taskdescription, category, checked: true },
    { taskdate: '2026-09-19', taskdescription, category, checked: false, missreason: 'The equipment was not available' },
  ];

  const foundational = evaluateIntervention({
    accountUid: 'tier-3a',
    profile: { setupComplete: true, categories },
    tasks,
    recentActivity: history('Health', 'Morning walk'),
    now,
  });
  const peak = evaluateIntervention({
    accountUid: 'tier-3b',
    profile: { setupComplete: true, categories },
    tasks,
    recentActivity: history('Rest', 'One screen-free hour'),
    now,
  });

  assert.equal(foundational.type, 'ENVIRONMENT_PROMPT');
  assert.equal(peak.type, 'ENVIRONMENT_PROMPT');

  const pick = (decision) =>
    decision.policy.candidates.find((item) => item.type === 'ENVIRONMENT_PROMPT');
  assert.equal(pick(foundational).tierWeight, 1.0);
  assert.equal(pick(peak).tierWeight, 0.8);
  assert.ok(pick(peak).utilityScore < pick(foundational).utilityScore);
  assert.ok(pick(peak).predictedLift < pick(foundational).predictedLift);
});

test('D-174-AC-04: an unresolved tier is neutral, not penalised', () => {
  // No categories at all — the shape every pre-D-174 test and the D-162
  // scenarios use.
  const decision = evaluateIntervention({
    accountUid: 'tier-4',
    profile: { setupComplete: true },
    tasks: [{ id: 'habit-1', description: 'Daily practice', active: true }],
    recentActivity: [
      { taskdate: '2026-09-19', taskdescription: 'Daily practice', checked: false },
    ],
    now,
  });

  assert.equal(decision.policy.derivedSignals.pyramidTier, null);
  assert.equal(decision.policy.derivedSignals.pyramidTierWeight, 1.0);
  const selected = decision.policy.candidates.find((item) => item.type === decision.type);
  assert.equal(selected.tierWeight, 1.0);
  assert.equal(selected.predictedLift, 0.10);
});

test('D-174-AC-05: tier never reaches the baseline or the completion rate', () => {
  const decision = evaluateIntervention({
    accountUid: 'tier-5',
    profile: { setupComplete: true, categories },
    tasks,
    recentActivity: [
      { taskdate: '2026-09-18', taskdescription: 'One screen-free hour', category: 'Rest', checked: true },
      { taskdate: '2026-09-19', taskdescription: 'One screen-free hour', category: 'Rest', checked: false },
    ],
    now,
  });

  // A peak check-in counts exactly as much as any other in the plain rate.
  assert.equal(decision.baseline.observedCount, 2);
  assert.equal(decision.baseline.completedCount, 1);
  assert.equal(decision.baseline.desiredCheckboxCompletion, 0.5);
  assert.equal(decision.outcome.completionRate, 0.5);
});

test('D-174-AC-06: the decision exposes the resolved tier and applied weight', () => {
  const decision = evaluateIntervention({
    accountUid: 'tier-6',
    profile: { setupComplete: true, categories },
    tasks,
    recentActivity: [
      { taskdate: '2026-09-19', taskdescription: 'Review spending', category: 'Finances', checked: false },
    ],
    now,
  });

  assert.equal(decision.policy.derivedSignals.pyramidTier, 'essential');
  assert.equal(decision.policy.derivedSignals.pyramidTierWeight, 0.9);
  assert.equal(decision.context.tasks.find((t) => t.description === 'Review spending').tier, 'essential');
  assert.equal(decision.context.categories.find((c) => c.name === 'Rest').tier, 'peak');
});

test('D-174: tier ranks order foundational first and unresolved last', () => {
  assert.ok(tierRank('foundational') < tierRank('essential'));
  assert.ok(tierRank('essential') < tierRank('peak'));
  assert.ok(tierRank('peak') < tierRank(null));
  assert.equal(tierWeight(null), 1.0);
});
