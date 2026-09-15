// D-146/R-SPEND: server-owned frequency limits. The client may use local
// guards for UX, but only this transaction decides whether a model call may
// proceed. Minute and day buckets are UTC, matching the canonical reset rule.
import admin from 'firebase-admin';

export const CALLS_PER_MINUTE = 5;
export const CALLS_PER_DAY = 75;

export class RateLimitError extends Error {
  constructor(scope, limit) {
    super(`rate_limited:${scope}`);
    this.status = 429;
    this.scope = scope;
    this.limit = limit;
  }
}

function profileDoc(store, uid) {
  return store.collection('users').doc(uid).collection('profile').doc('main');
}

function db() {
  try { return admin.firestore(); } catch { return null; }
}

function bucketKeys(now) {
  const iso = now.toISOString();
  return {
    minute: iso.slice(0, 16),
    day: iso.slice(0, 10),
  };
}

export async function guardCallFrequency(uid, _store = db(), _now = new Date()) {
  if (!uid || !_store) return;
  const keys = bucketKeys(_now);
  const ref = profileDoc(_store, uid);
  await _store.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.data() ?? {};
    const prior = data.aiRateLimit ?? {};
    const minuteCount = prior.minuteKey === keys.minute ? Number(prior.minuteCount) || 0 : 0;
    const dayCount = prior.dayKey === keys.day ? Number(prior.dayCount) || 0 : 0;
    if (minuteCount >= CALLS_PER_MINUTE) throw new RateLimitError('minute', CALLS_PER_MINUTE);
    if (dayCount >= CALLS_PER_DAY) throw new RateLimitError('day', CALLS_PER_DAY);
    tx.set(ref, {
      aiRateLimit: {
        minuteKey: keys.minute,
        minuteCount: minuteCount + 1,
        dayKey: keys.day,
        dayCount: dayCount + 1,
      },
    }, { merge: true });
  });
}
