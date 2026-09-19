import { neglectThresholdForTier, tierRank } from './pyramid_tier.js';

/**
 * D-175: per-task view of the checkbox history.
 *
 * The pooled completion rate cannot see one habit being dropped: eleven of
 * twelve tasks checked every day reads as 92% however many consecutive days
 * the twelfth is missed. Trailing streaks computed over the interleaved
 * history have the same blind spot — the run of checked entries from the
 * other tasks resets them. Both are computed per task here instead.
 *
 * `history` is the chronologically ascending checkbox history from the
 * context builder: `{ task, checked, tier, date }`.
 */
export function taskMissStreaks(history = []) {
  const byTask = new Map();
  for (const entry of history) {
    const task = entry?.task;
    if (!task) continue;
    const record = byTask.get(task) || { task, tier: null, missStreak: 0, observed: 0, lastMissReason: null };
    record.tier = entry.tier ?? record.tier;
    record.observed += 1;
    if (entry.checked === true) {
      record.missStreak = 0;
    } else {
      record.missStreak += 1;
      record.lastMissReason = entry.missReason ?? record.lastMissReason;
    }
    byTask.set(task, record);
  }
  return [...byTask.values()];
}

/**
 * Tasks currently being dropped, strongest pyramid tier first and, within a
 * tier, the longest-running neglect first. A task is neglected once its own
 * consecutive misses reach its tier's threshold, whatever the pooled rate.
 */
export function neglectedTasks(history = []) {
  return taskMissStreaks(history)
    .filter((record) => record.missStreak >= neglectThresholdForTier(record.tier))
    .sort((a, b) => tierRank(a.tier) - tierRank(b.tier) || b.missStreak - a.missStreak);
}

/** Longest single-task miss streak, used to escalate the support cadence. */
export function worstMissStreak(history = []) {
  return taskMissStreaks(history).reduce(
    (worst, record) => (record.missStreak > worst ? record.missStreak : worst), 0);
}
