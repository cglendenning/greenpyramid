import test from 'node:test';
import assert from 'node:assert/strict';
import { articleMessageKey, persistNewsfeedArticle } from './newsfeed_analysis.js';

class Ref {
  constructor(store, path) { this.store = store; this.path = path; }
  collection(name) { return new Ref(this.store, `${this.path}/${name}`); }
  doc(name) { return new Ref(this.store, `${this.path}/${name}`); }
  async get() { return { exists: this.path in this.store.data, data: () => this.store.data[this.path], ref: this }; }
  async set(data) { this.store.data[this.path] = data; }
}
class Store {
  constructor() { this.data = {}; }
  collection(name) { return new Ref(this, name); }
  async runTransaction(fn) {
    const writes = [];
    const value = await fn({ get: (r) => r.get(), set: (r, d) => writes.push([r, d]) });
    for (const [r, d] of writes) await r.set(d);
    return value;
  }
}

const article = { headline: 'Increased Consistency Drives Growth', body: 'First.\n\nSecond.' };
const now = new Date('2026-10-28T15:00:00Z');

test('D-122-AC-05: a generated article persists as an account inbox record', async () => {
  const store = new Store();
  const result = await persistNewsfeedArticle(store, 'u1', article, '2026-10-28', now);
  assert.equal(result.created, true);
  const records = Object.entries(store.data);
  assert.equal(records.length, 1);
  const [path, record] = records[0];
  assert.match(path, /^users\/u1\/inbox\//);
  assert.equal(record.type, 'article');
  assert.equal(record.title, article.headline);
  assert.equal(record.body, article.body);
  assert.equal(record.occurrenceDate, '2026-10-28');
  assert.equal(record.messageKey, articleMessageKey(article));
});

test('D-122-AC-05: persisting the same article twice keeps one record', async () => {
  const store = new Store();
  await persistNewsfeedArticle(store, 'u1', article, '2026-10-28', now);
  const second = await persistNewsfeedArticle(store, 'u1', article, '2026-10-28', now);
  assert.equal(second.created, false);
  assert.equal(Object.keys(store.data).length, 1);
});

test('D-122-AC-05: a malformed local date falls back to the server UTC day', async () => {
  const store = new Store();
  await persistNewsfeedArticle(store, 'u1', article, 'yesterday', now);
  assert.equal(Object.values(store.data)[0].occurrenceDate, '2026-10-28');
});

test('D-122-AC-05: an empty article is never persisted', async () => {
  const store = new Store();
  const result = await persistNewsfeedArticle(store, 'u1', { headline: '', body: 'x' }, '2026-10-28', now);
  assert.equal(result.created, false);
  assert.equal(Object.keys(store.data).length, 0);
});
