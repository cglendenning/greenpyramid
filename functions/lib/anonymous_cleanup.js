// D-147-AC-06: server-owned cleanup for abandoned anonymous accounts.
// Eligibility is rechecked against Auth and the server profile immediately
// before deletion; a client cannot manufacture an expired marker and cause a
// linked account to be removed.

const MAX_RETRIES = 3;

function isAnonymous(user) {
  return user && Array.isArray(user.providerData) && user.providerData.length === 0;
}

function isEligible(profile, user, now) {
  const ttl = profile?.ttlAt?.toDate ? profile.ttlAt.toDate() : profile?.ttlAt instanceof Date ? profile.ttlAt : null;
  return isAnonymous(user) && profile?.entitlement === 'pre_trial' && profile?.setupComplete !== true && ttl && ttl.getTime() <= now.getTime();
}

async function retry(action, attempts = MAX_RETRIES) {
  let last;
  for (let i = 0; i < attempts; i += 1) {
    try { return await action(); } catch (error) { last = error; }
  }
  throw last;
}

async function deleteTree(ref) {
  for (const collection of await ref.listCollections()) {
    const snapshot = await collection.get();
    for (const doc of snapshot.docs) await deleteTree(doc.ref);
  }
  await ref.delete();
}

export async function cleanupAnonymousAccounts(store, auth, now = new Date()) {
  const candidates = await store.collection('users').where('ttlAt', '<=', now).limit(100).get();
  const outcomes = [];
  for (const candidate of candidates.docs) {
    const uid = candidate.id;
    const userRef = store.collection('users').doc(uid);
    const profile = (await userRef.collection('profile').doc('main').get()).data() ?? {};
    let user;
    try { user = await auth.getUser(uid); } catch (error) {
      if (error.code === 'auth/user-not-found') continue;
      outcomes.push({ uid, outcome: 'failed', error: error.code ?? 'auth_lookup_failed' });
      continue;
    }
    if (!isEligible(profile, user, now)) continue;
    try {
      await retry(() => deleteTree(userRef));
      await retry(() => auth.deleteUser(uid));
      await store.collection('cleanupAudit').doc(uid).set({ outcome: 'deleted', reason: 'anonymous_ttl_expired', completedAt: now });
      outcomes.push({ uid, outcome: 'deleted' });
    } catch (error) {
      await store.collection('cleanupAudit').doc(uid).set({ outcome: 'failed', reason: 'anonymous_ttl_expired', error: error.code ?? error.message, attemptedAt: now });
      outcomes.push({ uid, outcome: 'failed', error: error.code ?? 'cleanup_failed' });
    }
  }
  return outcomes;
}

export { isEligible, retry };
