function iso(value) {
  if (!value) return null;
  if (typeof value?.toDate === 'function') return value.toDate().toISOString();
  if (value instanceof Date) return value.toISOString();
  return typeof value === 'number' ? new Date(value).toISOString() : String(value);
}

function profileUid(doc) {
  return doc.ref.path.split('/')[1];
}

function userRecord(uid, authUser, profile = {}) {
  const firstName = profile.firstName || authUser?.displayName?.split(/\s+/)[0] || null;
  return {
    uid,
    firstName,
    displayName: firstName || authUser?.email || 'Unnamed user',
    email: authUser?.email || profile.email || null,
    providers: (authUser?.providerData || []).map((p) => p.providerId),
    entitlement: profile.entitlement || 'pre_trial',
    lifetimeAccess: profile.lifetimeAccess === true,
    setupComplete: profile.setupComplete === true,
    subscriptionExpiresAtMs: profile.subscriptionExpiresAtMs || null,
    subscriptionSource: profile.subscriptionSource || null,
    totalSpendUsd: Number(profile.totalSpendUsd || 0),
    aiCalls: Number(profile.aiCalls || 0),
    createdAt: iso(authUser?.metadata?.creationTime || profile.createdAt),
    lastSignInAt: iso(authUser?.metadata?.lastSignInTime || profile.lastSignInAt),
  };
}

export function buildAdminUserSummary({ authUsers = [], profiles = [] }) {
  const authByUid = new Map(authUsers.map((u) => [u.uid, u]));
  const uids = new Set([...authByUid.keys(), ...profiles.map(profileUid)]);
  const users = [...uids].map((uid) => userRecord(uid, authByUid.get(uid), profiles.find((p) => profileUid(p) === uid)?.data() || {}));
  users.sort((a, b) => a.displayName.toLowerCase().localeCompare(b.displayName.toLowerCase()));
  const count = (fn) => users.filter(fn).length;
  return {
    summary: {
      totalUsers: users.length,
      namedUsers: count((u) => Boolean(u.firstName)),
      setupComplete: count((u) => u.setupComplete),
      trialing: count((u) => u.entitlement === 'trialing'),
      subscribed: count((u) => u.entitlement === 'subscribed'),
      lifetimeSubscribers: count((u) => u.lifetimeAccess),
      paidSubscribers: count((u) => u.entitlement === 'subscribed' && !u.lifetimeAccess),
      lapsed: count((u) => u.entitlement === 'lapsed'),
      totalSpendUsd: users.reduce((sum, u) => sum + u.totalSpendUsd, 0),
      aiCalls: users.reduce((sum, u) => sum + u.aiCalls, 0),
    },
    users,
  };
}

export function buildAdminUserDetail({ uid, authUser, profile = {}, usage = {}, audit = [] }) {
  return {
    ...userRecord(uid, authUser, profile),
    trialStartedAt: iso(profile.trialStartedAt),
    trialExpiresAt: iso(profile.trialExpiresAt),
    setupCompletedAt: iso(profile.setupCompletedAt),
    spendCapUsd: Number(profile.spendCapUsd || 0),
    subscriptionEventTimestampMs: profile.subscriptionEventTimestampMs || null,
    lifetimeAccessGrantedAt: iso(profile.lifetimeAccessGrantedAt),
    lifetimeAccessGrantedBy: profile.lifetimeAccessGrantedBy || null,
    lifetimeAccessRevokedAt: iso(profile.lifetimeAccessRevokedAt),
    lifetimeAccessRevokedBy: profile.lifetimeAccessRevokedBy || null,
    lifetimeAccessSource: profile.lifetimeAccessSource || null,
    lifetimeCodeId: profile.lifetimeCodeId || null,
    usage,
    lifetimeAudit: audit.map((entry) => ({
      action: entry.action,
      source: entry.source,
      actorUid: entry.actorUid,
      createdAt: iso(entry.createdAt),
    })),
  };
}
