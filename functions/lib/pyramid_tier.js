/**
 * D-174: pyramid tier, derived only from the position the user already gave a
 * category. Distinct from the stable/emerging/persistent *support* tier, which
 * is about cadence and comes from streaks.
 */
export const TIER_FOUNDATIONAL = 'foundational';
export const TIER_ESSENTIAL = 'essential';
export const TIER_PEAK = 'peak';

const TIER_WEIGHTS = Object.freeze({
  [TIER_FOUNDATIONAL]: 1.0,
  [TIER_ESSENTIAL]: 0.9,
  [TIER_PEAK]: 0.8,
});

const TIER_RANKS = Object.freeze({
  [TIER_FOUNDATIONAL]: 0,
  [TIER_ESSENTIAL]: 1,
  [TIER_PEAK]: 2,
});

export function tierForPosition(position) {
  const value = Number(position);
  if (!Number.isInteger(value) || value < 1 || value > 6) return null;
  if (value <= 3) return TIER_FOUNDATIONAL;
  if (value <= 5) return TIER_ESSENTIAL;
  return TIER_PEAK;
}

/** An unresolved tier is neutral: it never reduces support (D-174-AC-04). */
export function tierWeight(tier) {
  return TIER_WEIGHTS[tier] ?? 1.0;
}

/** Lower sorts first. An unresolved tier goes last (D-174-AC-02). */
export function tierRank(tier) {
  return TIER_RANKS[tier] ?? 3;
}

function normalizedName(value) {
  return typeof value === 'string' ? value.trim().toLowerCase() : '';
}

/**
 * Resolve a tier from whatever links a task or check-in to a category: the
 * category identifier where the record carries one, otherwise the category
 * name it already carries. Requires no new field from the consumer app.
 */
export function resolveTier({ categoryId = null, categoryName = null, categories = [] }) {
  if (!Array.isArray(categories) || !categories.length) return null;
  const byId = categoryId === null || categoryId === undefined
    ? null
    : categories.find((category) => category.id === categoryId || category.position === categoryId);
  if (byId) return tierForPosition(byId.position ?? byId.id);
  const name = normalizedName(categoryName);
  if (!name) return null;
  const byName = categories.find((category) => normalizedName(category.name) === name);
  return byName ? tierForPosition(byName.position ?? byName.id) : null;
}

/**
 * D-175: how many consecutive misses of one task constitute neglect. A
 * foundational habit earns attention sooner than a peak one; an unresolved
 * tier uses the middle threshold so it is never the hardest to notice.
 */
const NEGLECT_THRESHOLDS = Object.freeze({
  [TIER_FOUNDATIONAL]: 2,
  [TIER_ESSENTIAL]: 3,
  [TIER_PEAK]: 4,
});

export function neglectThresholdForTier(tier) {
  return NEGLECT_THRESHOLDS[tier] ?? 3;
}
