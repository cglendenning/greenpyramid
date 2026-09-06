// D-041 (amended): the Council's model is a single global Firestore
// document, not a hardcoded constant — editable by hand to move between
// Anthropic model tiers without a redeploy. `config/council` is separate
// from `config/<other-surface>` documents any future surface would get,
// preserving D-041's "one configuration location per surface" rule rather
// than collapsing every surface into one shared blob.
import admin from 'firebase-admin';

// Cheapest Anthropic tier — the deliberate starting point (owner's call,
// 2026-09-06): validate quality at the lowest cost before spending more.
export const FALLBACK_MODEL = 'claude-haiku-4-5';

// Read on every call but cached briefly — a global switch should take
// effect for all users within roughly a minute, not require a redeploy,
// but every advisor turn does not need its own Firestore round trip.
export const CACHE_TTL_MS = 60_000;

let cached = null;
let cachedAt = 0;

function db() {
  try { return admin.firestore(); } catch { return null; }
}

// _store and _now are injectable for testing.
export async function getCouncilModel(_store = db(), _now = Date.now()) {
  if (cached && (_now - cachedAt) < CACHE_TTL_MS) return cached;
  try {
    if (!_store) throw new Error('no Firestore instance available');
    const snap = await _store.collection('config').doc('council').get();
    const model = snap.data()?.model;
    cached = typeof model === 'string' && model.length > 0 ? model : FALLBACK_MODEL;
  } catch (e) {
    console.error('getCouncilModel: falling back, could not read config/council:', e.message);
    cached = cached ?? FALLBACK_MODEL;
  }
  cachedAt = _now;
  return cached;
}

// Test-only: clears the module-level cache between test cases.
export function _resetModelCacheForTest() {
  cached = null;
  cachedAt = 0;
}
