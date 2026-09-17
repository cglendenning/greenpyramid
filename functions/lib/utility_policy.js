import { INTERVENTION_TYPES, SURFACE_BY_TYPE } from './intervention_taxonomy.js';

const MAX_CANDIDATES = 4;
const BURDEN_WINDOW_DAYS = 7;
const BURDEN_PER_RECENT_INTERVENTION = 0.5;
const SUPPORT_CADENCE = Object.freeze({
  stable: Object.freeze({ sameTypeCooldownDays: 7, maxRecentNonSilent: 1 }),
  emerging: Object.freeze({ sameTypeCooldownDays: 3, maxRecentNonSilent: 2 }),
  persistent: Object.freeze({ sameTypeCooldownDays: 2, maxRecentNonSilent: 4 }),
});
const LIFT_BY_TYPE = Object.freeze({
  REMINDER: 0.10,
  COMMITMENT_REQUEST: 0.08,
  PLAN_PROMPT: 0.12,
  IMPLEMENTATION_INTENTION: 0.14,
  VALUE_REFRAME: 0.06,
  REFLECTION: 0.04,
  INFORMATION_REQUEST: 0.11,
  ENVIRONMENT_PROMPT: 0.13,
  RECOVERY: 0.15,
  CELEBRATION: 0.08,
  SUCCESS_REFLECTION: 0.07,
  TARGET_REVIEW: 0.09,
  CHALLENGE_REVIEW: 0.10,
});
const SECONDARY_UTILITY_BY_TYPE = Object.freeze({
  CELEBRATION: 0.08,
  SUCCESS_REFLECTION: 0.07,
});
const ALTERNATIVE_TYPES_BY_TYPE = Object.freeze({
  REMINDER: ['REFLECTION', 'INFORMATION_REQUEST'],
  COMMITMENT_REQUEST: ['PLAN_PROMPT', 'REFLECTION'],
  PLAN_PROMPT: ['INFORMATION_REQUEST', 'REFLECTION'],
  IMPLEMENTATION_INTENTION: ['PLAN_PROMPT', 'INFORMATION_REQUEST'],
  VALUE_REFRAME: ['REFLECTION', 'INFORMATION_REQUEST'],
  REFLECTION: ['INFORMATION_REQUEST', 'PLAN_PROMPT'],
  INFORMATION_REQUEST: ['PLAN_PROMPT', 'REFLECTION'],
  ENVIRONMENT_PROMPT: ['INFORMATION_REQUEST', 'PLAN_PROMPT'],
  RECOVERY: ['REFLECTION', 'INFORMATION_REQUEST'],
  CELEBRATION: ['SUCCESS_REFLECTION', 'REFLECTION'],
  SUCCESS_REFLECTION: ['CELEBRATION', 'REFLECTION'],
  TARGET_REVIEW: ['INFORMATION_REQUEST', 'REFLECTION'],
  CHALLENGE_REVIEW: ['PLAN_PROMPT', 'REFLECTION'],
});

const OBJECTIVE_BY_TYPE = Object.freeze({
  REMINDER: 'support_next_checkbox',
  COMMITMENT_REQUEST: 'secure_commitment',
  PLAN_PROMPT: 'create_action_plan',
  IMPLEMENTATION_INTENTION: 'create_cue_link',
  VALUE_REFRAME: 'reconnect_to_value',
  REFLECTION: 'learn_from_pattern',
  INFORMATION_REQUEST: 'gather_context',
  ENVIRONMENT_PROMPT: 'reduce_environment_friction',
  RECOVERY: 'restart_after_disruption',
  CELEBRATION: 'acknowledge_completion',
  SUCCESS_REFLECTION: 'learn_success_factors',
  TARGET_REVIEW: 'reassess_target',
  CHALLENGE_REVIEW: 'calibrate_challenge',
});

