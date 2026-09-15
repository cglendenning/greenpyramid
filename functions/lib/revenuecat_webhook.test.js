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
  async runTransaction(fn) {
    const tx = {
      get: (ref) => ref.get(),
      set: (ref, data, opts) => ref.set(data, opts),
    };
    return fn(tx);
  }
}

const path = (uid) => `users/${uid}/profile/main`;

test('D-054: INITIAL_PURCHASE grants subscribed', async () => {
  const store = new FakeFirestore();
  const result = await applyRevenueCatEvent({ id: 'e1', type: 'INITIAL_PURCHASE', app_user_id: 'u1' }, store);
  assert.equal(result, 'subscribed');
  assert.equal(store.data[path('u1')].entitlement, 'subscribed');
});

for (const type of ['RENEWAL', 'UNCANCELLATION', 'PRODUCT_CHANGE', 'TRANSFER']) {
  test(`D-054: ${type} grants subscribed`, async () => {
    const store = new FakeFirestore();
    const result = await applyRevenueCatEvent({ id: `e-${type}`, type, app_user_id: 'u1' }, store);
    assert.equal(result, 'subscribed');
  });
}

test('D-054: EXPIRATION transitions a subscribed account to lapsed', async () => {
  const store = new FakeFirestore({ [path('u1')]: { entitlement: 'subscribed' } });
  const result = await applyRevenueCatEvent({ id: 'e2', type: 'EXPIRATION', app_user_id: 'u1', event_timestamp_ms: 2 }, store);
  assert.equal(result, 'lapsed');
  assert.equal(store.data[path('u1')].entitlement, 'lapsed');
});

test('D-054: CANCELLATION alone does not end access — no entitlement '
    + 'change until RevenueCat sends the later EXPIRATION', async () => {
  const store = new FakeFirestore({ [path('u1')]: { entitlement: 'subscribed' } });
  const result = await applyRevenueCatEvent({ id: 'e3', type: 'CANCELLATION', app_user_id: 'u1', event_timestamp_ms: 1 }, store);
  assert.equal(result, null);
  assert.equal(store.data[path('u1')].entitlement, 'subscribed');
});

test('D-054: BILLING_ISSUE and unrecognized event types are no-ops', async () => {
  const store = new FakeFirestore({ [path('u1')]: { entitlement: 'subscribed' } });
  assert.equal(await applyRevenueCatEvent({ id: 'e4', type: 'BILLING_ISSUE', app_user_id: 'u1' }, store), null);
  assert.equal(await applyRevenueCatEvent({ id: 'e5', type: 'TEST', app_user_id: 'u1' }, store), null);
  assert.equal(store.data[path('u1')].entitlement, 'subscribed');
});

test('D-054: a malformed event (missing type or app_user_id) is a no-op, '
    + 'never a throw', async () => {
  const store = new FakeFirestore();
  assert.equal(await applyRevenueCatEvent({}, store), null);
  assert.equal(await applyRevenueCatEvent({ type: 'INITIAL_PURCHASE', app_user_id: 'u1' }, store), null);
  assert.equal(await applyRevenueCatEvent(null, store), null);
});

// D-146-AC-06
test('D-135: replayed and out-of-order events do not overwrite newer state', async () => {
  const store = new FakeFirestore();
  assert.equal(await applyRevenueCatEvent({ id: 'new', type: 'INITIAL_PURCHASE', app_user_id: 'u1', event_timestamp_ms: 20 }, store), 'subscribed');
  assert.equal(await applyRevenueCatEvent({ id: 'old', type: 'EXPIRATION', app_user_id: 'u1', event_timestamp_ms: 10 }, store), null);
  assert.equal(await applyRevenueCatEvent({ id: 'new', type: 'EXPIRATION', app_user_id: 'u1', event_timestamp_ms: 30 }, store), null);
  assert.equal(store.data[path('u1')].entitlement, 'subscribed');
});

test('D-135: storage failures propagate for webhook retry', async () => {
  const store = new FakeFirestore();
  store.runTransaction = async () => { throw new Error('storage unavailable'); };
  await assert.rejects(() => applyRevenueCatEvent({ id: 'e1', type: 'INITIAL_PURCHASE', app_user_id: 'u1' }, store), /storage unavailable/);
});

test('verifyWebhookAuth requires an exact match against the configured secret', () => {
  assert.equal(verifyWebhookAuth('Bearer abc123', 'Bearer abc123'), true);
  assert.equal(verifyWebhookAuth('Bearer wrong', 'Bearer abc123'), false);
  assert.equal(verifyWebhookAuth(undefined, 'Bearer abc123'), false);
  assert.equal(verifyWebhookAuth('Bearer abc123', undefined), false);
});
