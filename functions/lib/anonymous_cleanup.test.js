import assert from 'node:assert/strict';
import test from 'node:test';
import { cleanupAnonymousAccounts } from './anonymous_cleanup.js';

class Ref {
  constructor(store, path, id) { this.store = store; this.path = path; this.id = id; }
  collection(name) { return new Collection(this.store, `${this.path}/${name}`); }
  async get() { const d = this.store.data.get(this.path); return { exists: d !== undefined, data: () => d }; }
  async delete() { this.store.data.delete(this.path); }
  async listCollections() { return []; }
  async set(value) { this.store.data.set(this.path, value); }
}
class Collection {
  constructor(store, path) { this.store = store; this.path = path; }
  doc(id) { return new Ref(this.store, `${this.path}/${id}`, id); }
  where() { return this; }
  limit() { return this; }
  async get() {
    const prefix = `${this.path}/`;
    const docs = [...this.store.data.entries()].filter(([p]) => p.startsWith(prefix) && !p.slice(prefix.length).includes('/')).map(([p, d]) => new Ref(this.store, p, p.split('/').pop()));
    return { docs };
  }
}
class Store {
  constructor(data) { this.data = new Map(Object.entries(data)); }
  collection(name) { return new Collection(this, name); }
}

const expired = new Date('2026-01-01T00:00:00Z');
const timestamp = { toDate: () => expired };

test('D-147-AC-06: expired anonymous accounts delete the full tree, Auth user, and audit success', async () => {
  const store = new Store({
    'users/u1': { ttlAt: timestamp },
    'users/u1/profile/main': { entitlement: 'pre_trial', setupComplete: false, ttlAt: timestamp },
    'users/u1/tasks/t1': { description: 'private' },
  });
  const auth = { getUser: async () => ({ providerData: [] }), deleteUser: async uid => { auth.deleted = uid; } };
  const result = await cleanupAnonymousAccounts(store, auth, new Date('2026-02-01T00:00:00Z'));
  assert.deepEqual(result, [{ uid: 'u1', outcome: 'deleted' }]);
  assert.equal(auth.deleted, 'u1');
  assert.equal(store.data.has('users/u1'), false);
  assert.equal(store.data.get('cleanupAudit/u1').outcome, 'deleted');
});

test('D-147-AC-06: linked or completed accounts are never cleanup candidates', async () => {
  const store = new Store({
    'users/u1': { ttlAt: timestamp },
    'users/u1/profile/main': { entitlement: 'subscribed', setupComplete: true, ttlAt: timestamp },
  });
  const auth = { getUser: async () => ({ providerData: [{ providerId: 'apple.com' }] }), deleteUser: async () => { throw new Error('must not delete'); } };
  assert.deepEqual(await cleanupAnonymousAccounts(store, auth, new Date('2026-02-01T00:00:00Z')), []);
  assert.equal(store.data.has('users/u1'), true);
});
