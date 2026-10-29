import test from 'node:test';
import assert from 'node:assert/strict';
import { claimSetupRequest, setupIdempotency } from './setup_idempotency.js';

class Ref {
  constructor(store, path) { this.store = store; this.path = path; }
  collection(n) { return new Ref(this.store, `${this.path}/${n}`); }
  doc(n) { return new Ref(this.store, `${this.path}/${n}`); }
  async get() { return { exists: this.path in this.store.data, data: () => this.store.data[this.path] }; }
  async set(d) { this.store.data[this.path] = d; }
  async delete() { delete this.store.data[this.path]; }
}
class Store {
  constructor() { this.data = {}; }
  collection(n) { return new Ref(this, n); }
  async runTransaction(fn) {
    const writes = [];
    const value = await fn({ get: (r) => r.get(), set: (r, d) => writes.push([r, d]) });
    for (const [r, d] of writes) await r.set(d);
    return value;
  }
}

const requestId = '00000000-0000-4000-8000-0000000000aa';
const body = { sessionId: 's1', requestId, categoryName: 'Alignment' };

// Runs one request through the middleware with [handler] standing in for
// the route; resolves with the status and body the client received.
function run(store, handler) {
  return new Promise((resolve) => {
    const req = { uid: 'u', path: '/deriveHabits', body };
    const res = {
      statusCode: 200,
      status(code) { this.statusCode = code; return this; },
      json(value) { resolve({ status: this.statusCode, body: value }); return this; },
    };
    setupIdempotency(() => store)(req, res, () => handler(res));
  });
}

test('D-148: a rate-limited setup request is not cached, so the identical retry runs again', async () => {
  const store = new Store();
  let calls = 0;
  const first = await run(store, async (res) => {
    calls++;
    await res.status(429).json({ error: 'rate_limited', scope: 'minute', limit: 5 });
  });
  assert.equal(first.status, 429);
  assert.equal(Object.keys(store.data).length, 0, 'the failed claim must be released');

  const retry = await run(store, async (res) => {
    calls++;
    await res.status(200).json({ habits: ['Breathe before deciding'] });
  });
  assert.equal(retry.status, 200);
  assert.deepEqual(retry.body, { habits: ['Breathe before deciding'] });
  assert.equal(calls, 2);
});

test('D-148: a successful setup result is still replayed without a second dispatch', async () => {
  const store = new Store();
  let calls = 0;
  await run(store, async (res) => { calls++; await res.status(200).json({ habits: ['A'] }); });
  const replay = await run(store, async (res) => { calls++; await res.status(200).json({ habits: ['B'] }); });
  assert.deepEqual(replay.body, { habits: ['A'] });
  assert.equal(calls, 1);
});

test('D-148: a failure record cached before this fix is reclaimed rather than replayed', async () => {
  const store = new Store();
  const stuck = await claimSetupRequest(store, 'u', requestId, '/deriveHabits', body);
  await stuck.ref.set({
    fingerprint: stuck.fingerprint, state: 'completed', status: 429,
    response: { error: 'rate_limited', scope: 'minute', limit: 5 },
  });
  const reclaimed = await claimSetupRequest(store, 'u', requestId, '/deriveHabits', body);
  assert.equal(reclaimed.state, 'claimed');
});

test('D-148: an in-flight setup request still reports pending to a concurrent duplicate', async () => {
  const store = new Store();
  await claimSetupRequest(store, 'u', requestId, '/deriveHabits', body);
  const duplicate = await claimSetupRequest(store, 'u', requestId, '/deriveHabits', body);
  assert.equal(duplicate.state, 'pending');
});