const REASON_PATTERNS = Object.freeze([
  ['target_change', /\b(no longer|not relevant|irrelevant|changed goal|different goal|don't want|do not want|not important)\b/],
  ['difficulty', /\b(hard|difficult|overwhelm(?:ed|ing)?|too much|pain(?:ful)?|exhaust(?:ed|ing)?|complex)\b/],
  ['environment', /\b(location|equipment|prepare|preparation|setup|weather|commute|friction|not ready|not available)\b/],
  ['disruption', /\b(meeting|busy|sick|ill|unexpected|emergency|travel|interruption|interrupted|forgot|forget)\b/],
  ['information', /\b(not sure|unsure|confused|unclear|don't know|do not know|why|need help)\b/],
  ['planning', /\b(plan|planning|schedule|scheduled|time|later|tomorrow|remember|when|cue|trigger|situation)\b/],
  ['motivation', /\b(value|meaning|motivated|motivation|matters|pointless)\b/],
  ['commitment', /\b(commit|committed|commitment)\b/],
]);

function normalized(value) {
  return typeof value === 'string' ? value.trim().toLowerCase() : '';
}

function dateValue(value) {
  const parsed = new Date(value).valueOf();
  return Number.isFinite(parsed) ? parsed : null;
}

function recentCount(priorInterventions, now) {
  const cutoff = now.getTime() - BURDEN_WINDOW_DAYS * 86400000;
  return priorInterventions.filter((decision) => {
    const at = dateValue(decision.evaluatedAt);
    return at !== null && at >= cutoff && at <= now.getTime() && decision.type !== 'NONE';
  }).length;
}

function recentTypeCount(priorInterventions, type, now, cooldownDays) {
  const cutoff = now.getTime() - cooldownDays * 86400000;
  return priorInterventions.filter((decision) => {
    const at = dateValue(decision.evaluatedAt);
    return at !== null && at >= cutoff && at <= now.getTime() && decision.type === type;
  }).length;
}

function failedTypeCounts(priorInterventions, history, now) {
  const counts = {};
  for (const decision of priorInterventions) {
    if (!decision.type || decision.type === 'NONE' || !INTERVENTION_TYPES.includes(decision.type)) continue;
    const at = dateValue(decision.evaluatedAt);
    if (at === null || at > now.getTime()) continue;
    const response = history
      .map((entry) => ({ entry, at: dateValue(entry.date || entry.taskdate) }))
      .filter(({ at: responseAt }) => responseAt !== null && responseAt > at && responseAt <= now.getTime())
      .sort((a, b) => a.at - b.at)[0];
    if (response && response.entry.checked !== true) counts[decision.type] = (counts[decision.type] || 0) + 1;
  }
  return counts;
}

function trailingStreak(history, checked) {
  let count = 0;
  for (let index = history.length - 1; index >= 0; index -= 1) {
    if (history[index].checked !== checked) break;
    count += 1;
  }
  return count;
}

export function classifyMissReason(reason) {
  const value = normalized(reason);
  if (!value) return 'unknown';
  return REASON_PATTERNS.find(([, pattern]) => pattern.test(value))?.[0] || 'unknown';
}

function deriveSignals({ baseline, target, context = {}, priorInterventions = [], now = new Date() }) {
  const history = Array.isArray(context.checkboxHistory) ? context.checkboxHistory : [];
  const tasks = Array.isArray(context.tasks) ? context.tasks : [];
  const task = tasks.find((candidate) => candidate.description === target) || tasks[0] || null;
  const latestMiss = [...history].reverse().find((entry) => entry.checked !== true) || null;
  const latestReason = latestMiss?.missReason || null;
  const reasonClass = classifyMissReason(latestReason);
  const category = normalized(task?.category);
  const matchingValue = (context.values || []).some((value) => {
    const valueName = normalized(value.name);
    return valueName === category || Boolean(value.description) || Boolean(value.essence);
  });
  const goals = Array.isArray(context.goals) ? context.goals : [];
  const hasValueContext = matchingValue || goals.length > 0;
  const hasCue = Boolean(task?.cue || task?.scheduledTime);
  const hasPlan = Boolean(task?.plan || hasCue);
  const latestChecked = history.at(-1)?.checked === true;
  const completedStreak = trailingStreak(history, true);
  const missedStreak = trailingStreak(history, false);
  const mixedHistory = baseline.completedCount > 0 && baseline.missedCount > 0;
  const observedCount = Number.isInteger(baseline.observedCount)
    ? baseline.observedCount
    : history.length;
  const completionRate = Number.isFinite(baseline.desiredCheckboxCompletion)
    ? baseline.desiredCheckboxCompletion
    : null;
  const supportTier = missedStreak >= 3 ||
      (observedCount >= 3 && completionRate !== null && completionRate <= 0.5)
    ? 'persistent'
    : missedStreak >= 2 ||
        (observedCount >= 2 && completionRate !== null && completionRate < 0.8)
      ? 'emerging'
      : 'stable';
  const needsImplementationIntention = reasonClass === 'planning' &&
    /\b(time|when|cue|trigger|situation|after|before)\b/.test(normalized(latestReason));
  const failedTypeCountsByType = failedTypeCounts(priorInterventions, history, now);

  return {
    task,
    target,
    latestReason,
    reasonClass,
    hasValueContext,
    hasCue,
    hasPlan,
    latestChecked,
    completedStreak,
    missedStreak,
    mixedHistory,
    supportTier,
    failedTypeCounts: failedTypeCountsByType,
    needsImplementationIntention,
    commitmentNeeded: context.commitmentNeeded === true || task?.commitmentRequired === true,
  };
}

function candidate({ type, target, objective, rationale, baseline, burden }) {
  const lift = LIFT_BY_TYPE[type];
  return {
    type,
    target: target ?? null,
    objective: objective || OBJECTIVE_BY_TYPE[type],
    surface: SURFACE_BY_TYPE[type],
    rationale,
    predictedCheckboxCompletion: Math.min(1, (baseline ?? 0) + lift),
    predictedLift: lift,
    secondaryUtility: SECONDARY_UTILITY_BY_TYPE[type] || 0,
    burden,
  };
}

/**
 * D-166: derive a bounded candidate set for every semantic intervention type.
 * Candidate generation is deterministic and semantic; no copy or model call
 * participates in policy selection.
 */
export function generateInterventionCandidates({
  baseline,
  target = null,
  objective = null,
  priorInterventions = [],
  now = new Date(),
  context = {},
} = {}) {
  const baselineValue = Number.isFinite(baseline?.desiredCheckboxCompletion)
    ? baseline.desiredCheckboxCompletion
    : 0;
  const count = recentCount(priorInterventions, now);
  const burden = 1 + count * BURDEN_PER_RECENT_INTERVENTION;
  const signals = deriveSignals({ baseline, target, context, priorInterventions, now });
  const cadence = SUPPORT_CADENCE[signals.supportTier];
  const candidates = [{
    type: 'NONE', target: null, objective: null, surface: 'none',
    rationale: 'no_useful_action', predictedCheckboxCompletion: baselineValue,
    predictedLift: 0, secondaryUtility: 0, burden: 0,
  }];
  const add = (type, reason, explicitObjective = null) => {
    if (!INTERVENTION_TYPES.includes(type) || type === 'NONE' || candidates.some((item) => item.type === type)) return;
    const failedCount = signals.failedTypeCounts[type] || 0;
    const alternativeType = failedCount >= 3
      ? (ALTERNATIVE_TYPES_BY_TYPE[type] || []).find((alternative) =>
        !candidates.some((item) => item.type === alternative) &&
        (signals.failedTypeCounts[alternative] || 0) < 3)
      : null;
    const selectedType = alternativeType || type;
    candidates.push(candidate({
      type: selectedType,
      target,
      objective: explicitObjective,
      rationale: alternativeType ? 'alternate_after_repeated_failure' : reason,
      baseline: baselineValue, burden,
    }));
  };

  if (signals.commitmentNeeded && target) add('COMMITMENT_REQUEST', 'commitment_needed');

  const hasMissOpportunity = Boolean(baseline?.opportunity && target && !signals.latestChecked);
  if (hasMissOpportunity) {
    switch (signals.reasonClass) {
      case 'target_change':
        add('TARGET_REVIEW', 'target_may_no_longer_fit');
        break;
      case 'difficulty':
        add('CHALLENGE_REVIEW', 'challenge_needs_calibration');
        break;
      case 'environment':
        add('ENVIRONMENT_PROMPT', 'environmental_friction');
        break;
      case 'disruption':
        add('RECOVERY', 'disruption_recovery');
        break;
      case 'information':
        add('INFORMATION_REQUEST', 'missing_context');
        break;
      case 'planning':
        add(signals.needsImplementationIntention ? 'IMPLEMENTATION_INTENTION' : 'PLAN_PROMPT',
          signals.needsImplementationIntention ? 'missing_cue_or_time' : 'missing_action_plan');
        break;
      case 'motivation':
        if (signals.hasValueContext) add('VALUE_REFRAME', 'reconnect_to_stated_value');
        else add('REFLECTION', 'notice_motivation_pattern');
        break;
      case 'commitment':
        add('COMMITMENT_REQUEST', 'commitment_needed');
        break;
      default:
        if (signals.commitmentNeeded) break;
        if (signals.missedStreak >= 2 && !signals.hasPlan) add('PLAN_PROMPT', 'repeated_miss_without_plan');
        else if (signals.missedStreak >= 2) add('INFORMATION_REQUEST', 'repeated_miss_without_reason');
        else add('REMINDER', 'recent_completion_risk');
    }
    if (signals.reasonClass === 'motivation' && signals.hasValueContext) add('VALUE_REFRAME', 'reconnect_to_stated_value');
    if (signals.reasonClass === 'planning' && !signals.needsImplementationIntention) add('PLAN_PROMPT', 'missing_action_plan');
  } else if (signals.latestChecked && signals.completedStreak >= 3) {
    if (signals.completedStreak % 2 === 1) add('CELEBRATION', 'success_cadence_acknowledgment');
    else add('SUCCESS_REFLECTION', 'success_cadence_learning');
  } else if (signals.latestChecked && signals.mixedHistory) {
    add('REFLECTION', 'mixed_pattern_learning');
  }

  if (candidates.length === 1 && target && baseline?.opportunity) add('REMINDER', 'recent_completion_risk');
  return {
    candidates: candidates.slice(0, MAX_CANDIDATES),
    signals,
    recentInterventionCount: count,
    burden,
    supportTier: signals.supportTier,
    cadence,
  };
}

/** D-157/D-166: compare bounded semantic candidates with silence. */
export function chooseIntervention({
  baseline,
  target = null,
  objective = null,
  priorInterventions = [],
  now = new Date(),
  context = {},
} = {}) {
  const generated = generateInterventionCandidates({ baseline, target, objective, priorInterventions, now, context });
  const count = generated.recentInterventionCount;
  const cadence = generated.cadence;
  const candidates = generated.candidates.map((item) => ({
    ...item,
    cooldownBlocked: item.type !== 'NONE' && recentTypeCount(priorInterventions, item.type, now, cadence.sameTypeCooldownDays) > 0,
    utilityScore: item.predictedCheckboxCompletion + item.secondaryUtility - item.burden * 0.01,
  }));
  const silence = candidates[0];
  const eligible = candidates
    .filter((item) => item.type !== 'NONE' && !item.cooldownBlocked)
    .sort((a, b) => b.utilityScore - a.utilityScore || b.predictedLift - a.predictedLift);
  const best = eligible[0];
  const cooldownBlockedCandidate = candidates.find((item) => item.type !== 'NONE' && item.cooldownBlocked);
  const selected = count < cadence.maxRecentNonSilent && best && best.utilityScore > silence.utilityScore
    ? best : silence;
  const suppressionReason = selected.type === 'NONE'
    ? count >= cadence.maxRecentNonSilent
      ? 'burden_limit'
      : cooldownBlockedCandidate
        ? 'same_type_cooldown'
        : best && best.utilityScore <= silence.utilityScore
          ? 'low_utility'
          : 'no_eligible_candidate'
    : null;

  return {
    candidates,
    selectedType: selected.type,
    suppressionReason,
    selectionMode: 'deterministic_utility',
    policyVersion: 'intervention-policy-v2',
    derivedSignals: generated.signals,
    burdenAssumptions: {
      recentInterventionCount: count,
      windowDays: BURDEN_WINDOW_DAYS,
      repeatedInterventionPenalty: BURDEN_PER_RECENT_INTERVENTION,
      silenceRecovery: selected.type === 'NONE' && count > 0,
      supportTier: generated.supportTier,
      maxRecentNonSilent: cadence.maxRecentNonSilent,
      typeCooldownDays: cadence.sameTypeCooldownDays,
      repeatedTypeFailureThreshold: 3,
    },
    burdenAfterSelection: selected.type === 'NONE' ? Math.max(0, count - 1) : count + 1,
    safetyBound: { maxCandidates: MAX_CANDIDATES, allowedTypes: INTERVENTION_TYPES },
  };
}
