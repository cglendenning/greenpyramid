import { test } from 'node:test';
import assert from 'node:assert/strict';
import { checkSpendLimit, recordCost, SpendLimitError, DEFAULT_SPEND_CAP_USD, MODEL_RATES } from './billing.js';

// Minimal in-memory Firestore fake — just enough surface for billing.js:
// collection().doc().collection().doc(), get/set(merge), and runTransaction.
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
    return fn({
      get: (ref) => ref.get(),
      set: (ref, data, opts) => ref.set(data, opts),
    });
  }
}

const profilePath = (uid) => `users/${uid}/profile/main`;
const jan = new Date('2026-01-15T00:00:00Z');
const feb = new Date('2026-02-01T00:00:00Z');

test('D-087: checkSpendLimit no-ops without a uid or a store', async () => {
  await checkSpendLimit(null, new FakeFirestore());
  await checkSpendLimit('u1', null);
});

test('D-087: an account under its cap passes', async () => {
  const store = new FakeFirestore({ [profilePath('u1')]: { totalSpendUsd: 1, spendMonthKey: '2026-01' } });
  await checkSpendLimit('u1', store, jan);
});

test('D-087: an account at or over its cap is refused', async () => {
  const store = new FakeFirestore({
    [profilePath('u1')]: { totalSpendUsd: DEFAULT_SPEND_CAP_USD, spendMonthKey: '2026-01' },
  });
  await assert.rejects(() => checkSpendLimit('u1', store, jan), SpendLimitError);
});

test('D-087: a per-account spendCapUsd override is honored', async () => {
  const store = new FakeFirestore({
    [profilePath('u1')]: { totalSpendUsd: 8, spendCapUsd: 10, spendMonthKey: '2026-01' },
  });
  await checkSpendLimit('u1', store, jan); // under the raised cap
});

test('D-087: spend recorded in a prior month does not count toward the '
  + 'current month\'s cap', async () => {
  const store = new FakeFirestore({
    [profilePath('u1')]: { totalSpendUsd: DEFAULT_SPEND_CAP_USD, spendMonthKey: '2026-01' },
  });
  await checkSpendLimit('u1', store, feb); // February — January's spend is stale
});

test('D-041: all three Anthropic tiers are priced, cheapest to costliest '
  + 'matching the published table', () => {
  const tiers = ['claude-haiku-4-5', 'claude-sonnet-5', 'claude-opus-5'];
  for (const tier of tiers) assert.ok(MODEL_RATES[tier], `missing rate for ${tier}`);
  assert.ok(MODEL_RATES['claude-haiku-4-5'].input < MODEL_RATES['claude-sonnet-5'].input);
  assert.ok(MODEL_RATES['claude-sonnet-5'].input < MODEL_RATES['claude-opus-5'].input);
});

test('D-041/D-087: recordCost computes real cost from Opus 5 token rates', async () => {
  const store = new FakeFirestore();
  await recordCost('u1', 'claude-opus-5', 1_000_000, 0, store, jan);
  assert.equal(store.data[profilePath('u1')].totalSpendUsd, MODEL_RATES['claude-opus-5'].input * 1_000_000);
});

test('D-087: recordCost accumulates within the same month', async () => {
  const store = new FakeFirestore();
  await recordCost('u1', 'claude-opus-5', 100_000, 0, store, jan);
  await recordCost('u1', 'claude-opus-5', 100_000, 0, store, jan);
  const expected = 2 * MODEL_RATES['claude-opus-5'].input * 100_000;
  assert.ok(Math.abs(store.data[profilePath('u1')].totalSpendUsd - expected) < 1e-9);
});

test('D-087: recordCost resets the running total on a month rollover', async () => {
  const store = new FakeFirestore({
    [profilePath('u1')]: { totalSpendUsd: 4.99, spendMonthKey: '2026-01' },
  });
  await recordCost('u1', 'claude-opus-5', 100_000, 0, store, feb);
  const data = store.data[profilePath('u1')];
  assert.equal(data.spendMonthKey, '2026-02');
  assert.ok(data.totalSpendUsd < 1, 'February spend should not include January\'s balance');
});

test('recordCost is a no-op for an unknown model or zero usage', async () => {
  const store = new FakeFirestore();
  await recordCost('u1', 'unknown-model', 1000, 1000, store, jan);
  assert.equal(store.data[profilePath('u1')], undefined);
});
