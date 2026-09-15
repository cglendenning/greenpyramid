import { createHash } from 'node:crypto';

export const APPROVED_TRIGGER_CATEGORIES = Object.freeze([
  'self_harm', 'medical_crisis', 'illegal_activity', 'abuse_or_coercion', 'privacy_or_security',
]);

const priority = new Map(APPROVED_TRIGGER_CATEGORIES.map((value, index) => [value, index]));

/** D-161: safety executes before rendering/delivery and stores no trigger text. */
export function applySafetyConstraints({ decision, decisionId, triggers = [], policyVersion = 'safety-v1', now = new Date() }) {
  const approved = triggers
    .filter((trigger) => APPROVED_TRIGGER_CATEGORIES.includes(trigger?.type))
    .sort((a, b) => priority.get(a.type) - priority.get(b.type));
  const trigger = approved[0];
  const audit = {
    auditId: createHash('sha256').update(`${decisionId}:${trigger?.type || 'none'}:${policyVersion}`).digest('hex').slice(0, 32),
    triggerType: trigger?.type || null,
    decisionId,
    action: trigger ? 'suppress' : 'allow',
    policyVersion,
    timestamp: now.toISOString(),
  };
  if (!trigger) return { allowed: true, decision, audit };
  return {
    allowed: false,
    decision: {
      ...decision,
      type: 'NONE', surface: 'none', target: null, objective: null,
      rationale: 'safety_suppressed', safetySuppressed: true,
    },
    audit,
  };
}

