import { test } from 'node:test';
import assert from 'node:assert/strict';
import { generateLifetimeCode, hashLifetimeCode, redeemLifetimeCode, grantLifetimeAccess, revokeLifetimeAccess, LifetimeCodeError } from './lifetime_codes.js';

// D-168-AC-02 / D-168-AC-05 / D-168-AC-06: lifetime revoke/grant semantics,
// billing preservation, and the focused backend verification suite.

class FakeDoc {
  constructor(store, path) { this.store = store; this.path = path; }
  async get() { const data = this.store.data[this.path]; return { exists: data != null, data: () => data }; }
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

test('D-167-AC-01: generated codes are formatted and only their hash is stored', async () => {
  const store = new FakeFirestore();
  const result = await generateLifetimeCode(store, 'admin-1', new Date('2026-09-18T00:00:00Z'));
  assert.match(result.code, /^GP-LIFE-[A-Z0-9]{4}(?:-[A-Z0-9]{4}){3}$/);
  assert.equal(store.data[`lifetimeSubscriptionCodes/${hashLifetimeCode(result.code)}`].code, undefined);
  assert.equal(store.data[`lifetimeSubscriptionCodes/${hashLifetimeCode(result.code)}`].createdBy, 'admin-1');
});

test('D-167-AC-02: redemption atomically grants subscribed lifetime access and consumes the code', async () => {
  const store = new FakeFirestore();
  const generated = await generateLifetimeCode(store, 'admin-1');
  const result = await redeemLifetimeCode(store, 'user-1', generated.code);
  assert.deepEqual(result, { entitlement: 'subscribed', lifetimeAccess: true });
  assert.equal(store.data['users/user-1/profile/main'].lifetimeAccess, true);
  assert.equal(store.data[`lifetimeSubscriptionCodes/${hashLifetimeCode(generated.code)}`].redeemedBy, 'user-1');
  await assert.rejects(() => redeemLifetimeCode(store, 'user-2', generated.code),
    (error) => error instanceof LifetimeCodeError && error.code === 'lifetime_code_redeemed');
});

test('D-167-AC-02: malformed codes do not touch account state', async () => {
  const store = new FakeFirestore();
  await assert.rejects(() => redeemLifetimeCode(store, 'user-1', 'not-a-code'),
    (error) => error instanceof LifetimeCodeError && error.code === 'lifetime_code_invalid');
  assert.equal(Object.keys(store.data).length, 0);
});

test('D-168-AC-02: self revoke removes lifetime access but preserves an active paid subscription', async () => {
  const now = new Date('2026-09-18T00:00:00Z');
  const store = new FakeFirestore({
    'users/user-1/profile/main': {
      entitlement: 'subscribed', lifetimeAccess: true,
      subscriptionExpiresAtMs: now.getTime() + 86400000,
      lifetimeAccessPreviousEntitlement: 'lapsed',
    },
  });
  const result = await revokeLifetimeAccess(store, 'user-1', 'user-1', now);
  assert.deepEqual(result, { entitlement: 'subscribed', lifetimeAccess: false });
  assert.equal(store.data['users/user-1/profile/main'].lifetimeAccess, false);
  assert.equal(store.data['users/user-1/profile/main'].entitlement, 'subscribed');
  assert.equal(Object.values(store.data).some((v) => v.action === 'revoke' && v.actorUid === 'user-1'), true);
});

test('D-168-AC-05: admin grant and revoke are audited and restore the prior entitlement', async () => {
  const now = new Date('2026-09-18T00:00:00Z');
  const store = new FakeFirestore({ 'users/user-1/profile/main': { entitlement: 'lapsed' } });
  assert.deepEqual(await grantLifetimeAccess(store, 'user-1', 'admin-1', now), { entitlement: 'subscribed', lifetimeAccess: true });
  assert.deepEqual(await revokeLifetimeAccess(store, 'user-1', 'admin-1', now), { entitlement: 'lapsed', lifetimeAccess: false });
  assert.equal(Object.values(store.data).filter((v) => v.action).length, 2);
});

// D-167-AC-06: the lifetime-code security and single-use behavior is covered
// by this focused suite and is included in the release verification pass.
