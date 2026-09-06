import { test } from 'node:test';
import assert from 'node:assert/strict';
import { resolveEntitlement, requireEntitlement, EntitlementRequiredError } from './entitlement.js';

class FakeDoc {
  constructor(store, path) { this.store = store; this.path = path; }
  async get() { return { data: () => this.store.data[this.path] }; }
  async set(data, opts) {
    const existing = this.store.data[this.path];
    this.store.data[this.path] = opts?.merge ? { ...(existing ?? {}), ...data } : data;
  }
  collection(name) { return new FakeCollection(this.store, `${this.path}/${name}`); }
}
class FakeCollection {
  constructor(store, path) { this.store = store; this.path = path; }
  doc(id) { return new FakeDoc(this.store, `${this.path}/${id}`); }
}
class FakeFirestore {
  constructor(seed = {}) { this.data = seed; }
  collection(name) { return new FakeCollection(this, name); }
}

const fakeTimestamp = (date) => ({ toDate: () => date });
const path = (uid) => `users/${uid}/profile/main`;

test('D-057: no uid or store resolves to pre_trial rather than throwing', async () => {
  assert.equal(await resolveEntitlement(null, new FakeFirestore()), 'pre_trial');
  assert.equal(await resolveEntitlement('u1', null), 'pre_trial');
});

test('D-057: a missing profile doc resolves to pre_trial', async () => {
  const store = new FakeFirestore();
  assert.equal(await resolveEntitlement('u1', store), 'pre_trial');
});

test('D-057: an unexpired trial resolves as trialing, untouched', async () => {
  const now = new Date('2026-06-01T00:00:00Z');
  const store = new FakeFirestore({
    [path('u1')]: { entitlement: 'trialing', trialExpiresAt: fakeTimestamp(new Date('2026-06-04T00:00:00Z')) },
  });
  assert.equal(await resolveEntitlement('u1', store, now), 'trialing');
});

test('D-057: an expired trial transitions to lapsed in place, server-side, '
    + 'regardless of what the client clock claims', async () => {
  const now = new Date('2026-06-05T00:00:00Z');
  const store = new FakeFirestore({
    [path('u1')]: { entitlement: 'trialing', trialExpiresAt: fakeTimestamp(new Date('2026-06-04T00:00:00Z')) },
  });
  assert.equal(await resolveEntitlement('u1', store, now), 'lapsed');
  assert.equal(store.data[path('u1')].entitlement, 'lapsed');
});

test('D-057: subscribed and lapsed pass through unchanged', async () => {
  const store = new FakeFirestore({
    [path('u1')]: { entitlement: 'subscribed' },
    [path('u2')]: { entitlement: 'lapsed' },
  });
  assert.equal(await resolveEntitlement('u1', store), 'subscribed');
  assert.equal(await resolveEntitlement('u2', store), 'lapsed');
});

test('D-016: requireEntitlement passes for trialing and subscribed', async () => {
  const store = new FakeFirestore({
    [path('u1')]: { entitlement: 'trialing', trialExpiresAt: fakeTimestamp(new Date('2099-01-01')) },
    [path('u2')]: { entitlement: 'subscribed' },
  });
  await requireEntitlement('u1', store);
  await requireEntitlement('u2', store);
});

test('D-016: requireEntitlement throws EntitlementRequiredError for '
    + 'pre_trial and lapsed', async () => {
  const store = new FakeFirestore({ [path('u1')]: { entitlement: 'lapsed' } });
  await assert.rejects(() => requireEntitlement('u1', store), EntitlementRequiredError);
  await assert.rejects(() => requireEntitlement('u2', store), EntitlementRequiredError);
});
