import { resolveTier, tierForPosition } from './pyramid_tier.js';

function text(value) {
  return typeof value === 'string' && value.trim() ? value.trim() : null;
}

function boolean(value) {
  return value === true || value === 'true' || value === 1;
}

function categoryName(category) {
  return text(category?.name) || text(category?.cat);
}

// D-174: a task and a check-in each inherit the pyramid tier of their
// category. Derived from the user's own category position; no new subject
// classification and no new field from the consumer app (D-154-AC-02).
function tierFor(categories, { categoryId, categoryName: name }) {
  return resolveTier({ categoryId, categoryName: name, categories });
}

/**
 * D-154: normalize only user-defined context. Missing relationships remain
 * null; this builder never introduces a subject taxonomy or inferred facts.
 */
export function buildInterventionContext({ profile = {}, tasks = [], recentActivity = [] }) {
  const categories = (Array.isArray(profile.categories) ? profile.categories : [])
    .slice(0, 6)
    .map((category) => ({
      id: category.id ?? category.position ?? null,
      position: category.position ?? null,
      name: categoryName(category),
      valueDescription: text(category.description),
      essence: text(category.activeEssence),
      tier: tierForPosition(category.position ?? category.id),
    }))
    .filter((category) => category.name);

  const goals = (Array.isArray(profile.goals) ? profile.goals : [])
    .map((goal) => text(goal?.text ?? goal))
    .filter(Boolean)
    .map((value) => ({ text: value, source: 'user' }));
  const vision = text(profile.visionStatement);
  if (vision) goals.push({ text: vision, source: 'user' });

  return {
    values: categories.map(({ id, position, name, valueDescription, essence }) => ({
      id, position, name, description: valueDescription, essence,
    })),
    goals,
    categories,
    tasks: tasks
      .filter((task) => task.active !== false && task.deleted !== true)
      .map((task) => ({
        id: task.id ?? null,
        description: text(task.description) || text(task.taskdescription),
        category: text(task.category),
        categoryId: task.categoryId ?? null,
        scheduledTime: text(task.scheduledtime) || text(task.scheduledTime),
        plan: text(task.plan) || text(task.nextStep),
        cue: text(task.cue) || text(task.implementationIntention),
        commitmentRequired: boolean(task.commitmentRequired),
        challengeLevel: text(task.challengeLevel),
        tier: tierFor(categories, {
          categoryId: task.categoryId ?? null,
          categoryName: text(task.category),
        }),
      })),
    checkboxHistory: recentActivity.map((entry) => ({
      date: text(entry.taskdate) || text(entry.date),
      category: text(entry.category),
      task: text(entry.taskdescription) || text(entry.description),
      checked: boolean(entry.checked),
      missReason: text(entry.missreason) || text(entry.missReason),
      tier: tierFor(categories, {
        categoryId: entry.categoryId ?? null,
        categoryName: text(entry.category),
      }),
    })),
    commitmentNeeded: boolean(profile.commitmentNeeded),
  };
}
