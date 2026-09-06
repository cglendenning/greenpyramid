import { test } from 'node:test';
import assert from 'node:assert/strict';
import { applyRevenueCatEvent, verifyWebhookAuth } from './revenuecat_webhook.js';

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

const path = (uid) => `users/${uid}/profile/main`;

test('D-070: INITIAL_PURCHASE grants subscribed', async () => {
  const store = new FakeFirestore();
  const result = await applyRevenueCatEvent({ type: 'INITIAL_PURCHASE', app_user_id: 'u1' }, store);
  assert.equal(result, 'subscribed');
  assert.equal(store.data[path('u1')].entitlement, 'subscribed');
});

for (const type of ['RENEWAL', 'UNCANCELLATION', 'PRODUCT_CHANGE', 'TRANSFER']) {
  test(`D-070: ${type} grants subscribed`, async () => {
    const store = new FakeFirestore();
    const result = await applyRevenueCatEvent({ type, app_user_id: 'u1' }, store);
    assert.equal(result, 'subscribed');
  });
}

test('D-070: EXPIRATION transitions a subscribed account to lapsed', async () => {
  const store = new FakeFirestore({ [path('u1')]: { entitlement: 'subscribed' } });
  const result = await applyRevenueCatEvent({ type: 'EXPIRATION', app_user_id: 'u1' }, store);
  assert.equal(result, 'lapsed');
  assert.equal(store.data[path('u1')].entitlement, 'lapsed');
});

test('D-070: CANCELLATION alone does not end access — no entitlement '
    + 'change until RevenueCat sends the later EXPIRATION', async () => {
  const store = new FakeFirestore({ [path('u1')]: { entitlement: 'subscribed' } });
  const result = await applyRevenueCatEvent({ type: 'CANCELLATION', app_user_id: 'u1' }, store);
  assert.equal(result, null);
  assert.equal(store.data[path('u1')].entitlement, 'subscribed');
});

test('D-070: BILLING_ISSUE and unrecognized event types are no-ops', async () => {
  const store = new FakeFirestore({ [path('u1')]: { entitlement: 'subscribed' } });
  assert.equal(await applyRevenueCatEvent({ type: 'BILLING_ISSUE', app_user_id: 'u1' }, store), null);
  assert.equal(await applyRevenueCatEvent({ type: 'TEST', app_user_id: 'u1' }, store), null);
  assert.equal(store.data[path('u1')].entitlement, 'subscribed');
});

test('D-070: a malformed event (missing type or app_user_id) is a no-op, '
    + 'never a throw', async () => {
  const store = new FakeFirestore();
  assert.equal(await applyRevenueCatEvent({}, store), null);
  assert.equal(await applyRevenueCatEvent({ type: 'INITIAL_PURCHASE' }, store), null);
  assert.equal(await applyRevenueCatEvent(null, store), null);
});

test('verifyWebhookAuth requires an exact match against the configured secret', () => {
  assert.equal(verifyWebhookAuth('Bearer abc123', 'Bearer abc123'), true);
  assert.equal(verifyWebhookAuth('Bearer wrong', 'Bearer abc123'), false);
  assert.equal(verifyWebhookAuth(undefined, 'Bearer abc123'), false);
  assert.equal(verifyWebhookAuth('Bearer abc123', undefined), false);
});
