// D-041 (amended): each surface's model is a single global Firestore
// document, not a hardcoded constant — editable by hand to move between
// Anthropic model tiers without a redeploy. `config/<surface>` is separate
// per surface (config/council, config/notifications, ...), preserving
// D-041's "one configuration location per surface" rule rather than
// collapsing every surface into one shared blob.
import admin from 'firebase-admin';

// Cheapest Anthropic tier — the deliberate starting point (owner's call,
// 2026-09-06): validate quality at the lowest cost before spending more.
export const FALLBACK_MODEL = 'claude-haiku-4-5';

// Read on every call but cached briefly — a global switch should take
// effect for all users within roughly a minute, not require a redeploy,
// but not every call needs its own Firestore round trip.
export const CACHE_TTL_MS = 60_000;

function db() {
  try { return admin.firestore(); } catch { return null; }
}

/// Builds a getModel(store?, now?)/_resetCacheForTest() pair scoped to one
/// `config/{docId}` document. Each surface gets its own instance so their
/// caches (and any future divergence in fallback/TTL) stay independent.
export function makeModelConfig(docId, fallback = FALLBACK_MODEL) {
  let cached = null;
  let cachedAt = 0;

  async function getModel(_store = db(), _now = Date.now()) {
    if (cached && (_now - cachedAt) < CACHE_TTL_MS) return cached;
    try {
      if (!_store) throw new Error('no Firestore instance available');
      const snap = await _store.collection('config').doc(docId).get();
      const model = snap.data()?.model;
      cached = typeof model === 'string' && model.length > 0 ? model : fallback;
    } catch (e) {
      console.error(`getModel(${docId}): falling back, could not read config/${docId}:`, e.message);
      cached = cached ?? fallback;
    }
    cachedAt = _now;
    return cached;
  }

  function _resetCacheForTest() {
    cached = null;
    cachedAt = 0;
  }

  return { getModel, _resetCacheForTest };
}

// D-050/D-028: the Council's model.
const council = makeModelConfig('council');
export const getCouncilModel = council.getModel;
export const _resetModelCacheForTest = council._resetCacheForTest;

// D-036/D-037: the notification generator's model — its own configuration
// location, independently switchable from the Council's.
const notifications = makeModelConfig('notifications');
export const getNotificationModel = notifications.getModel;
export const _resetNotificationModelCacheForTest = notifications._resetCacheForTest;
