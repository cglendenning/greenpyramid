import { createHash } from 'node:crypto';

// Only a successful (2xx) result is replayed. Clients derive requestId from
// the request body, so a cached refusal or failure (rate limit, setup
// allowance, provider error) would be replayed to every identical retry
// forever; those records are reclaimable instead.
function isReplayable(data) {
  return data.state === 'completed' && data.status >= 200 && data.status < 300;
}

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
      if (data.state === 'pending' || isReplayable(data)) return { ref, ...data };
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
      if (status < 200 || status >= 300) {
        // Release the claim so the identical request can be retried; the
        // setup call allowance still bounds how many real calls happen.
        try {
          await claim.ref.delete();
        } catch (e) {
          console.error('setupIdempotency: releasing failed claim:', e.message);
        }
        return original(value);
      }
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
