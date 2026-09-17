import test from 'node:test';
import assert from 'node:assert/strict';
import { buildInterventionContext } from './intervention_context.js';

test('D-154-AC-01: context connects user values, goals, categories, tasks and checkbox history', () => {
  const context = buildInterventionContext({
    profile: {
      visionStatement: 'Live deliberately',
      categories: [{ position: 1, cat: 'Health', description: 'Care for my body', activeEssence: 'Energy' }],
    },
    tasks: [{ id: 'habit-1', category: 'Health', description: 'Walk ten minutes', scheduledtime: '08:00', cue: 'After coffee' }],
    recentActivity: [{ taskdate: '2026-09-14', category: 'Health', taskdescription: 'Walk ten minutes', checked: 'false', missreason: 'A meeting interrupted me' }],
  });

  assert.equal(context.values[0].name, 'Health');
  assert.equal(context.values[0].description, 'Care for my body');
  assert.deepEqual(context.goals, [{ text: 'Live deliberately', source: 'user' }]);
  assert.equal(context.categories[0].position, 1);
  assert.equal(context.tasks[0].category, 'Health');
  assert.equal(context.tasks[0].scheduledTime, '08:00');
  assert.equal(context.tasks[0].cue, 'After coffee');
  assert.equal(context.checkboxHistory[0].checked, false);
  assert.equal(context.checkboxHistory[0].missReason, 'A meeting interrupted me');
});

test('D-154-AC-02: context preserves user language without a subject classification', () => {
  const context = buildInterventionContext({
    profile: { categories: [{ name: 'Craft', description: 'Make useful things' }] },
  });

  assert.equal(Object.hasOwn(context, 'subject'), false);
  assert.equal(Object.hasOwn(context.categories[0], 'subject'), false);
  assert.equal(context.categories[0].name, 'Craft');
});

test('D-154-AC-03: missing context stays empty and engine can safely return NONE', () => {
  const context = buildInterventionContext({});

  assert.deepEqual(context.values, []);
  assert.deepEqual(context.goals, []);
  assert.deepEqual(context.categories, []);
  assert.deepEqual(context.tasks, []);
  assert.deepEqual(context.checkboxHistory, []);
});
