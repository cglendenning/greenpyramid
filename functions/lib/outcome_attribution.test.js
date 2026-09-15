import test from 'node:test';
import assert from 'node:assert/strict';
import { attributeCheckboxOutcome, buildLearningExample } from './outcome_attribution.js';

const base = {
  experimentId: 'exp-1', decisionId: 'decision-1', target: 'habit-1',
  deliveredAt: '2026-09-15T10:00:00Z', measurementWindowDays: 1, deliveryState: 'sent',
};

test('D-160-AC-01: an experiment records target checkbox completion inside its measurement window', () => {
  const outcome = attributeCheckboxOutcome({
    ...base,
    events: [
      { type: 'checkbox', target: 'habit-1', occurredAt: '2026-09-15T11:00:00Z', checked: true, postDeployment: true },
      { type: 'checkbox', target: 'habit-1', occurredAt: '2026-09-16T12:01:00Z', checked: true, postDeployment: true },
    ],
  });

  assert.equal(outcome.primaryOutcome.name, 'checkbox_completion_quantity');
  assert.equal(outcome.primaryOutcome.completionCount, 1);
  assert.equal(outcome.primaryOutcome.measuredWithinWindow, true);
});

test('D-160-AC-02: delivery and technical failures are not behavioral treatment failures', () => {
  const outcome = attributeCheckboxOutcome({
    ...base, deliveryState: 'failed', events: [{ type: 'technical_failure', postDeployment: true }],
  });

  assert.equal(outcome.attributionQualified, false);
  assert.equal(outcome.primaryOutcome.measuredWithinWindow, false);
  assert.equal(outcome.primaryOutcome.completionCount, 0);
});

test('D-160-AC-03: learning accepts only qualified post-deployment data and carries a model version', () => {
  const attribution = attributeCheckboxOutcome({ ...base, events: [] });
  const example = buildLearningExample({ attribution, modelVersion: 'engine-v1' });

  assert.equal(example.modelVersion, 'engine-v1');
  assert.equal(example.source, 'post_deployment_attribution');
  assert.equal(buildLearningExample({ attribution: { attributionQualified: false }, modelVersion: 'engine-v1' }), null);
});

