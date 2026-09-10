import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  latestScheduledMinutes,
  todaysScheduledHabits,
  shouldSendBatchCheckin,
} from './batch_checkin_schedule.js';

// 2026-06-15 is a Monday.
const walk = { id: 't1', category: 'Health', taskdescription: 'Walk',
  monday: 'true', tuesday: 'false', scheduledtime: '07:00' };
const stretch = { id: 't2', category: 'Health', taskdescription: 'Stretch',
  monday: 'true', tuesday: 'false', scheduledtime: '18:30' };
const unscheduled = { id: 't3', category: 'Health', taskdescription: 'Read',
  monday: 'true', tuesday: 'false', scheduledtime: null };
const tuesdayOnly = { id: 't4', category: 'Work', taskdescription: 'Plan',
  monday: 'false', tuesday: 'true', scheduledtime: '09:00' };

test('D-124: latestScheduledMinutes — the latest of today\'s active '
  + 'scheduled habits, ignoring unscheduled and other-day habits', () => {
  const tasks = [walk, stretch, unscheduled, tuesdayOnly];
  assert.equal(latestScheduledMinutes(tasks, 'monday'), 18 * 60 + 30);
});

test('D-124: latestScheduledMinutes is null when nothing is scheduled and '
  + 'active today', () => {
  assert.equal(latestScheduledMinutes([unscheduled, tuesdayOnly], 'monday'), null);
});

test('D-124: todaysScheduledHabits names exactly the scheduled, active '
  + 'habits — the push payload\'s own source of truth', () => {
  const tasks = [walk, stretch, unscheduled, tuesdayOnly];
  const habits = todaysScheduledHabits(tasks, 'monday');
  assert.deepEqual(habits.map((h) => h.id), ['t1', 't2']);
  assert.deepEqual(habits[0], {
    id: 't1', category: 'Health', description: 'Walk', scheduledtime: '07:00',
  });
});

test('D-124: shouldSendBatchCheckin is false before the latest scheduled '
  + 'time has passed', () => {
  const now = new Date('2026-06-15T18:00:00Z'); // 18:00 UTC, before 18:30
  const result = shouldSendBatchCheckin({
    tasks: [walk, stretch], timezone: 'UTC', now, lastSentDate: null,
  });
  assert.ok(!result);
});

test('D-124: shouldSendBatchCheckin is true once the latest scheduled '
  + 'time has passed and today hasn\'t been sent yet', () => {
  const now = new Date('2026-06-15T18:30:00Z');
  const result = shouldSendBatchCheckin({
    tasks: [walk, stretch], timezone: 'UTC', now, lastSentDate: null,
  });
  assert.ok(result);
});

test('D-124: shouldSendBatchCheckin is false once today has already been '
  + 'sent — the once-per-day guard notification_schedule.js\'s narrow '
  + 'fixed-slot window doesn\'t need', () => {
  const now = new Date('2026-06-15T19:00:00Z');
  const result = shouldSendBatchCheckin({
    tasks: [walk, stretch], timezone: 'UTC', now, lastSentDate: '2026-06-15',
  });
  assert.ok(!result);
});

test('D-124: a new day with a new latest time sends again even though a '
  + 'previous day was already sent', () => {
  const now = new Date('2026-06-16T19:00:00Z'); // Tuesday
  const result = shouldSendBatchCheckin({
    tasks: [tuesdayOnly], timezone: 'UTC', now, lastSentDate: '2026-06-15',
  });
  assert.ok(result);
});

test('D-124: a day with no scheduled habits at all never sends', () => {
  const now = new Date('2026-06-15T23:59:00Z');
  const result = shouldSendBatchCheckin({
    tasks: [unscheduled], timezone: 'UTC', now, lastSentDate: null,
  });
  assert.ok(!result);
});

test('D-124: an unset timezone never sends', () => {
  const now = new Date('2026-06-15T23:59:00Z');
  const result = shouldSendBatchCheckin({
    tasks: [walk], timezone: undefined, now, lastSentDate: null,
  });
  assert.ok(!result);
});

test('D-124: an invalid timezone string never sends, rather than guessing '
  + 'a default', () => {
  const now = new Date('2026-06-15T23:59:00Z');
  const result = shouldSendBatchCheckin({
    tasks: [walk], timezone: 'Not/ATimezone', now, lastSentDate: null,
  });
  assert.ok(!result);
});

test('D-124: a half-hour-offset timezone (India, UTC+5:30) computes the '
  + 'correct local day and time', () => {
  // 07:00 IST Monday == 01:30 UTC Monday; the walk habit's 7am slot has
  // just passed at 07:01 IST == 01:31 UTC.
  const now = new Date('2026-06-15T01:31:00Z');
  const result = shouldSendBatchCheckin({
    tasks: [walk], timezone: 'Asia/Kolkata', now, lastSentDate: null,
  });
  assert.ok(result);
});
