import { createHash } from 'node:crypto';

// An unresolved dispatch never expires into a second potentially billable call.
export async function claimSetupRequest(store, uid, key, path, body) {
  if (!/^[0-9a-f-]{36}$/i.test(key ?? '')) throw new Error('request_id_required');
  const ref = store.collection('users').doc(uid).collection('setupRequests').doc(key);
  const fingerprint = createHash('sha256').update(JSON.stringify([path, body])).digest('hex');
  return store.runTransaction(async tx => {
    const snap = await tx.get(ref);
    if (snap.exists) {
      const data = snap.data();
      if (data.fingerprint !== fingerprint) throw new Error('request_id_payload_conflict');
      return { ref, ...data };
    }
    tx.set(ref, { fingerprint, state: 'pending' });
    return { ref, fingerprint, state: 'claimed' };
  });
}

export function setupIdempotency(getStore) {
  return async (req, res, next) => {
    if (!req.body?.sessionId) return res.status(400).json({ error: 'session_required' });
    let claim;
    try {
      claim = await claimSetupRequest(getStore(), req.uid, req.body.requestId, req.path, req.body);
    } catch (e) { return res.status(400).json({ error: e.message }); }
    if (claim.state === 'completed') return res.status(claim.status).json(claim.response);
    if (claim.state === 'pending') return res.status(503).json({ error: 'request_pending_reconciliation' });
    const original = res.json.bind(res);
    res.json = async value => {
      const status = res.statusCode;
      try {
        await claim.ref.set({ fingerprint: claim.fingerprint, state: 'completed', status, response: value });
        return original(value);
      } catch {
        return res.status(503) && original({ error: 'request_pending_reconciliation' });
      }
    };
    next();
  };
}
