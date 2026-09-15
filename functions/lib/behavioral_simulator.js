import { evaluateIntervention } from './intervention_engine.js';

export const REQUIRED_SCENARIOS = Object.freeze([
  'autonomous', 'responsive', 'fatigue', 'sequence', 'changing', 'difficult', 'mature',
]);

const PRODUCTION_PROJECT = /(^|[-_])(?:prod|production)([-_]|$)|life-ops/i;

export function assertSandboxTarget({ projectId, credentials = false } = {}) {
  if (!projectId || PRODUCTION_PROJECT.test(projectId) || credentials) {
    throw new Error('production_target_rejected');
  }
  if (!projectId.endsWith('-sandbox')) throw new Error('sandbox_project_required');
  return true;
}

function random(seed) {
  let value = seed >>> 0;
  return () => {
    value = (1664525 * value + 1013904223) >>> 0;
    return value / 4294967296;
  };
}

function checkedForScenario(name, day, draw) {
  switch (name) {
    case 'autonomous': return true;
    case 'responsive': return day >= 5 || day % 4 !== 0;
    case 'fatigue': return day < 45 ? draw() > 0.1 : draw() > 0.55;
    case 'sequence': return day % 3 !== 1;
    case 'changing': return day < 60 ? draw() > 0.2 : draw() > 0.45;
    case 'difficult': return draw() > 0.7;
    case 'mature': return day < 20 ? draw() > 0.25 : draw() > 0.1;
    default: throw new Error('scenario_invalid');
  }
}

/** D-162: virtual-time simulator using the production logical engine. */
export function runScenario({ name, days = 180, seed = 1, start = '2026-01-01T12:00:00Z', failureMode = 'default' }) {
  if (!REQUIRED_SCENARIOS.includes(name)) throw new Error('scenario_invalid');
  if (!Number.isInteger(days) || days < 1 || days > 3650) throw new Error('days_invalid');
  const draw = random(seed);
  const timeline = [];
  const decisions = [];
  const tasks = [{ id: 'habit-1', description: name === 'changing' ? 'Current practice' : 'Daily practice', active: true }];
  const profile = { setupComplete: true, categories: [{ position: 1, cat: 'Growth', description: 'Keep learning' }] };
  for (let day = 0; day < days; day++) {
    const now = new Date(new Date(start).valueOf() + day * 86400000);
    const checked = checkedForScenario(name, day, draw);
    const activity = { taskdate: now.toISOString(), taskdescription: tasks[0].description, checked };
    const recentActivity = [...timeline.map((entry) => entry.activity), activity];
    const decision = evaluateIntervention({
      accountUid: `sim-${name}`,
      profile,
      tasks,
      recentActivity,
      priorInterventions: decisions,
      now,
    });
    const deliveryState = decision.type === 'NONE'
      ? 'not_sent'
      : failureMode === 'none' ? 'sent' : day % 17 === 0 ? 'failed' : 'sent';
    const record = { day, at: now.toISOString(), activity, decision, deliveryState };
    timeline.push(record);
    decisions.push(decision);
  }
  return {
    name,
    virtualDays: days,
    timeline,
    metrics: {
      evaluations: timeline.length,
      none: timeline.filter((entry) => entry.decision.type === 'NONE').length,
      delivered: timeline.filter((entry) => entry.deliveryState === 'sent').length,
      failedDelivery: timeline.filter((entry) => entry.deliveryState === 'failed').length,
    },
  };
}

export function runSimulation({ projectId = 'greenpyramid-sandbox', months = 6, seed = 1, scenarios = REQUIRED_SCENARIOS, failureMode = 'default' } = {}) {
  assertSandboxTarget({ projectId });
  if (!Number.isInteger(months) || months < 1 || months > 24) throw new Error('months_invalid');
  if (!Number.isInteger(seed)) throw new Error('seed_invalid');
  if (!Array.isArray(scenarios) || scenarios.length < 1 || scenarios.length > REQUIRED_SCENARIOS.length || new Set(scenarios).size !== scenarios.length || scenarios.some((name) => !REQUIRED_SCENARIOS.includes(name))) throw new Error('scenarios_invalid');
  if (!['default', 'none'].includes(failureMode)) throw new Error('failure_mode_invalid');
  const days = months * 30;
  const results = scenarios.map((name, index) => runScenario({ name, days, seed: seed + index, failureMode }));
  return {
    projectId,
    virtualMonths: months,
    virtualDays: days,
    seed,
    failureMode,
    scenarios: results,
    timeline: results.flatMap((scenario) => scenario.timeline),
  };
}
