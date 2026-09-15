import { INTERVENTION_TYPES } from './intervention_taxonomy.js';

const MAX_CANDIDATES = 2;
const BURDEN_WINDOW_DAYS = 7;
const BURDEN_LIMIT = 3;

function recentCount(priorInterventions, now) {
  const cutoff = now.getTime() - BURDEN_WINDOW_DAYS * 86400000;
  return priorInterventions.filter((decision) => {
    const at = new Date(decision.evaluatedAt).valueOf();
    return Number.isFinite(at) && at >= cutoff && at <= now.getTime() && decision.type !== 'NONE';
  }).length;
}

/** D-157: bounded, auditable utility selection; no copy or model call. */
export function chooseIntervention({ baseline, target = null, objective = null, priorInterventions = [], now = new Date() }) {
  const count = recentCount(priorInterventions, now);
  const candidates = [
    { type: 'NONE', predictedCheckboxCompletion: baseline.desiredCheckboxCompletion, burden: 0 },
  ];
  if (baseline.opportunity && target) {
    candidates.push({
      type: 'REMINDER',
      target,
      objective,
      predictedCheckboxCompletion: Math.min(1, (baseline.desiredCheckboxCompletion ?? 0) + 0.1),
      burden: 1 + count * 0.5,
    });
  }
  const boundedCandidates = candidates.slice(0, MAX_CANDIDATES);
  const reminder = boundedCandidates.find((candidate) => candidate.type === 'REMINDER');
  const selectedType = reminder && count < BURDEN_LIMIT &&
      reminder.predictedCheckboxCompletion - (baseline.desiredCheckboxCompletion ?? 0) > reminder.burden * 0.01
    ? 'REMINDER'
    : 'NONE';

  return {
    candidates: boundedCandidates,
    selectedType,
    selectionMode: 'deterministic_utility',
    burdenAssumptions: {
      recentInterventionCount: count,
      windowDays: BURDEN_WINDOW_DAYS,
      repeatedInterventionPenalty: 0.5,
      silenceRecovery: count > 0,
    },
    burdenAfterSelection: selectedType === 'NONE' ? Math.max(0, count - 1) : count + 1,
    safetyBound: { maxCandidates: MAX_CANDIDATES, allowedTypes: INTERVENTION_TYPES },
  };
}

