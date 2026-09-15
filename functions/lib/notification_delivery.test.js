import test from 'node:test';
import assert from 'node:assert/strict';
import { markInboxRead, notificationMessageKey, registerInstallation, upsertInboxItem } from './notification_delivery.js';

class Ref {
  constructor(store, path) { this.store = store; this.path = path; }
  collection(name) { return new Ref(this.store, `${this.path}/${name}`); }
  doc(name) { return new Ref(this.store, `${this.path}/${name}`); }
  async get() { return { exists: this.path in this.store.data, data: () => this.store.data[this.path], ref: this }; }
  async set(data, options) { this.store.data[this.path] = options?.merge ? { ...this.store.data[this.path], ...data } : data; }
}
class Store {
  constructor() { this.data = {}; this.queue = Promise.resolve(); }
  collection(name) { return new Ref(this, name); }
  collectionGroup(name) {
    const store = this;
    return {
      name,
      async get() {
        return {
          docs: Object.entries(store.data)
              .filter(([path]) => path.includes(`/${name}/`))
              .map(([path, data]) => ({ ref: new Ref(store, path), data: () => data })),
        };
      },
    };
  }
  runTransaction(fn) { const result = this.queue.then(async () => { const writes = []; const tx = { get: r => r.get(), set: (r, d, o) => writes.push([r, d, o]) }; const value = await fn(tx); for (const [r, d, o] of writes) await r.set(d, o); return value; }); this.queue = result.catch(() => {}); return result; }
}

const requestId = '00000000-0000-4000-8000-000000000001';
const installationId = '00000000-0000-4000-8000-000000000002';

test('D-149-AC-01: installation registration increments revision and acknowledges', async () => {
  const store = new Store();
  const result = await registerInstallation(store, 'new-user', {
    requestId, installationId, token: 'token-a', enabled: true, timezone: 'America/Los_Angeles', expectedRevision: 0,
  });
  assert.deepEqual(result, { requestId, acknowledged: true });
  assert.equal(store.data['users/new-user/installations/' + installationId].revision, 1);
});

test('D-149-AC-01: stale installation revision is rejected', async () => {
  const store = new Store();
  await registerInstallation(store, 'u', { requestId, installationId, token: 'a', enabled: true, timezone: 'UTC', expectedRevision: 0 });
  await assert.rejects(() => registerInstallation(store, 'u', { requestId, installationId, token: 'b', enabled: true, timezone: 'UTC', expectedRevision: 0 }), /revision_conflict/);
});

test('D-149-AC-03: inbox upsert is idempotent by stable message key', async () => {
  const store = new Store();
  const item = { messageKey: notificationMessageKey({ type: 'tailored', occurrenceDate: '2026-09-15', slot: 'morning' }), type: 'tailored', occurrenceDate: '2026-09-15', habitIds: [], title: 'A', body: 'B' };
  assert.equal((await upsertInboxItem(store, 'u', item)).created, true);
  assert.equal((await upsertInboxItem(store, 'u', item)).created, false);
  assert.equal(Object.keys(store.data).length, 1);
});

test('D-149-AC-01: marking an unknown inbox key still acknowledges safely', async () => {
  const store = new Store();
  assert.deepEqual(await markInboxRead(store, 'u', { requestId, messageKey: 'missing' }), { requestId, acknowledged: true });
});
