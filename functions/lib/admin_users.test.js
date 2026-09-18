import test from 'node:test';
import assert from 'node:assert/strict';
import { buildAdminUserDetail, buildAdminUserSummary } from './admin_users.js';

const categories = Array.from({ length: 6 }, (_, index) => ({
  cat: `Category ${index + 1}`,
  position: index + 1,
}));

test('D-168-AC-04: legacy completed profiles derive setup completion from the durable pyramid', () => {
  const detail = buildAdminUserDetail({
    uid: 'legacy-user',
    profile: { firstName: 'Craig', categories },
    usage: { tasks: 12 },
  });
  assert.equal(detail.setupComplete, true);
  assert.equal(detail.setupCompletedAt, null);
});

test('D-168-AC-04: detail honors root setup completion and counts embedded categories', () => {
  const detail = buildAdminUserDetail({
    uid: 'modern-user',
    account: { setupComplete: true, setupCompletedAt: new Date('2026-01-01') },
    profile: { categories },
    usage: { tasks: 0, categories: 0 },
  });
  assert.equal(detail.setupComplete, true);
  assert.equal(detail.setupCompletedAt, '2026-01-01T00:00:00.000Z');
});

test('D-168-AC-04: incomplete profiles remain incomplete', () => {
  const summary = buildAdminUserSummary({
    profiles: [{ ref: { path: 'users/partial/profile/main' }, data: () => ({ categories: categories.slice(0, 5) }) }],
  });
  assert.equal(summary.users[0].setupComplete, false);
});
