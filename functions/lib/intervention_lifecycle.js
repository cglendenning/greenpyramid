function asMillis(value) {
  const millis = new Date(value).valueOf();
  return Number.isFinite(millis) ? millis : null;
}

/** D-158: lifecycle state is derived immediately before any delivery. */
export function revalidateIntervention(decision, {
  now = new Date(),
  completedTargetIds = [],
  changedTargetIds = [],
  superseded = false,
} = {}) {
  const nowMillis = now.valueOf();
  const expiresAt = asMillis(decision.evaluatedAt) + (decision.validityWindowHours || 0) * 3600000;
  let status = 'pending';
  let reason = null;
  if (decision.type === 'NONE') {
    status = 'suppressed'; reason = 'policy_none';
  } else if (expiresAt <= nowMillis) {
    status = 'expired'; reason = 'validity_window_elapsed';
  } else if (completedTargetIds.includes(decision.target)) {
    status = 'suppressed'; reason = 'target_completed';
  } else if (changedTargetIds.includes(decision.target)) {
    status = 'suppressed'; reason = 'target_changed';
  } else if (superseded) {
    status = 'superseded'; reason = 'newer_decision';
  }
  return { status, reason, revalidatedAt: now.toISOString(), expiresAt: new Date(expiresAt).toISOString() };
}

/** Offline recovery revalidates current context without replaying stale work. */
export function recoverInterventions(decisions, context) {
  return decisions.map((decision) => ({
    decision,
    lifecycle: revalidateIntervention(decision, context),
  }));
}

/** Delivery acceptance is required before a decision can be scored as treatment. */
export function isTreatmentEligible({ lifecycleStatus, deliveryState }) {
  return deliveryState === 'sent' && lifecycleStatus === 'pending';
}

