import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { claimNotificationDispatch, completeNotificationDispatch, deliverNotification, failNotificationDispatch, markInboxRead, notificationMessageKey, registerInstallation, upsertInboxItem } from './notification_delivery.js';

class Ref {
  constructor(store, path) { this.store = store; this.path = path; }
  collection(name) { return new Ref(this.store, `${this.path}/${name}`); }
  doc(name) { return new Ref(this.store, `${this.path}/${name}`); }
  where(field, operator, value) {
    if (operator !== '==') throw new Error('test_only_supports_equality');
    const store = this.store;
    const prefix = `${this.path}/`;
    return {
      async get() {
        return {
          docs: Object.entries(store.data)
              .filter(([path, data]) => path.startsWith(prefix) && !path.slice(prefix.length).includes('/') && data?.[field] === value)
              .map(([path, data]) => ({ ref: new Ref(store, path), data: () => data })),
        };
      },
    };
  }
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

test('D-149-AC-01: installation registration rejects a non-IANA timezone', async () => {
  const store = new Store();
  await assert.rejects(() => registerInstallation(store, 'u', {
    requestId, installationId, token: 'a', enabled: true,
    timezone: 'not-a-timezone', expectedRevision: 0,
  }), /timezone_invalid/);
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

test('D-149-AC-03: concurrent retries claim one logical dispatch', async () => {
  const store = new Store();
  const key = notificationMessageKey({ type: 'batch_checkin', occurrenceDate: '2026-09-15', habitIds: ['h1'] });
  const claims = await Promise.all([
    claimNotificationDispatch(store, 'u', key),
    claimNotificationDispatch(store, 'u', key),
  ]);
  assert.deepEqual(claims.sort(), [false, true]);
});

test('D-149: shared delivery writes the inbox before provider delivery', async () => {
  const store = new Store();
  store.data['users/u/installations/i'] = { enabled: true, token: 'token-1' };
  const key = notificationMessageKey({ type: 'intervention', occurrenceDate: '2026-09-15', slot: '09:00' });
  const result = await deliverNotification({
    store,
    messaging: { sendEachForMulticast: async () => ({ successCount: 1 }) },
    uid: 'u',
    item: { messageKey: key, type: 'intervention', occurrenceDate: '2026-09-15', title: 'Keep going', body: 'A bounded message.' },
    payload: { type: 'intervention', messageKey: key, accountUid: 'u' },
  });
  assert.deepEqual(result, { state: 'sent', inbox: true, delivered: true });
  const inboxDocs = Object.entries(store.data).filter(([path]) => path.includes('/inbox/'));
  assert.equal(inboxDocs.length, 1);
  assert.equal(inboxDocs[0][1].type, 'intervention');
  assert.equal(store.data[Object.keys(store.data).find((path) => path.includes('/notificationClaims/'))].state, 'sent');
});

test('D-149-AC-03: failed transport releases the stable claim for retry, '
  + 'and accepted transport closes it', async () => {
  const store = new Store();
  const key = notificationMessageKey({ type: 'tailored', occurrenceDate: '2026-09-15', slot: 'morning' });
  assert.equal(await claimNotificationDispatch(store, 'u', key), true);
  await failNotificationDispatch(store, 'u', key);
  assert.equal(await claimNotificationDispatch(store, 'u', key), true);
  await completeNotificationDispatch(store, 'u', key);
  assert.equal(await claimNotificationDispatch(store, 'u', key), false);
  assert.equal(store.data['users/u/notificationClaims/' + createHash('sha256').update(key).digest('hex')].state, 'sent');
});
