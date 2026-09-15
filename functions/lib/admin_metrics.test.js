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
