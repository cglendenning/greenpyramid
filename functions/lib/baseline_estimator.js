/**
 * D-155: estimate the no-intervention checkbox outcome from observed history.
 * This module contains no copy or delivery behavior, so detection remains
 * independently testable from rendering and transport.
 */
export function estimateBaseline({ recentActivity = [] }) {
  const observedCount = recentActivity.length;
  const completedCount = recentActivity.filter((entry) =>
    entry.checked === true || entry.checked === 'true' || entry.checked === 1).length;
  const completionRate = observedCount ? completedCount / observedCount : null;
  const missedCount = observedCount - completedCount;
  const opportunity = missedCount > 0 && completionRate < 0.8
    ? { kind: 'completion_risk', reason: 'recent_completion_risk' }
    : null;

  return {
    desiredCheckboxCompletion: completionRate,
    observedCount,
    completedCount,
    missedCount,
    opportunity,
  };
}

