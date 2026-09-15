import { test } from 'node:test';
import assert from 'node:assert/strict';
import { guardCallFrequency, RateLimitError } from './rate_limit.js';

class Doc {
  constructor(store, path) { this.store = store; this.path = path; }
  async get() { return { data: () => this.store[this.path] }; }
  async set(data, options) {
    this.store[this.path] = options?.merge ? { ...(this.store[this.path] ?? {}), ...data } : data;
  }
  collection(name) { return new Collection(this.store, `${this.path}/${name}`); }
}
class Collection {
  constructor(store, path) { this.store = store; this.path = path; }
  doc(id) { return new Doc(this.store, `${this.path}/${id}`); }
}
class Store {
  constructor() { this.data = {}; }
  collection(name) { return new Collection(this.data, name); }
  runTransaction(fn) { return fn({ get: ref => ref.get(), set: (ref, data, options) => ref.set(data, options) }); }
}

const now = new Date('2026-09-15T12:34:00Z');

test('D-146-AC-02: server frequency limits reject the sixth minute call', async () => {
  const store = new Store();
  for (let i = 0; i < 5; i++) await guardCallFrequency('u1', store, now);
  await assert.rejects(() => guardCallFrequency('u1', store, now), RateLimitError);
});

test('D-146-AC-02: minute buckets reset without resetting the daily count', async () => {
  const store = new Store();
  for (let i = 0; i < 5; i++) await guardCallFrequency('u1', store, now);
  await guardCallFrequency('u1', store, new Date('2026-09-15T12:35:00Z'));
  const data = store.data['users/u1/profile/main'].aiRateLimit;
  assert.equal(data.minuteCount, 1);
  assert.equal(data.dayCount, 6);
});
