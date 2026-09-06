import { test } from 'node:test';
import assert from 'node:assert/strict';
import { grantTrialIfEligible, grantMigrationTrial, DeviceTrialError, TRIAL_DAYS, MIGRATION_TRIAL_DAYS, DEVICE_TRIAL_RETENTION_DAYS } from './device_trial.js';

class FakeDoc {
  constructor(store, path) { this.store = store; this.path = path; }
  get exists() { return this.store.data[this.path] !== undefined; }
  async get() {
    const self = this;
    return {
      data: () => self.store.data[self.path],
      get exists() { return self.exists; },
    };
  }
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
const trialPath = (hash) => `deviceTrials/${hash}`;
const now = new Date('2026-06-01T00:00:00Z');

test('D-059: a fresh Android device is granted a 3-day trial and marked '
    + 'consumed', async () => {
  const store = new FakeFirestore();
  const result = await grantTrialIfEligible(
    'u1', { platform: 'android', androidIdHash: 'hash1' }, store, now,
  );
  assert.equal(result.granted, true);
  assert.equal(result.entitlement, 'trialing');
  assert.equal(store.data[profilePath('u1')].entitlement, 'trialing');
  assert.ok(store.data[trialPath('hash1')]);
  const expiresAt = store.data[profilePath('u1')].trialExpiresAt.toDate();
  assert.equal(expiresAt.getTime() - now.getTime(), TRIAL_DAYS * 24 * 60 * 60 * 1000);
});

test('D-060/D-064: the device trial marker carries a 24-month ttlAt so '
    + 'Firestore purges it — retained, not kept forever', () => {
  const store = new FakeFirestore();
  return grantTrialIfEligible(
    'u1', { platform: 'android', androidIdHash: 'hash1' }, store, now,
  ).then(() => {
    const ttlAt = store.data[trialPath('hash1')].ttlAt.toDate();
    assert.equal(ttlAt.getTime() - now.getTime(), DEVICE_TRIAL_RETENTION_DAYS * 24 * 60 * 60 * 1000);
    assert.equal(DEVICE_TRIAL_RETENTION_DAYS, 730, 'D-064 specifies 24 months');
  });
});

test('D-059: an Android device that already consumed its trial lands a '
    + 'brand-new account in lapsed, not trialing — the reinstall case', async () => {
  const store = new FakeFirestore({ [trialPath('hash1')]: { uid: 'old-uid' } });
  const result = await grantTrialIfEligible(
    'new-uid', { platform: 'android', androidIdHash: 'hash1' }, store, now,
  );
  assert.equal(result.granted, false);
  assert.equal(result.entitlement, 'lapsed');
  assert.equal(store.data[profilePath('new-uid')].entitlement, 'lapsed');
});

test('D-059: android_id_hash_required is thrown when no hash is provided', async () => {
  const store = new FakeFirestore();
  await assert.rejects(
    () => grantTrialIfEligible('u1', { platform: 'android' }, store, now),
    DeviceTrialError,
  );
});

test('an already-subscribed account is never downgraded by a trial '
    + 'request, on either platform', async () => {
  const store = new FakeFirestore({ [profilePath('u1')]: { entitlement: 'subscribed' } });
  const result = await grantTrialIfEligible(
    'u1', { platform: 'android', androidIdHash: 'hash1' }, store, now,
  );
  assert.equal(result.granted, false);
  assert.equal(result.entitlement, 'subscribed');
  assert.equal(store.data[profilePath('u1')].entitlement, 'subscribed');
  assert.equal(store.data[trialPath('hash1')], undefined);
});

test('a retried trial request for an already-trialing account is a no-op — '
    + 'it must never re-run the device-check logic and find its own marker '
    + 'already set, which would incorrectly demote the account to lapsed', async () => {
  const store = new FakeFirestore({
    [profilePath('u1')]: { entitlement: 'trialing' },
    [trialPath('hash1')]: { uid: 'u1' },
  });
  const result = await grantTrialIfEligible(
    'u1', { platform: 'android', androidIdHash: 'hash1' }, store, now,
  );
  assert.equal(result.granted, false);
  assert.equal(result.entitlement, 'trialing');
  assert.equal(store.data[profilePath('u1')].entitlement, 'trialing');
});

test('a lapsed account requesting a trial again on the same consumed '
    + 'device is confirmed lapsed, not re-granted', async () => {
  const store = new FakeFirestore({
    [profilePath('u1')]: { entitlement: 'lapsed' },
    [trialPath('hash1')]: { uid: 'u1' },
  });
  const result = await grantTrialIfEligible(
    'u1', { platform: 'android', androidIdHash: 'hash1' }, store, now,
  );
  assert.equal(result.granted, false);
  assert.equal(result.entitlement, 'lapsed');
});

test('invalid_platform is rejected', async () => {
  const store = new FakeFirestore();
  await assert.rejects(
    () => grantTrialIfEligible('u1', { platform: 'web' }, store, now),
    DeviceTrialError,
  );
});

test('D-071: a pre_trial existing-user account is granted a one-time '
    + '30-day migration trial', async () => {
  const store = new FakeFirestore({ [profilePath('u1')]: { entitlement: 'pre_trial' } });
  const result = await grantMigrationTrial('u1', store, now);
  assert.equal(result.granted, true);
  assert.equal(store.data[profilePath('u1')].entitlement, 'trialing');
  const expiresAt = store.data[profilePath('u1')].trialExpiresAt.toDate();
  assert.equal(expiresAt.getTime() - now.getTime(), MIGRATION_TRIAL_DAYS * 24 * 60 * 60 * 1000);
});

test('D-071: the migration trial is never granted twice, even on a '
    + 'retried request', async () => {
  const store = new FakeFirestore({
    [profilePath('u1')]: { entitlement: 'trialing', migrationTrialGrantedAt: 'already-set' },
  });
  const result = await grantMigrationTrial('u1', store, now);
  assert.equal(result.granted, false);
  assert.equal(result.entitlement, 'trialing');
});

test('D-071: an account that already went through setup\'s own device '
    + 'trial (or is subscribed/lapsed) never receives the migration grant', async () => {
  const store = new FakeFirestore({ [profilePath('u1')]: { entitlement: 'subscribed' } });
  const result = await grantMigrationTrial('u1', store, now);
  assert.equal(result.granted, false);
  assert.equal(result.entitlement, 'subscribed');
});
