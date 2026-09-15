import assert from 'node:assert/strict';
import test from 'node:test';
import { applySyncRequest, restoreAccount, validateSyncRequest } from './sync_operations.js';

const uid = 'u1';
const id = (n) => `00000000-0000-4000-8000-${String(n).padStart(12, '0')}`;

class Ref {
  constructor(store, path) { this.store = store; this.path = path; }
  collection(name) { return new Collection(this.store, `${this.path}/${name}`); }
  async get() { const value = this.store.data.get(this.path); return { exists: value !== undefined, data: () => value }; }
}
class Store {
  constructor() { this.data = new Map(); }
  collection(name) { return new Collection(this, name); }
  async runTransaction(fn) {
    const tx = { get: ref => ref.get(), set: (ref, value, options) => {
      const old = this.data.get(ref.path) ?? {};
      this.data.set(ref.path, options?.merge ? { ...old, ...value } : value);
    }, create: (ref, value) => {
      if (this.data.has(ref.path)) throw new Error('already_exists');
      this.data.set(ref.path, value);
    } };
    return fn(tx);
  }
}
class Collection {
  constructor(store, path) { this.store = store; this.path = path; }
  doc(id) { return new Ref(this.store, `${this.path}/${id}`); }
  collection(name) { return new Collection(this.store, `${this.path}/${name}`); }
  async get() {
    const prefix = `${this.path}/`;
    const docs = [...this.store.data.entries()]
      .filter(([path]) => path.startsWith(prefix) && !path.slice(prefix.length).includes('/'))
      .map(([path, data]) => ({ ref: new Ref(this.store, path), data: () => data }));
    return { docs };
  }
}

const operation = (revision, value = { id: id(2), name: 'Health' }) => ({
  operationId: id(1), entity: 'category', entityId: id(2), kind: 'upsert', expectedRevision: revision, value,
});

test('D-147-AC-04: retries are idempotent and do not create a second revision', async () => {
  const store = new Store();
  const request = { requestId: id(3), operations: [operation(0)] };
  const first = await applySyncRequest(store, uid, request);
  const second = await applySyncRequest(store, uid, request);
  assert.deepEqual(second.results, first.results);
  assert.equal(second.checkpoint, '1');
});

test('D-147-AC-03: stale revisions return a conflict without overwriting cloud state', async () => {
  const store = new Store();
  await applySyncRequest(store, uid, { requestId: id(4), operations: [operation(0)] });
  const stale = { ...operation(0, { id: id(2), name: 'Changed' }), operationId: id(5) };
  const response = await applySyncRequest(store, uid, { requestId: id(6), operations: [stale] });
  assert.equal(response.results[0].outcome, 'conflict');
  assert.equal(response.results[0].serverRevision, 1);
});

test('D-147-AC-02: restore returns typed durable entities after a checkpoint', async () => {
  const store = new Store();
  await applySyncRequest(store, uid, { requestId: id(7), operations: [operation(0)] });
  const response = await restoreAccount(store, uid, { requestId: id(8), checkpoint: null });
  assert.equal(response.complete, true);
  assert.equal(response.categories[0].name, 'Health');
  assert.deepEqual(response.habits, []);
});

test('D-147: malformed requests are rejected before any write', () => {
  assert.throws(() => validateSyncRequest({ requestId: id(9), operations: [] }), /operations_invalid/);
});
