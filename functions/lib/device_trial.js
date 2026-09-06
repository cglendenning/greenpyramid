// D-021/D-057/D-058/D-059/D-071: grants the one free trial a device (or,
// for the D-034 migration cohort, an account) is owed, exactly once, and
// never lets that grant touch an already-subscribed account.
import admin from 'firebase-admin';
import { queryTwoBits, updateTwoBits } from './device_check.js';

export const TRIAL_DAYS = 3; // D-057
export const MIGRATION_TRIAL_DAYS = 30; // D-071

export class DeviceTrialError extends Error {
  constructor(message) {
    super(message);
    this.status = 400;
  }
}

function db() {
  try { return admin.firestore(); } catch { return null; }
}

function profileDoc(store, uid) {
  return store.collection('users').doc(uid).collection('profile').doc('main');
}

function deviceTrialDoc(store, androidIdHash) {
  return store.collection('deviceTrials').doc(androidIdHash);
}

function trialWindow(days, now) {
  return {
    trialStartedAt: now,
    trialExpiresAt: new Date(now.getTime() + days * 24 * 60 * 60 * 1000),
  };
}

// D-059: the Android marker is a hash the client already computed (SHA-256
// of ANDROID_ID) — this never sees or stores the raw identifier. A device
// that has already consumed its trial lands the account in 'lapsed', not
// 'trialing', even on a brand-new account (the reinstall case D-059 exists
// to close).
async function grantAndroidTrial(uid, androidIdHash, { _store, _now }) {
  if (!androidIdHash) throw new DeviceTrialError('android_id_hash_required');
  const trialRef = deviceTrialDoc(_store, androidIdHash);
  const profileRef = profileDoc(_store, uid);

  return _store.runTransaction(async (tx) => {
    const trialSnap = await tx.get(trialRef);
    if (trialSnap.exists) {
      tx.set(profileRef, { entitlement: 'lapsed' }, { merge: true });
      return { granted: false, entitlement: 'lapsed' };
    }
    const { trialStartedAt, trialExpiresAt } = trialWindow(TRIAL_DAYS, _now);
    tx.set(trialRef, { uid, createdAt: admin.firestore.Timestamp.fromDate(_now) });
    tx.set(profileRef, {
      entitlement: 'trialing',
      trialStartedAt: admin.firestore.Timestamp.fromDate(trialStartedAt),
      trialExpiresAt: admin.firestore.Timestamp.fromDate(trialExpiresAt),
    }, { merge: true });
    return { granted: true, entitlement: 'trialing', trialExpiresAt };
  });
}

// D-059: iOS's marker lives entirely in Apple's DeviceCheck bits — Green
// Pyramid persists no device identifier of its own here, so there is no
// local transaction to guard this with; Apple's query/update pair is the
// only state.
async function grantIosTrial(uid, deviceCheckToken, { _store, _now, deviceCheckConfig }) {
  if (!deviceCheckToken) throw new DeviceTrialError('device_check_token_required');
  const profileRef = profileDoc(_store, uid);

  const { bit0 } = await queryTwoBits(deviceCheckToken, deviceCheckConfig);
  if (bit0) {
    await profileRef.set({ entitlement: 'lapsed' }, { merge: true });
    return { granted: false, entitlement: 'lapsed' };
  }

  await updateTwoBits(deviceCheckToken, { bit0: true, bit1: false, ...deviceCheckConfig });
  const { trialStartedAt, trialExpiresAt } = trialWindow(TRIAL_DAYS, _now);
  await profileRef.set({
    entitlement: 'trialing',
    trialStartedAt: admin.firestore.Timestamp.fromDate(trialStartedAt),
    trialExpiresAt: admin.firestore.Timestamp.fromDate(trialExpiresAt),
  }, { merge: true });
  return { granted: true, entitlement: 'trialing', trialExpiresAt };
}

// The single entry point for both platforms, called once at setup
// completion (D-058). An account that is already subscribed OR already
// trialing is returned untouched: trial bookkeeping is meaningless once a
// subscription exists, and re-running the device-check logic for an
// already-trialing account (e.g. a retried request after a lost response)
// would find its own device marker already set and incorrectly demote it to
// lapsed. Only an account that has never been granted a trial (pre_trial)
// reaches the actual device-binding checks below.
export async function grantTrialIfEligible(
  uid,
  { platform, androidIdHash, deviceCheckToken, deviceCheckConfig } = {},
  _store = db(),
  _now = new Date(),
) {
  if (!uid || !_store) throw new DeviceTrialError('uid_required');

  const profileRef = profileDoc(_store, uid);
  const existing = (await profileRef.get()).data() ?? {};
  if (existing.entitlement === 'subscribed' || existing.entitlement === 'trialing') {
    return { granted: false, entitlement: existing.entitlement };
  }

  if (platform === 'android') return grantAndroidTrial(uid, androidIdHash, { _store, _now });
  if (platform === 'ios') return grantIosTrial(uid, deviceCheckToken, { _store, _now, deviceCheckConfig });
  throw new DeviceTrialError('invalid_platform');
}

// D-071: existing users get one 30-day trial, granted once, at the first
// launch of the build that lands this specification — never device-bound
// (D-059's explicit carve-out for this cohort). Guarded by a transaction on
// the account's own entitlement field, so a retried request can never grant
// it twice: only an account still at 'pre_trial' (never through setup's own
// grant, and never migrated before) is eligible.
export async function grantMigrationTrial(uid, _store = db(), _now = new Date()) {
  if (!uid || !_store) throw new DeviceTrialError('uid_required');
  const profileRef = profileDoc(_store, uid);

  return _store.runTransaction(async (tx) => {
    const snap = await tx.get(profileRef);
    const entitlement = snap.data()?.entitlement ?? 'pre_trial';
    if (entitlement !== 'pre_trial') {
      return { granted: false, entitlement };
    }
    const { trialStartedAt, trialExpiresAt } = trialWindow(MIGRATION_TRIAL_DAYS, _now);
    tx.set(profileRef, {
      entitlement: 'trialing',
      trialStartedAt: admin.firestore.Timestamp.fromDate(trialStartedAt),
      trialExpiresAt: admin.firestore.Timestamp.fromDate(trialExpiresAt),
      migrationTrialGrantedAt: admin.firestore.Timestamp.fromDate(_now),
    }, { merge: true });
    return { granted: true, entitlement: 'trialing', trialExpiresAt };
  });
}
