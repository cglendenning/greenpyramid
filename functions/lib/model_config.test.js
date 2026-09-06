import { test } from 'node:test';
import assert from 'node:assert/strict';
import { getCouncilModel, _resetModelCacheForTest, FALLBACK_MODEL, CACHE_TTL_MS } from './model_config.js';

class FakeDoc {
  constructor(store, path) { this.store = store; this.path = path; }
  async get() { return { data: () => this.store.data[this.path] }; }
}
class FakeFirestore {
  constructor(seed = {}) { this.data = seed; }
  collection(name) { return { doc: (id) => new FakeDoc(this, `${name}/${id}`) }; }
}

test('D-041: with no config/council document, falls back to the cheapest '
  + 'tier', async () => {
  _resetModelCacheForTest();
  const model = await getCouncilModel(new FakeFirestore(), Date.now());
  assert.equal(model, FALLBACK_MODEL);
});

test('D-041: a configured model is read from config/council', async () => {
  _resetModelCacheForTest();
  const store = new FakeFirestore({ 'config/council': { model: 'claude-sonnet-5' } });
  const model = await getCouncilModel(store, Date.now());
  assert.equal(model, 'claude-sonnet-5');
});

test('D-041: the result is cached — a second call within the TTL does not '
  + 're-read Firestore', async () => {
  _resetModelCacheForTest();
  let reads = 0;
  const store = new FakeFirestore({ 'config/council': { model: 'claude-opus-5' } });
  const realCollection = store.collection.bind(store);
  store.collection = (name) => { reads++; return realCollection(name); };

  const now = Date.now();
  await getCouncilModel(store, now);
  await getCouncilModel(store, now + 1000);
  assert.equal(reads, 1);
});

test('D-041: the cache expires after CACHE_TTL_MS and re-reads', async () => {
  _resetModelCacheForTest();
  const store = new FakeFirestore({ 'config/council': { model: 'claude-opus-5' } });
  const now = Date.now();
  await getCouncilModel(store, now);

  store.data['config/council'] = { model: 'claude-haiku-4-5' };
  const model = await getCouncilModel(store, now + CACHE_TTL_MS + 1);
  assert.equal(model, 'claude-haiku-4-5');
});

test('D-041: an unreachable Firestore falls back rather than throwing',
  async () => {
    _resetModelCacheForTest();
    const model = await getCouncilModel(null, Date.now());
    assert.equal(model, FALLBACK_MODEL);
  });
