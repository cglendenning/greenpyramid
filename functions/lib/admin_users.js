function iso(value) {
  if (!value) return null;
  if (typeof value?.toDate === 'function') return value.toDate().toISOString();
  if (value instanceof Date) return value.toISOString();
  return typeof value === 'number' ? new Date(value).toISOString() : String(value);
}

function profileUid(doc) {
  return doc.ref.path.split('/')[1];
}

function realCategoryCount(profile = {}) {
  return Array.isArray(profile.categories)
    ? profile.categories.filter((category) => {
        const name = typeof category?.cat === 'string' ? category.cat.trim() : '';
        return name && !name.startsWith('Empty');
      }).length
    : 0;
}

function setupIsComplete(profile = {}, account = {}, usage = {}) {
  if (profile.setupComplete === true || account.setupComplete === true) return true;
  if (profile.setupCompletedAt || account.setupCompletedAt || account.setupCompletionId) return true;
  // Legacy completed accounts predate the explicit flag. Their durable
  // profile still contains the six real pyramid categories; when detail
  // usage is available, require at least one task as D-001 does.
  const hasPyramid = realCategoryCount(profile) >= 6;
  const hasTask = usage.tasks == null || Number(usage.tasks) >= 1;
  return hasPyramid && hasTask;
}

function userRecord(uid, authUser, profile = {}, account = {}, usage = {}) {
  const firstName = profile.firstName || authUser?.displayName?.split(/\s+/)[0] || null;
  return {
    uid,
    firstName,
    displayName: firstName || authUser?.email || 'Unnamed user',
    email: authUser?.email || profile.email || null,
    providers: (authUser?.providerData || []).map((p) => p.providerId),
    entitlement: profile.entitlement || 'pre_trial',
    lifetimeAccess: profile.lifetimeAccess === true,
    setupComplete: setupIsComplete(profile, account, usage),
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

export function buildAdminUserDetail({ uid, authUser, account = {}, profile = {}, usage = {}, audit = [] }) {
  return {
    ...userRecord(uid, authUser, profile, account, usage),
    trialStartedAt: iso(profile.trialStartedAt || account.trialStartedAt),
    trialExpiresAt: iso(profile.trialExpiresAt || account.trialExpiresAt),
    setupCompletedAt: iso(profile.setupCompletedAt || account.setupCompletedAt),
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
