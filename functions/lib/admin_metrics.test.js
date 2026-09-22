import test from 'node:test';
import assert from 'node:assert/strict';
import { buildAdminMetrics } from './admin_metrics.js';

test('admin metrics returns bounded funnel, screen usage, and top five users', () => {
  // D-165-AC-04
  const profiles = Array.from({ length: 6 }, (_, i) => ({
    uidHash: `u${i}`, totalSpendUsd: i, aiCalls: i * 2,
    entitlement: i === 5 ? 'subscribed' : 'pre_trial', setupComplete: i > 0,
  }));
  const telemetry = [
    { eventName: 'setup_begin', uidHash: 'u0' },
    { eventName: 'account_link', uidHash: 'u0' },
    { eventName: 'setup_complete', uidHash: 'u0' },
    { eventName: 'trial_started', uidHash: 'u0' },
    { eventName: 'screen_open', screenKey: 'home', uidHash: 'u0' },
    { eventName: 'screen_open', screenKey: 'home', uidHash: 'u1' },
  ];
  const result = buildAdminMetrics({ profiles, telemetry, now: new Date('2026-09-15T00:00:00Z') });
  assert.equal(result.topUsers.length, 5);
  assert.equal(result.topUsers[0].uidHash, 'u5');
  assert.deepEqual(result.screenUsage, [{ screenKey: 'home', opens: 2, uniqueUsers: 2 }]);
  assert.equal(result.funnel.linkRate, 1);
  assert.equal(result.funnel.completionRate, 1);
  assert.equal(result.funnel.subscriptionRate, 1);
  assert.equal(result.cost.month, '2026-09');
  assert.equal(result.usersCreatedByDay.length, 30);
  assert.deepEqual(
    result.usersCreatedByDay.find((day) => day.date === '2026-09-15'),
    { date: '2026-09-15', count: 0 },
  );
});

test('admin aggregate contains no raw profile or message content', () => {
  const result = buildAdminMetrics({
    profiles: [{ uid: 'raw-user', email: 'person@example.com', totalSpendUsd: 1 }],
    telemetry: [{ eventName: 'screen_open', screenKey: 'home', uidHash: 'hash' }],
  });
  const serialized = JSON.stringify(result);
  assert.equal(serialized.includes('person@example.com'), false);
  assert.equal(serialized.includes('raw-user'), false);
  assert.equal(serialized.includes('message'), false);
});

// D-165-AC-08 / D-165-AC-09 / D-165-AC-10: lifecycle cohorts, conversion
// timing, and the explicit ledger-versus-invoice billing boundary.
test('admin metrics deduplicates lifecycle events and computes conversion timing', () => {
  const result = buildAdminMetrics({
    authUsers: [
      { uidHash: 'u1', createdAt: '2026-09-01T00:00:00.000Z' },
      { uidHash: 'u2', createdAt: '2026-09-01T00:00:00.000Z' },
      { uidHash: 'u3', createdAt: '2026-09-01T00:00:00.000Z' },
    ],
    profiles: [
      {
        uidHash: 'u1',
        entitlement: 'subscribed',
        subscriptionEventTimestampMs: Date.parse('2026-09-03T00:00:00.000Z'),
        spendByMonth: { '2026-09': 1.25 },
      },
      { uidHash: 'u2', entitlement: 'lapsed' },
      { uidHash: 'u3', entitlement: 'pre_trial' },
    ],
    telemetry: [
      { uidHash: 'u1', eventName: 'setup_begin', occurredAt: '2026-09-01T00:01:00.000Z' },
      { uidHash: 'u1', eventName: 'setup_begin', occurredAt: '2026-09-01T00:02:00.000Z' },
      { uidHash: 'u1', eventName: 'setup_complete', occurredAt: '2026-09-01T00:03:00.000Z' },
      { uidHash: 'u1', eventName: 'trial_started', occurredAt: '2026-09-01T00:04:00.000Z' },
      { uidHash: 'u1', eventName: 'subscription_started', occurredAt: '2026-09-03T00:00:00.000Z' },
      { uidHash: 'u2', eventName: 'setup_begin', occurredAt: '2026-09-01T00:01:00.000Z' },
      { uidHash: 'u2', eventName: 'trial_started', occurredAt: '2026-09-01T00:04:00.000Z' },
    ],
  });

  assert.deepEqual(result.cohorts, {
    downloadedUsers: 3,
    setupStartedUsers: 2,
    setupAbandonedUsers: 1,
    setupCompleteUsers: 1,
    preTrialUsers: 1,
    trialingUsers: 0,
    lapsedUsers: 1,
    subscribedUsers: 1,
  });
  assert.equal(result.conversion.trialToSubscriptionRate, 0.5);
  assert.equal(result.conversion.downloadToSubscriptionRate, 1 / 3);
  assert.equal(result.conversion.meanDownloadToSubscriptionDays, 2);
  assert.equal(result.cost.claude.allTimeUsd, 1.25);
  assert.equal(result.cost.allServices.state, 'incomplete');
  assert.deepEqual(
    result.usersCreatedByDay.find((day) => day.date === '2026-09-01'),
    { date: '2026-09-01', count: 3 },
  );
});
