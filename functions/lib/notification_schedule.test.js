import { test } from 'node:test';
import assert from 'node:assert/strict';
import { isNotificationWindow, isEligibleForTailoredNotification, DAILY_SLOTS } from './notification_schedule.js';

test('D-023: exactly three daily slots, matching the existing 9am/12pm/8pm '
  + 'cadence', () => {
  assert.deepEqual(DAILY_SLOTS, [
    { hour: 9, minute: 0 },
    { hour: 12, minute: 0 },
    { hour: 20, minute: 0 },
  ]);
});

test('D-039: a UTC user at exactly 09:00 is in the morning window', () => {
  const now = new Date('2026-06-15T09:00:00Z');
  assert.ok(isNotificationWindow('UTC', now));
});

test('D-039: a UTC user at 09:10 is still in the window (within the job '
  + 'interval)', () => {
  const now = new Date('2026-06-15T09:10:00Z');
  assert.ok(isNotificationWindow('UTC', now));
});

test('D-039: a UTC user at 09:20 has missed the window', () => {
  const now = new Date('2026-06-15T09:20:00Z');
  assert.ok(!isNotificationWindow('UTC', now));
});

test('D-039: a half-hour-offset timezone (India, UTC+5:30) still matches '
  + 'its local 9am', () => {
  // 09:00 IST == 03:30 UTC.
  const now = new Date('2026-06-15T03:30:00Z');
  assert.ok(isNotificationWindow('Asia/Kolkata', now));
});

test('D-039: an unset timezone never matches', () => {
  assert.ok(!isNotificationWindow(undefined, new Date()));
});

test('D-039: an invalid timezone string never matches, rather than '
  + 'guessing a default', () => {
  assert.ok(!isNotificationWindow('Not/ATimezone', new Date()));
});

test('D-036: a lapsed account is never eligible, even inside its notification '
  + 'window', () => {
  const now = new Date('2026-06-15T09:00:00Z');
  const eligible = isEligibleForTailoredNotification(
    { entitlement: 'lapsed', timezone: 'UTC' }, now);
  assert.ok(!eligible);
});

test('D-016/R7: a pre_trial account is eligible — everyone is treated as '
  + 'entitled until R8', () => {
  const now = new Date('2026-06-15T09:00:00Z');
  const eligible = isEligibleForTailoredNotification(
    { entitlement: 'pre_trial', timezone: 'UTC' }, now);
  assert.ok(eligible);
});

test('a missing profile document is never eligible', () => {
  assert.ok(!isEligibleForTailoredNotification(null, new Date()));
});
