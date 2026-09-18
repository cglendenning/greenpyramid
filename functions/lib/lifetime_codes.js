import { createHash, randomBytes, randomUUID } from 'node:crypto';

// Lifetime gifts are account entitlements, not RevenueCat products. The
// account still uses the normal `subscribed` capability, while this separate
// flag tells every trusted writer that Apple/RevenueCat expiration must not
// remove access.
const ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const CODE_PREFIX = 'GP-LIFE';
const CODE_PATTERN = /^GP-LIFE-[A-Z0-9]{4}(?:-[A-Z0-9]{4}){3}$/;

export class LifetimeCodeError extends Error {
  constructor(code) {
    super(code);
    this.code = code;
  }
}

function entitlementAfterLifetimeRevoke(profile, now) {
  const expiry = Number(profile.subscriptionExpiresAtMs || 0);
  if (expiry > now.getTime()) return 'subscribed';
  return profile.lifetimeAccessPreviousEntitlement || 'lapsed';
}

async function updateLifetimeAccess(store, uid, actorUid, action, source, now) {
  if (!store || !uid || !actorUid) throw new LifetimeCodeError('authentication_required');
  const profileRef = profileDoc(store, uid);
  const auditRef = store.collection('users').doc(uid).collection('lifetimeSubscriptionAudit').doc(randomUUID());
  const apply = async (tx) => {
    const snapshot = await tx.get(profileRef);
    const profile = snapshot.data() || {};
    if (action === 'grant' && profile.lifetimeAccess === true) {
      throw new LifetimeCodeError('account_already_has_lifetime_access');
    }
    if (action === 'revoke' && profile.lifetimeAccess !== true) {
      throw new LifetimeCodeError('lifetime_access_not_active');
    }
    const next = action === 'grant'
      ? {
          entitlement: 'subscribed',
          lifetimeAccess: true,
          lifetimeAccessGrantedAt: now,
          lifetimeAccessGrantedBy: actorUid,
          lifetimeAccessPreviousEntitlement: profile.entitlement || 'lapsed',
          lifetimeAccessSource: source,
          subscriptionSource: source,
        }
      : {
          entitlement: entitlementAfterLifetimeRevoke(profile, now),
          lifetimeAccess: false,
          lifetimeAccessRevokedAt: now,
          lifetimeAccessRevokedBy: actorUid,
          lifetimeAccessSource: null,
          lifetimeCodeId: null,
          subscriptionSource: 'revoked_lifetime',
        };
    tx.set(profileRef, next, { merge: true });
    tx.set(auditRef, {
      action,
      actorUid,
      source,
      previousEntitlement: profile.entitlement || null,
      nextEntitlement: next.entitlement,
      previousLifetimeAccess: profile.lifetimeAccess === true,
      nextLifetimeAccess: next.lifetimeAccess,
      codeId: profile.lifetimeCodeId || null,
      createdAt: now,
    });
    return { entitlement: next.entitlement, lifetimeAccess: next.lifetimeAccess };
  };
  if (typeof store.runTransaction === 'function') return store.runTransaction(apply);
  return apply({ get: (ref) => ref.get(), set: (ref, data, opts) => ref.set(data, opts) });
}

export function grantLifetimeAccess(store, uid, actorUid, now = new Date()) {
  return updateLifetimeAccess(store, uid, actorUid, 'grant', 'admin', now);
}

export function revokeLifetimeAccess(store, uid, actorUid, now = new Date()) {
  return updateLifetimeAccess(store, uid, actorUid, 'revoke', 'self_or_admin', now);
}

function profileDoc(store, uid) {
  return store.collection('users').doc(uid).collection('profile').doc('main');
}

export function normalizeLifetimeCode(value) {
  return String(value ?? '').trim().toUpperCase().replace(/\s+/g, '');
}

export function hashLifetimeCode(code) {
  return createHash('sha256').update(normalizeLifetimeCode(code)).digest('hex');
}

function randomCode() {
  const bytes = randomBytes(16);
  const body = Array.from(bytes, (byte) => ALPHABET[byte % ALPHABET.length]).join('');
  return `${CODE_PREFIX}-${body.slice(0, 4)}-${body.slice(4, 8)}-${body.slice(8, 12)}-${body.slice(12, 16)}`;
}

export async function generateLifetimeCode(store, createdBy, now = new Date()) {
  if (!store || !createdBy) throw new LifetimeCodeError('admin_identity_required');
  const code = randomCode();
  const codeHash = hashLifetimeCode(code);
  const ref = store.collection('lifetimeSubscriptionCodes').doc(codeHash);
  await ref.set({
    codeHash,
    createdAt: now,
    createdBy,
    redeemedAt: null,
    redeemedBy: null,
    kind: 'lifetime_subscription',
  });
  // The raw code is intentionally returned only to the authenticated admin
  // that generated it. It is never stored in Firestore.
  return { code, codeId: codeHash };
}

export async function redeemLifetimeCode(store, uid, rawCode, now = new Date()) {
  const code = normalizeLifetimeCode(rawCode);
  if (!CODE_PATTERN.test(code)) throw new LifetimeCodeError('lifetime_code_invalid');
  if (!store || !uid) throw new LifetimeCodeError('authentication_required');

  const codeRef = store.collection('lifetimeSubscriptionCodes').doc(hashLifetimeCode(code));
  const profileRef = profileDoc(store, uid);
  const apply = async (tx) => {
    const codeSnapshot = await tx.get(codeRef);
    if (!codeSnapshot.exists) throw new LifetimeCodeError('lifetime_code_invalid');
    const stored = codeSnapshot.data() || {};
    if (stored.redeemedAt) throw new LifetimeCodeError('lifetime_code_redeemed');

    const profileSnapshot = await tx.get(profileRef);
    const profile = profileSnapshot.data() || {};
    if (profile.lifetimeAccess === true) {
      throw new LifetimeCodeError('account_already_has_lifetime_access');
    }

    tx.set(profileRef, {
      entitlement: 'subscribed',
      lifetimeAccess: true,
      lifetimeAccessGrantedAt: now,
      lifetimeAccessGrantedBy: uid,
      lifetimeAccessPreviousEntitlement: profile.entitlement || 'lapsed',
      lifetimeAccessSource: 'lifetime_code',
      lifetimeCodeId: codeRef.path.split('/').pop(),
      subscriptionSource: 'lifetime_code',
    }, { merge: true });
    tx.set(codeRef, {
      redeemedAt: now,
      redeemedBy: uid,
    }, { merge: true });
    return { entitlement: 'subscribed', lifetimeAccess: true };
  };

  if (typeof store.runTransaction === 'function') return store.runTransaction(apply);
  return apply({
    get: (ref) => ref.get(),
    set: (ref, data, opts) => ref.set(data, opts),
  });
}
