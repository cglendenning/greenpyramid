import { createHash } from 'node:crypto';
import { buildInterventionContext } from './intervention_context.js';
import { estimateBaseline } from './baseline_estimator.js';
import { validateInterventionDecision } from './intervention_taxonomy.js';
import { chooseIntervention } from './utility_policy.js';
import { resolveTier, tierRank } from './pyramid_tier.js';

const LOOKBACK_DAYS = 14;
const AUTONOMOUS_COMPLETION_THRESHOLD = 0.8;

function asDate(value) {
  if (value instanceof Date) return value;
  if (value?.toDate) return value.toDate();
  const parsed = new Date(value);
  return Number.isNaN(parsed.valueOf()) ? null : parsed;
}

function isChecked(value) {
  return value === true || value === 'true' || value === 1;
}

/** Day granularity, matching how check-ins are actually recorded (D-174). */
function dayKey(entry) {
  const date = asDate(entry.taskdate || entry.date);
  return date ? date.toISOString().slice(0, 10) : '';
}

function tierOf(context, entry) {
  return resolveTier({
    categoryId: entry.categoryId ?? null,
    categoryName: entry.category ?? null,
    categories: context.categories || [],
  });
}

function stableDecisionId(accountUid, now, state) {
  const fingerprint = JSON.stringify({
    accountUid,
    at: now.toISOString(),
    observed: state.observedCount,
    completed: state.completedCount,
    target: state.target,
  });
  return createHash('sha256').update(fingerprint).digest('hex').slice(0, 32);
}

function noneDecision({ accountUid, now, reason, state, decisionId, context, baseline, policy }) {
  return {
    decisionId: decisionId || stableDecisionId(accountUid, now, state),
    accountUid,
    evaluatedAt: now.toISOString(),
    type: 'NONE',
    surface: 'none',
    target: null,
    objective: null,
    rationale: reason,
    context,
    baseline,
    policy,
    validityWindowHours: 0,
    measurementWindowDays: 0,
    outcome: {
      primary: 'checkbox_completion_quantity',
      observedCount: state.observedCount,
      completedCount: state.completedCount,
      completionRate: state.completionRate,
    },
  };
}

function selectedDecision({ accountUid, now, state, decisionId, context, baseline, policy }) {
  const selected = policy.candidates.find((candidate) => candidate.type === policy.selectedType);
  if (!selected || selected.type === 'NONE') {
    return noneDecision({ accountUid, now, reason: 'no_useful_action', state, decisionId, context, baseline, policy });
  }
  return validateInterventionDecision({
    decisionId: decisionId || stableDecisionId(accountUid, now, state),
    accountUid,
    evaluatedAt: now.toISOString(),
    type: selected.type,
    surface: selected.surface,
    target: selected.target,
    objective: selected.objective,
    rationale: selected.rationale,
    context,
    baseline,
    policy,
    validityWindowHours: 24,
    measurementWindowDays: 1,
    outcome: {
      primary: 'checkbox_completion_quantity',
      observedCount: state.observedCount,
      completedCount: state.completedCount,
      completionRate: state.completionRate,
    },
  });
}

/**
 * D-152/D-166: cloud-service policy boundary. This function is deliberately pure:
 * model copy, delivery and client presentation cannot select the policy.
 */
export function evaluateIntervention({
  accountUid,
  profile = {},
  tasks = [],
  recentActivity = [],
  priorInterventions = [],
  now = new Date(),
  decisionId,
}) {
  if (!accountUid) throw new Error('account_uid_required');
  const current = asDate(now) || new Date();
  const activeTasks = tasks.filter((task) => task.active !== false && task.deleted !== true);
  const cutoff = new Date(current.getTime() - LOOKBACK_DAYS * 86400000);
  const observed = recentActivity.filter((entry) => {
    const date = asDate(entry.taskdate || entry.date);
    return date && date >= cutoff && date <= current;
  }).sort((a, b) => asDate(a.taskdate || a.date) - asDate(b.taskdate || b.date));
  const completedCount = observed.filter((entry) => isChecked(entry.checked)).length;
  const observedCount = observed.length;
  const completionRate = observedCount ? completedCount / observedCount : null;
  const baseline = estimateBaseline({ recentActivity: observed });
  const context = buildInterventionContext({ profile, tasks, recentActivity: observed });
  // D-174: check-ins are recorded with day granularity, so several misses
  // normally share the most recent date. Recency still decides first; the
  // pyramid tier then decides which of that day's misses the single decision
  // addresses, replacing what was previously an arbitrary ordering tiebreak.
  const missedEntries = observed.filter((entry) => !isChecked(entry.checked));
  const latestMissDay = missedEntries.length
    ? missedEntries.reduce((latest, entry) => {
      const day = dayKey(entry);
      return latest === null || day > latest ? day : latest;
    }, null)
    : null;
  const missed = missedEntries
    .filter((entry) => dayKey(entry) === latestMissDay)
    .sort((a, b) => tierRank(tierOf(context, a)) - tierRank(tierOf(context, b)))[0];
  const target = missed?.taskdescription || activeTasks[0]?.description || activeTasks[0]?.taskdescription || null;
  const state = { observedCount, completedCount, completionRate, target };
  const policy = chooseIntervention({
    baseline, target, objective: 'support_next_checkbox', priorInterventions, now: current, context,
  });

  if (profile.setupComplete !== true) {
    return validateInterventionDecision(noneDecision({ accountUid, now: current, reason: 'setup_incomplete', state, decisionId, context, baseline, policy }));
  }
  if (!activeTasks.length) {
    return validateInterventionDecision(noneDecision({ accountUid, now: current, reason: 'no_active_habits', state, decisionId, context, baseline, policy }));
  }
  if (!observedCount && policy.selectedType !== 'COMMITMENT_REQUEST') {
    return validateInterventionDecision(noneDecision({ accountUid, now: current, reason: 'insufficient_history', state, decisionId, context, baseline, policy }));
  }
  if (completionRate >= AUTONOMOUS_COMPLETION_THRESHOLD &&
      !['CELEBRATION', 'SUCCESS_REFLECTION'].includes(policy.selectedType)) {
    return validateInterventionDecision(noneDecision({ accountUid, now: current, reason: 'autonomous_completion', state, decisionId, context, baseline, policy }));
  }

  if (policy.selectedType === 'NONE') {
    return validateInterventionDecision(noneDecision({
      accountUid,
      now: current,
      reason: policy.suppressionReason || 'no_useful_action',
      state,
      decisionId,
      context,
      baseline,
      policy,
    }));
  }
  return selectedDecision({ accountUid, now: current, state, decisionId, context, baseline, policy });
}
