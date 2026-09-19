/**
 * D-176: same-day breadth of failure.
 *
 * D-175 gave the engine depth — one habit dropped day after day. Breadth is
 * the orthogonal blind spot: a day where most of the pyramid collapses at
 * once. The pooled completion rate cannot represent it, because it averages
 * the whole 14-day window; six ordinary days plus one day with eleven of
 * twelve missed still reads 84.5%, above the autonomous threshold, so the
 * engine stayed silent through exactly the moment support matters most.
 * Per-task streaks miss it too: on the first bad day every streak is 1.
 */
const COLLAPSE_SHARE = 0.5;
const MIN_COLLAPSE_MISSES = 2;

/** Day granularity, tolerating both `yyyy-MM-dd` and full ISO timestamps. */
function dayKey(value) {
  return typeof value === 'string' ? value.slice(0, 10) : '';
}

/**
 * Summarize the most recent recorded day on its own terms, independent of the
 * lookback average. `history` is the context builder's checkbox history.
 */
export function latestDaySummary(history = []) {
  const days = history.filter((entry) => dayKey(entry?.date));
  if (!days.length) {
    return { date: null, observed: 0, missed: 0, completion: null, collapse: false, missedTasks: [] };
  }
  const latest = days.reduce(
    (newest, entry) => (dayKey(entry.date) > newest ? dayKey(entry.date) : newest), '');
  const rows = days.filter((entry) => dayKey(entry.date) === latest);
  const missedRows = rows.filter((entry) => entry.checked !== true);
  const observed = rows.length;
  const missed = missedRows.length;
  return {
    date: latest,
    observed,
    missed,
    completion: observed ? (observed - missed) / observed : null,
    // A proportion rather than a count, so it holds for pyramids of any size;
    // the floor keeps a one-of-two day from reading as a collapse.
    collapse: missed >= MIN_COLLAPSE_MISSES && observed > 0 && missed / observed >= COLLAPSE_SHARE,
    missedTasks: missedRows.map((entry) => entry.task).filter(Boolean),
  };
}
