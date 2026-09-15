function text(value) {
  return typeof value === 'string' && value.trim() ? value.trim() : null;
}

function categoryName(category) {
  return text(category?.name) || text(category?.cat);
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
      })),
    checkboxHistory: recentActivity.map((entry) => ({
      date: text(entry.taskdate) || text(entry.date),
      category: text(entry.category),
      task: text(entry.taskdescription) || text(entry.description),
      checked: entry.checked === true || entry.checked === 'true' || entry.checked === 1,
    })),
  };
}

