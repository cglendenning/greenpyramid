import { test } from 'node:test';
import assert from 'node:assert/strict';
import { guardAndCountSetupCall, SetupCallLimitError, SETUP_CALL_LIMIT } from './setup_guard.js';

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
    return fn({ get: (ref) => ref.get(), set: (ref, data, opts) => ref.set(data, opts) });
  }
}

const path = (uid, sid) => `users/${uid}/councilSessions/${sid}`;

test('D-072: no-ops without a uid, sessionId, or store', async () => {
  assert.equal(await guardAndCountSetupCall(null, 's1', new FakeFirestore()), 0);
  assert.equal(await guardAndCountSetupCall('u1', null, new FakeFirestore()), 0);
  assert.equal(await guardAndCountSetupCall('u1', 's1', null), 0);
});

test('D-072: the first call counts to 1', async () => {
  const store = new FakeFirestore();
  const count = await guardAndCountSetupCall('u1', 's1', store);
  assert.equal(count, 1);
  assert.equal(store.data[path('u1', 's1')].modelCallCount, 1);
});

test('D-072: calls accumulate across invocations for the same session', async () => {
  const store = new FakeFirestore();
  for (let i = 0; i < 5; i++) await guardAndCountSetupCall('u1', 's1', store);
  assert.equal(store.data[path('u1', 's1')].modelCallCount, 5);
});

test('D-072: the 40th call is allowed through — it is the one that must '
  + 'close the session gracefully', async () => {
  const store = new FakeFirestore({ [path('u1', 's1')]: { modelCallCount: SETUP_CALL_LIMIT - 1 } });
  const count = await guardAndCountSetupCall('u1', 's1', store);
  assert.equal(count, SETUP_CALL_LIMIT);
});

test('D-072: the 41st call is refused', async () => {
  const store = new FakeFirestore({ [path('u1', 's1')]: { modelCallCount: SETUP_CALL_LIMIT } });
  await assert.rejects(() => guardAndCountSetupCall('u1', 's1', store), SetupCallLimitError);
});

test('D-072: two different sessions for the same account count '
  + 'independently', async () => {
  const store = new FakeFirestore({ [path('u1', 's1')]: { modelCallCount: SETUP_CALL_LIMIT } });
  const count = await guardAndCountSetupCall('u1', 's2', store);
  assert.equal(count, 1);
});
