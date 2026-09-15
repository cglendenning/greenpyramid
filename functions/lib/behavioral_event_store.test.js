import test from 'node:test';
import assert from 'node:assert/strict';
import { appendBehavioralEvents } from './behavioral_event_store.js';

class Store {
  constructor() { this.rows = new Map(); }
  collection(name) { return new Collection(this.rows, name); }
  async runTransaction(callback) {
    const tx = {
      get: async (ref) => ({ exists: this.rows.has(ref.path), data: () => this.rows.get(ref.path) }),
      create: (ref, value) => {
        if (this.rows.has(ref.path)) throw new Error('already_exists');
        this.rows.set(ref.path, value);
      },
    };
    await callback(tx);
  }
}

class Collection {
  constructor(rows, path = '') { this.rows = rows; this.path = path; }
  doc(id) { return new Document(this.rows, `${this.path}/${id}`, id); }
  collection(name) { return new Collection(this.rows, `${this.path}/${name}`); }
}

class Document {
  constructor(rows, path, id) { this.rows = rows; this.path = path; this.id = id; }
  collection(name) { return new Collection(this.rows, `${this.path}/${name}`); }
}

function event(overrides = {}) {
  return {
    eventId: 'evt-1', type: 'checkbox', source: 'sync', schemaVersion: 1,
    provenance: { operationId: 'op-1' }, data: { taskId: 'habit-1', checked: true },
    ...overrides,
  };
}

test('D-153-AC-01: appended events receive authenticated account and audit metadata', async () => {
  const store = new Store();
  const result = await appendBehavioralEvents(store, 'account-1', [event()], new Date('2026-09-15T12:00:00Z'));
  assert.deepEqual(result.results, [{ eventId: 'evt-1', outcome: 'appended' }]);
  const saved = store.rows.get('users/account-1/behavioralEvents/evt-1');
  assert.equal(saved.accountUid, 'account-1');
  assert.equal(saved.occurredAt, '2026-09-15T12:00:00.000Z');
  assert.equal(saved.schemaVersion, 1);
  assert.deepEqual(saved.provenance, { operationId: 'op-1' });
});

test('D-153-AC-02: repeated event IDs are idempotent and conflicting payloads fail', async () => {
  const store = new Store();
  await appendBehavioralEvents(store, 'account-1', [event()]);
  const replay = await appendBehavioralEvents(store, 'account-1', [event()]);
  assert.deepEqual(replay.results, [{ eventId: 'evt-1', outcome: 'duplicate' }]);
  await assert.rejects(
    appendBehavioralEvents(store, 'account-1', [event({ data: { taskId: 'different', checked: false } })]),
    /event_payload_conflict/,
  );
});

test('D-153-AC-03: append history retains prior facts instead of replacing them', async () => {
  const store = new Store();
  await appendBehavioralEvents(store, 'account-1', [event()]);
  await appendBehavioralEvents(store, 'account-1', [event({ eventId: 'evt-2', data: { taskId: 'habit-1', checked: false } })]);
  assert.equal(store.rows.size, 2);
  assert.equal(store.rows.get('users/account-1/behavioralEvents/evt-1').data.checked, true);
  assert.equal(store.rows.get('users/account-1/behavioralEvents/evt-2').data.checked, false);
});
