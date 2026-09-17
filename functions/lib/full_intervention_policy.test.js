import test from 'node:test';
import assert from 'node:assert/strict';
import { evaluateIntervention } from './intervention_engine.js';
import { applySafetyConstraints } from './safety_constraints.js';

const now = new Date('2026-09-15T12:00:00.000Z');
const task = { id: 'habit-1', description: 'Walk for ten minutes', category: 'Health', active: true };
const profile = {
  setupComplete: true,
  categories: [{ position: 1, cat: 'Health', description: 'Feel strong and well' }],
  visionStatement: 'Keep my health strong',
};

function activity(rows) {
  return rows.map((row, index) => ({
    taskdate: `2026-09-${String(10 + index).padStart(2, '0')}`,
    taskdescription: task.description,
    checked: row.checked,
    ...(row.missreason ? { missreason: row.missreason } : {}),
  }));
}

function evaluate(rows, extraProfile = {}, extraTask = {}) {
  return evaluateIntervention({
    accountUid: 'taxonomy-test',
    profile: { ...profile, ...extraProfile },
    tasks: [{ ...task, ...extraTask }],
    recentActivity: activity(rows),
    now,
  });
}

test('D-166-AC-01: every semantic taxonomy type has a deterministic input rule', () => {
  const cases = [
    ['REMINDER', [{ checked: false }]],
    ['COMMITMENT_REQUEST', [{ checked: false }], { commitmentNeeded: true }],
    ['PLAN_PROMPT', [{ checked: false }, { checked: false }]],
    ['IMPLEMENTATION_INTENTION', [{ checked: false, missreason: 'I need a better time cue' }]],
    ['VALUE_REFRAME', [{ checked: false, missreason: 'My motivation is low because this feels pointless' }]],
    ['REFLECTION', [{ checked: false }, { checked: true }]],
    ['INFORMATION_REQUEST', [{ checked: false }, { checked: false, missreason: 'I am not sure what changed' }]],
    ['ENVIRONMENT_PROMPT', [{ checked: false, missreason: 'The equipment was not available' }]],
    ['RECOVERY', [{ checked: true }, { checked: false, missreason: 'An unexpected meeting interrupted me' }]],
    ['CELEBRATION', [{ checked: true }, { checked: true }, { checked: true }]],
    ['SUCCESS_REFLECTION', [{ checked: true }, { checked: true }, { checked: true }, { checked: true }]],
    ['TARGET_REVIEW', [{ checked: false, missreason: 'This target is no longer relevant' }]],
    ['CHALLENGE_REVIEW', [{ checked: false, missreason: 'This is too difficult' }]],
  ];

  for (const [expectedType, rows, extraProfile] of cases) {
    const decision = evaluate(rows, extraProfile);
    assert.equal(decision.type, expectedType, expectedType);
    assert.equal(decision.policy.selectionMode, 'deterministic_utility');
    assert.equal(decision.policy.candidates.length <= 4, true);
    assert.equal(typeof decision.objective, 'string');
    assert.equal(typeof decision.surface, 'string');
    assert.equal(decision.outcome.primary, 'checkbox_completion_quantity');
  }
});

test('D-166-AC-02: policy fields are type-specific and clients cannot select a type', () => {
  const decision = evaluate([{ checked: false, missreason: 'This is too difficult' }]);
  assert.equal(decision.type, 'CHALLENGE_REVIEW');
  assert.equal(decision.objective, 'calibrate_challenge');
  assert.equal(decision.surface, 'council');
  assert.equal(decision.validityWindowHours, 24);
  assert.equal(decision.measurementWindowDays, 1);
});

test('D-166-AC-03: burden and same-type cooldown suppress otherwise useful candidates', () => {
  const prior = [{ type: 'RECOVERY', evaluatedAt: '2026-09-14T10:00:00.000Z' }];
  const decision = evaluateIntervention({
    accountUid: 'taxonomy-test',
    profile,
    tasks: [task],
    recentActivity: activity([
      { checked: false, missreason: 'An unexpected meeting interrupted me' },
      { checked: false, missreason: 'An unexpected meeting interrupted me' },
    ]),
    priorInterventions: prior,
    now,
  });
  assert.equal(decision.type, 'NONE');
  assert.equal(decision.policy.candidates.some((candidate) => candidate.type === 'RECOVERY' && candidate.cooldownBlocked), true);
  assert.equal(decision.policy.burdenAssumptions.typeCooldownDays, 3);
  assert.equal(decision.policy.suppressionReason, 'same_type_cooldown');
});

test('D-166-AC-03: persistent difficulty receives a shorter cadence and larger bounded support budget', () => {
  const decision = evaluate([
    { checked: false, missreason: 'The equipment was not available' },
    { checked: false, missreason: 'The equipment was not available' },
    { checked: false, missreason: 'The equipment was not available' },
  ]);
  assert.equal(decision.policy.derivedSignals.supportTier, 'persistent');
  assert.equal(decision.policy.burdenAssumptions.typeCooldownDays, 2);
  assert.equal(decision.policy.burdenAssumptions.maxRecentNonSilent, 4);
  assert.equal(decision.type, 'ENVIRONMENT_PROMPT');
});

test('D-166-AC-03: three failed uses of one type cause a bounded alternative to be considered', () => {
  const priorInterventions = [
    { type: 'ENVIRONMENT_PROMPT', evaluatedAt: '2026-09-06T10:00:00.000Z' },
    { type: 'ENVIRONMENT_PROMPT', evaluatedAt: '2026-09-08T10:00:00.000Z' },
    { type: 'ENVIRONMENT_PROMPT', evaluatedAt: '2026-09-10T10:00:00.000Z' },
  ];
  const recentActivity = [6, 7, 8, 9, 10, 11, 12, 13, 14].map((day) => ({
    taskdate: `2026-09-${day}T10:00:00.000Z`,
    taskdescription: task.description,
    checked: false,
    missreason: 'The equipment was not available',
  }));
  const decision = evaluateIntervention({
    accountUid: 'taxonomy-test',
    profile,
    tasks: [task],
    recentActivity,
    priorInterventions,
    now,
  });
  assert.equal(decision.type, 'INFORMATION_REQUEST');
  assert.equal(decision.policy.derivedSignals.failedTypeCounts.ENVIRONMENT_PROMPT, 3);
  assert.equal(decision.rationale, 'alternate_after_repeated_failure');
});

test('D-166-AC-04: miss reason classification is bounded and unknown-preserving', () => {
  const decision = evaluate([{ checked: false, missreason: 'The moon was purple' }]);
  assert.equal(decision.type, 'REMINDER');
  assert.equal(decision.policy.derivedSignals.reasonClass, 'unknown');
  assert.equal(decision.context.checkboxHistory[0].missReason, 'The moon was purple');
});

test('D-166-AC-05: safety suppresses every newly selectable semantic type', () => {
  const decision = evaluate([{ checked: false, missreason: 'This is too difficult' }]);
  const constrained = applySafetyConstraints({
    decision,
    decisionId: decision.decisionId,
    triggers: [{ type: 'medical_crisis', detail: 'must not be persisted' }],
    now,
  });
  assert.equal(constrained.allowed, false);
  assert.equal(constrained.decision.type, 'NONE');
  assert.equal(constrained.decision.rationale, 'safety_suppressed');
  assert.equal(JSON.stringify(constrained.audit).includes('must not be persisted'), false);
});
