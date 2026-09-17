export const INTERVENTION_TYPES = Object.freeze([
  'NONE', 'REMINDER', 'COMMITMENT_REQUEST', 'PLAN_PROMPT',
  'IMPLEMENTATION_INTENTION', 'VALUE_REFRAME', 'REFLECTION',
  'INFORMATION_REQUEST', 'ENVIRONMENT_PROMPT', 'RECOVERY', 'CELEBRATION',
  'SUCCESS_REFLECTION', 'TARGET_REVIEW', 'CHALLENGE_REVIEW',
]);

const SURFACES = new Set(['none', 'push', 'inbox', 'in_app', 'council', 'dedicated', 'local']);

export const SURFACE_BY_TYPE = Object.freeze({
  REMINDER: 'in_app',
  COMMITMENT_REQUEST: 'council',
  PLAN_PROMPT: 'council',
  IMPLEMENTATION_INTENTION: 'council',
  VALUE_REFRAME: 'in_app',
  REFLECTION: 'council',
  INFORMATION_REQUEST: 'council',
  ENVIRONMENT_PROMPT: 'council',
  RECOVERY: 'in_app',
  CELEBRATION: 'in_app',
  SUCCESS_REFLECTION: 'council',
  TARGET_REVIEW: 'council',
  CHALLENGE_REVIEW: 'council',
});

/** D-156: semantic decision validation is independent of copy and delivery. */
export function validateInterventionDecision(decision) {
  if (!decision || !INTERVENTION_TYPES.includes(decision.type)) throw new Error('intervention_type_invalid');
  if (!('target' in decision) || !('objective' in decision)) throw new Error('intervention_fields_missing');
  if (!Number.isInteger(decision.validityWindowHours) || decision.validityWindowHours < 0) {
    throw new Error('validity_window_invalid');
  }
  if (!Number.isInteger(decision.measurementWindowDays) || decision.measurementWindowDays < 0) {
    throw new Error('measurement_window_invalid');
  }
  if (!SURFACES.has(decision.surface)) throw new Error('intervention_surface_invalid');
  return decision;
}

/**
 * Deterministic client-safe fallback. It preserves semantic type and target
 * while omitting copy; delivery layers may render it without selecting policy.
 */
export function deterministicFallback(type, { target = null, objective = null } = {}) {
  if (!INTERVENTION_TYPES.includes(type)) throw new Error('intervention_type_invalid');
  const silent = type === 'NONE';
  return {
    type,
    target: silent ? null : target,
    objective: silent ? null : objective,
    validityWindowHours: silent ? 0 : 24,
    measurementWindowDays: silent ? 0 : 1,
    surface: silent ? 'none' : SURFACE_BY_TYPE[type] || 'in_app',
  };
}
