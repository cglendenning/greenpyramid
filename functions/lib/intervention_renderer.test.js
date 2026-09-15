import test from 'node:test';
import assert from 'node:assert/strict';
import { interpretFreeFormReply, renderIntervention, rendererFallbackFor } from './intervention_renderer.js';

const decision = {
  type: 'REMINDER', target: 'Walk', objective: 'support_next_checkbox', surface: 'in_app',
  validityWindowHours: 24, measurementWindowDays: 1,
};

test('D-159-AC-01: valid copy renders and malformed or unavailable copy falls back deterministically', () => {
  assert.equal(renderIntervention(decision, { modelCopy: { title: 'Today', body: 'Walk gently.' } }).renderedBy, 'model');
  const fallback = renderIntervention(decision, { modelCopy: { title: '', body: null } });
  assert.equal(fallback.renderedBy, 'deterministic_fallback');
  assert.equal(fallback.body, 'A small step toward Walk is still available.');
  assert.equal(rendererFallbackFor('RECOVERY', 'Rest').body, 'A gentle restart with Rest is enough for today.');
});

test('D-159-AC-02: renderer output cannot alter semantic type or select policy', () => {
  const rendered = renderIntervention(decision, { modelCopy: { title: 'Different', body: 'Copy only.' } });

  assert.equal(rendered.type, 'REMINDER');
  assert.equal(rendered.target, 'Walk');
  assert.equal(rendered.policy, undefined);
});

test('D-159-AC-03: free-form replies retain original text, interpretation and provenance', () => {
  const reply = interpretFreeFormReply({
    accountUid: 'account-1', decisionId: 'decision-1', originalText: 'I can do it after lunch.',
    interpretation: { commitment: true }, source: 'model',
  });

  assert.equal(reply.originalText, 'I can do it after lunch.');
  assert.deepEqual(reply.interpretation, { commitment: true });
  assert.deepEqual(reply.provenance.source, 'model');
  assert.equal(reply.accountUid, 'account-1');
});

