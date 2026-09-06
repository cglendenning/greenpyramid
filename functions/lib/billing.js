// D-087: per-account spend cap, server-enforced. Ported and adapted from
// Kansei's backend/src/utils/billing.js — same shape (checkBillingLimit /
// recordCost against a Firestore-backed running total), adapted for a
// recurring monthly cap (D-087) rather than a lifetime free-tier ceiling.
import admin from 'firebase-admin';

// D-087: the default cap for both trialing and subscribed accounts,
// resetting monthly. Editable per-account directly on the account's
// Firestore profile document (an operator override, not client-exposed) —
// that's what lets a specific account's cap be raised without a code change.
export const DEFAULT_SPEND_CAP_USD = 5.0;

// D-041: published per-token rates (USD), used to compute real cost from
// actual usage — never estimated. All three tiers are priced here since
// D-041's model is now switchable at runtime (config/council) — a rate
// missing for whichever model is actually selected would silently record
// zero cost for every call.
export const MODEL_RATES = {
  'claude-opus-5': { input: 5e-6, output: 25e-6 },
  'claude-sonnet-5': { input: 3e-6, output: 15e-6 },
  'claude-haiku-4-5': { input: 1e-6, output: 5e-6 },
};

export class SpendLimitError extends Error {
  constructor(totalSpendUsd, spendCapUsd) {
    super('spend_limit_exceeded');
    this.status = 402;
    this.totalSpendUsd = totalSpendUsd;
    this.spendCapUsd = spendCapUsd;
  }
}

function monthKey(date = new Date()) {
  return `${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, '0')}`;
}

function profileDoc(store, uid) {
  return store.collection('users').doc(uid).collection('profile').doc('main');
}

function db() {
  try { return admin.firestore(); } catch { return null; }
}

// Effective spend for the current month — a record from a prior month
// (spendMonthKey mismatch) is never counted, even if totalSpendUsd itself
// hasn't been zeroed out yet (that happens lazily, in recordCost).
function effectiveSpend(data, now) {
  if ((data.spendMonthKey ?? null) !== monthKey(now)) return 0;
  return data.totalSpendUsd ?? 0;
}

// Throws SpendLimitError if the account has reached its cap. No-ops when
// uid or the store is absent (dev mode / unauthenticated). _store and _now
// are injectable for testing; default to the live Firestore instance / now.
export async function checkSpendLimit(uid, _store = db(), _now = new Date()) {
  if (!uid || !_store) return;
  const snap = await profileDoc(_store, uid).get();
  const data = snap.data() ?? {};
  const cap = data.spendCapUsd ?? DEFAULT_SPEND_CAP_USD;
  const spend = effectiveSpend(data, _now);
  if (spend >= cap) throw new SpendLimitError(spend, cap);
}

// Records actual cost from real token usage, atomically, resetting the
// running total if the calendar month has rolled over since the last
// record. Fire-and-forget safe — callers should .catch() so a Firestore
// error never blocks the API response that already succeeded.
export async function recordCost(uid, model, inputTokens = 0, outputTokens = 0, _store = db(), _now = new Date()) {
  if (!uid || !_store) return;
  const rates = MODEL_RATES[model];
  const cost = rates ? inputTokens * rates.input + outputTokens * rates.output : 0;
  if (cost <= 0) return;

  const ref = profileDoc(_store, uid);
  const currentMonth = monthKey(_now);
  await _store.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.data() ?? {};
    const carriedOver = (data.spendMonthKey ?? null) === currentMonth
      ? (data.totalSpendUsd ?? 0)
      : 0;
    tx.set(ref, {
      totalSpendUsd: carriedOver + cost,
      spendMonthKey: currentMonth,
    }, { merge: true });
  });
}
