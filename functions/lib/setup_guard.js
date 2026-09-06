// D-072: the free setup conversation is bounded at 40 model calls,
// enforced server-side — the client cannot be trusted to stop itself.
// Separate from D-087's spend cap: setup is free (D-017), so it is never
// charged against an account's dollar cap; it is bounded by call count
// instead, sitting under AiGuard's existing daily rate limit.
import admin from 'firebase-admin';

export const SETUP_CALL_LIMIT = 40;

export class SetupCallLimitError extends Error {
  constructor(count) {
    super('setup_call_limit_exceeded');
    this.status = 409;
    this.count = count;
  }
}

function sessionDoc(store, uid, sessionId) {
  return store.collection('users').doc(uid).collection('councilSessions').doc(sessionId);
}

function db() {
  try { return admin.firestore(); } catch { return null; }
}

// Atomically checks-and-increments a setup session's call counter. The
// 40th call is allowed through — it's the one D-072 requires to close the
// session gracefully (derive categories, capture what exists, deliver the
// closing synthesis) rather than truncate mid-conversation; the 41st is
// refused. No-ops (never counts, never refuses) when uid/sessionId/store
// is absent.
export async function guardAndCountSetupCall(uid, sessionId, _store = db()) {
  if (!uid || !sessionId || !_store) return 0;
  const ref = sessionDoc(_store, uid, sessionId);
  return _store.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const count = snap.data()?.modelCallCount ?? 0;
    if (count >= SETUP_CALL_LIMIT) throw new SetupCallLimitError(count);
    tx.set(ref, { modelCallCount: count + 1 }, { merge: true });
    return count + 1;
  });
}
