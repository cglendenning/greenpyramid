import { evaluateIntervention } from './intervention_engine.js';
import { applySafetyConstraints } from './safety_constraints.js';
import { revalidateIntervention } from './intervention_lifecycle.js';
import { renderIntervention } from './intervention_renderer.js';
import { seededRandom } from './deterministic_random.js';
import { tierForPosition } from './pyramid_tier.js';

export const DEBUGGER_ACCOUNT_UID = 'debugger-sandbox';

// D-173: a stock six-category pyramid shaped like a real one (free-text
// category names, two to three tasks each) rather than the single fixed
// habit D-162's named scenarios use, so the engine sees the same shape of
// context it would for a real account.
const STOCK_CATEGORIES = Object.freeze([
  { cat: 'Health', description: 'Take care of my body', tasks: ['Morning walk', 'Cook a real dinner', 'Stretch before bed'] },
  { cat: 'Deep Work', description: 'Do work that matters', tasks: ['Focused writing block', 'Clear the inbox', 'Plan tomorrow'] },
  { cat: 'Family', description: 'Show up for the people I love', tasks: ['Call a parent', 'Family dinner, no phones'] },
  { cat: 'Finances', description: 'Build a stable future', tasks: ['Review spending', 'Add to savings'] },
  { cat: 'Creative Practice', description: 'Keep making things', tasks: ['Sketch for 15 minutes', 'Practice guitar'] },
  { cat: 'Rest', description: 'Protect recovery', tasks: ['Lights out by 11', 'One screen-free hour'] },
]);

/** D-173-AC-01: deterministic stock pyramid generation from a seed. */
export function generateStockPyramid({ seed = 1 } = {}) {
  if (!Number.isInteger(seed) || !Number.isSafeInteger(seed)) throw new Error('seed_invalid');
  const draw = seededRandom(seed);
  const categories = STOCK_CATEGORIES.map((source, index) => ({
    position: index + 1,
    cat: source.cat,
    description: source.description,
    activeEssence: null,
    // D-174-AC-06: the operator can see which tier each task sits in.
    tier: tierForPosition(index + 1),
  }));
  const tasks = STOCK_CATEGORIES.flatMap((source, categoryIndex) => {
    const count = 2 + (draw() > 0.5 ? 1 : 0);
    return source.tasks.slice(0, Math.min(count, source.tasks.length)).map((description, taskIndex) => ({
      id: `debug-task-${categoryIndex + 1}-${taskIndex + 1}`,
      description,
      category: source.cat,
      categoryId: categoryIndex + 1,
      tier: tierForPosition(categoryIndex + 1),
      active: true,
      scheduledTime: null,
      cue: null,
      plan: null,
      commitmentRequired: false,
      challengeLevel: null,
    }));
  });
  return { seed, categories, tasks };
}

const MAX_HISTORY_ENTRIES = 3650;
const MAX_TASKS = 24;

function assertBounded(name, value, max) {
  if (!Array.isArray(value)) throw new Error(`${name}_invalid`);
  if (value.length > max) throw new Error(`${name}_invalid`);
  return value;
}

/**
 * D-173-AC-03: run the identical production sequence — evaluateIntervention,
 * applySafetyConstraints, revalidateIntervention, renderIntervention — for
 * one operator-authored virtual day. The operator supplies the day's
 * evidence; this function does not let them choose the decision.
 */
export function evaluateDebuggerDay({
  profile = {},
  tasks = [],
  recentActivity = [],
  priorInterventions = [],
  safetyTriggers = [],
  now = new Date(),
} = {}) {
  assertBounded('tasks', tasks, MAX_TASKS);
  assertBounded('recentActivity', recentActivity, MAX_HISTORY_ENTRIES);
  assertBounded('priorInterventions', priorInterventions, MAX_HISTORY_ENTRIES);
  assertBounded('safetyTriggers', safetyTriggers, 5);

  const decision = evaluateIntervention({
    accountUid: DEBUGGER_ACCOUNT_UID,
    profile: { setupComplete: true, ...profile },
    tasks,
    recentActivity,
    priorInterventions,
    now,
  });
  const constrained = applySafetyConstraints({
    decision,
    decisionId: decision.decisionId,
    triggers: safetyTriggers,
    now,
  });
  const lifecycle = revalidateIntervention(constrained.decision, { now });
  const rendered = renderIntervention(constrained.decision);
  return { ...constrained.decision, safety: constrained.audit, lifecycle, rendered };
}
