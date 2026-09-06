// D-016/D-057: every AI surface outside setup requires an active trial or
// subscription. Trial state is server-authoritative — a device with a
// manipulated clock cannot extend it, because expiry is evaluated here, on
// every gated call, not trusted from whatever the client last cached.
import admin from 'firebase-admin';

export class EntitlementRequiredError extends Error {
  constructor(entitlement) {
    super('entitlement_required');
    this.status = 402;
    this.entitlement = entitlement;
  }
}

const ENTITLED_STATES = new Set(['trialing', 'subscribed']);

function profileDoc(store, uid) {
  return store.collection('users').doc(uid).collection('profile').doc('main');
}

function db() {
  try { return admin.firestore(); } catch { return null; }
}

// Reads the account's stored entitlement and, if it's a trial that has
// already passed trialExpiresAt, transitions it to 'lapsed' in place before
// returning — so callers never act on a trial the server itself considers
// expired, even if no one has written 'lapsed' yet. Missing uid/store/doc
// resolves to 'pre_trial' (dev mode / not-yet-synced account), never throws.
export async function resolveEntitlement(uid, _store = db(), _now = new Date()) {
  if (!uid || !_store) return 'pre_trial';
  const ref = profileDoc(_store, uid);
  const snap = await ref.get();
  const data = snap.data() ?? {};
  const entitlement = data.entitlement ?? 'pre_trial';
  if (entitlement !== 'trialing') return entitlement;

  const expiresAt = data.trialExpiresAt?.toDate ? data.trialExpiresAt.toDate() : null;
  if (expiresAt && expiresAt.getTime() <= _now.getTime()) {
    await ref.set({ entitlement: 'lapsed' }, { merge: true });
    return 'lapsed';
  }
  return 'trialing';
}

// Throws EntitlementRequiredError unless the account is trialing or
// subscribed. Setup's own free exchange never calls this — it is bounded by
// D-072's call count instead, applied earlier in guardCouncilCall.
export async function requireEntitlement(uid, _store = db(), _now = new Date()) {
  const entitlement = await resolveEntitlement(uid, _store, _now);
  if (!ENTITLED_STATES.has(entitlement)) throw new EntitlementRequiredError(entitlement);
  return entitlement;
}
