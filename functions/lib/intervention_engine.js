import { createHash } from 'node:crypto';
import { buildInterventionContext } from './intervention_context.js';

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

function noneDecision({ accountUid, now, reason, state, decisionId, context }) {
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

/**
 * D-152: server-owned policy boundary. This function is deliberately pure:
 * model copy, delivery and client presentation cannot select the policy.
 */
export function evaluateIntervention({
  accountUid,
  profile = {},
  tasks = [],
  recentActivity = [],
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
  });
  const completedCount = observed.filter((entry) => isChecked(entry.checked)).length;
  const observedCount = observed.length;
  const completionRate = observedCount ? completedCount / observedCount : null;
  const context = buildInterventionContext({ profile, tasks, recentActivity: observed });
  const state = { observedCount, completedCount, completionRate, target: null };

  if (profile.setupComplete !== true) {
    return noneDecision({ accountUid, now: current, reason: 'setup_incomplete', state, decisionId, context });
  }
  if (!activeTasks.length) {
    return noneDecision({ accountUid, now: current, reason: 'no_active_habits', state, decisionId, context });
  }
  if (!observedCount) {
    return noneDecision({ accountUid, now: current, reason: 'insufficient_history', state, decisionId, context });
  }
  if (completionRate >= AUTONOMOUS_COMPLETION_THRESHOLD) {
    return noneDecision({ accountUid, now: current, reason: 'autonomous_completion', state, decisionId, context });
  }

  const missed = observed.find((entry) => !isChecked(entry.checked));
  const target = missed?.taskdescription || activeTasks[0].description || activeTasks[0].taskdescription || null;
  state.target = target;
  return {
    decisionId: decisionId || stableDecisionId(accountUid, current, state),
    accountUid,
    evaluatedAt: current.toISOString(),
    type: 'REMINDER',
    surface: 'in_app',
    target,
    objective: 'support_next_checkbox',
    rationale: 'recent_completion_risk',
    context,
    validityWindowHours: 24,
    measurementWindowDays: 1,
    outcome: {
      primary: 'checkbox_completion_quantity',
      observedCount,
      completedCount,
      completionRate,
    },
  };
}
