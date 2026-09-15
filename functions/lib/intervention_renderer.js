import { deterministicFallback, validateInterventionDecision } from './intervention_taxonomy.js';

const MAX_COPY = 280;

function bounded(value) {
  return typeof value === 'string' ? value.trim().slice(0, MAX_COPY) : '';
}

function fallbackCopy(decision) {
  if (decision.type === 'NONE') return { title: '', body: '' };
  const target = bounded(decision.target) || 'the next thing that matters';
  const copy = {
    REMINDER: `A small step toward ${target} is still available.`,
    COMMITMENT_REQUEST: `Would you like to choose a small next step for ${target}?`,
    PLAN_PROMPT: `What is your simplest plan for ${target}?`,
    IMPLEMENTATION_INTENTION: `When will you make room for ${target}?`,
    VALUE_REFRAME: `Let ${target} reflect what matters to you.`,
    REFLECTION: `Take a moment to notice what ${target} is teaching you.`,
    INFORMATION_REQUEST: `What would help you understand ${target} better?`,
    ENVIRONMENT_PROMPT: `What could make ${target} easier to begin?`,
    RECOVERY: `A gentle restart with ${target} is enough for today.`,
    CELEBRATION: `You made progress with ${target}.`,
    SUCCESS_REFLECTION: `What helped you complete ${target}?`,
    TARGET_REVIEW: `Is ${target} still the right target?`,
    CHALLENGE_REVIEW: `What would make ${target} more challenging in a useful way?`,
  };
  return { title: 'A thought for today', body: copy[decision.type] || `Consider ${target}.` };
}

/** D-159: rendering consumes semantic data; it cannot select or alter policy. */
export function renderIntervention(decision, { modelCopy = null } = {}) {
  validateInterventionDecision(decision);
  const fallback = fallbackCopy(decision);
  const title = bounded(modelCopy?.title);
  const body = bounded(modelCopy?.body);
  return {
    type: decision.type,
    target: decision.target,
    title: title || fallback.title,
    body: body || fallback.body,
    renderedBy: title && body ? 'model' : 'deterministic_fallback',
  };
}

export function interpretFreeFormReply({ accountUid, decisionId, originalText, interpretation = null, source = 'model' }) {
  if (!accountUid || !decisionId || typeof originalText !== 'string') throw new Error('reply_provenance_invalid');
  return {
    accountUid,
    decisionId,
    originalText: originalText.slice(0, 4000),
    interpretation,
    provenance: { source, preservedAt: new Date().toISOString() },
  };
}

export function rendererFallbackFor(type, target = null) {
  return renderIntervention({ ...deterministicFallback(type, { target, objective: 'fallback' }), decisionId: 'fallback' });
}

