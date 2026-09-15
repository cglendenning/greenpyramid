// D-061: per-account spend cap, server-enforced. Ported and adapted from
// Kansei's backend/src/utils/billing.js — same shape (checkBillingLimit /
// recordCost against a Firestore-backed running total), adapted for a
// recurring monthly cap (D-061) rather than a lifetime free-tier ceiling.
import admin from 'firebase-admin';

// D-061: the default cap for both trialing and subscribed accounts,
// resetting monthly. Editable per-account directly on the account's
// Firestore profile document (an operator override, not client-exposed) —
// that's what lets a specific account's cap be raised without a code change.
export const DEFAULT_SPEND_CAP_USD = 5.0;

// D-145: published per-token rates (USD), used to compute real cost from
// actual usage — never estimated. All three tiers are priced here since
// D-145's model is now switchable at runtime (config/council) — a rate
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

export class UnknownModelPricingError extends Error {
  constructor(model) {
    super(`unknown_model_pricing:${model}`);
    this.status = 500;
    this.model = model;
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

// D-146: reserve the worst-case billable cost before provider dispatch. The
// reservation lives with the server-owned profile and is included in the
// same transaction as the cap check, so concurrent requests cannot both
// spend the same remaining allowance. `reservationId` must be unique per
// provider dispatch and is returned unchanged for settlement.
export async function reserveCost(uid, model, inputTokenBound, maxOutputTokens,
  reservationId, _store = db(), _now = new Date()) {
  if (!uid || !_store) return { reservationId, amountUsd: 0 };
  const rates = MODEL_RATES[model];
  if (!rates) throw new UnknownModelPricingError(model);
  const amountUsd = Math.max(0, inputTokenBound) * rates.input +
    Math.max(0, maxOutputTokens) * rates.output;
  const ref = profileDoc(_store, uid);
  const currentMonth = monthKey(_now);
  await _store.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.data() ?? {};
    const carriedOver = (data.spendMonthKey ?? null) === currentMonth
      ? (data.totalSpendUsd ?? 0) : 0;
    const existing = (data.spendReservations ?? {})[reservationId];
    if (existing) return;
    const reservations = (data.spendMonthKey ?? null) === currentMonth
      ? { ...(data.spendReservations ?? {}) } : {};
    const outstanding = Object.values(reservations)
      .reduce((sum, item) => sum + (Number(item.amountUsd) || 0), 0);
    const cap = data.spendCapUsd ?? DEFAULT_SPEND_CAP_USD;
    if (carriedOver + outstanding + amountUsd > cap) {
      throw new SpendLimitError(carriedOver + outstanding, cap);
    }
    reservations[reservationId] = { amountUsd, model, monthKey: currentMonth };
    tx.set(ref, {
      spendMonthKey: currentMonth,
      spendReservations: reservations,
    }, { merge: true });
  });
  return { reservationId, amountUsd };
}

// D-146: settle exactly once. Actual provider usage becomes committed spend;
// the unused part of the reservation is released in the same transaction.
export async function settleCost(uid, reservationId, model, inputTokens = 0,
  outputTokens = 0, _store = db(), _now = new Date()) {
  if (!uid || !_store) return;
  const rates = MODEL_RATES[model];
  if (!rates) throw new UnknownModelPricingError(model);
  const actual = Math.max(0, inputTokens) * rates.input +
    Math.max(0, outputTokens) * rates.output;
  const ref = profileDoc(_store, uid);
  const currentMonth = monthKey(_now);
  await _store.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.data() ?? {};
    const reservations = { ...(data.spendReservations ?? {}) };
    const reservation = reservations[reservationId];
    if (!reservation) return;
    delete reservations[reservationId];
    const carriedOver = (data.spendMonthKey ?? null) === currentMonth
      ? (data.totalSpendUsd ?? 0) : 0;
    tx.set(ref, {
      totalSpendUsd: carriedOver + actual,
      spendMonthKey: currentMonth,
      spendReservations: reservations,
    }, { merge: true });
  });
}

export async function releaseCost(uid, reservationId, _store = db()) {
  if (!uid || !_store) return;
  const ref = profileDoc(_store, uid);
  await _store.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.data() ?? {};
    const reservations = { ...(data.spendReservations ?? {}) };
    if (!(reservationId in reservations)) return;
    delete reservations[reservationId];
    tx.set(ref, { spendReservations: reservations }, { merge: true });
  });
}
