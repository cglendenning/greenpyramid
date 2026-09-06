// D-070: RevenueCat is authoritative for the *subscribed* state only —
// trial state (D-057/D-059) is never touched here, and this never grants a
// trial. `app_user_id` is the Firebase uid: the client calls
// `Purchases.logIn(uid)` right after Firebase sign-in (D-030), so RevenueCat
// always reports back the same id this backend already keys everything on.
const SUBSCRIBED_EVENTS = new Set([
  'INITIAL_PURCHASE',
  'RENEWAL',
  'UNCANCELLATION',
  'PRODUCT_CHANGE',
  'TRANSFER',
]);

// CANCELLATION alone does not end access — the user keeps it through the
// remainder of the billing period they already paid for, and RevenueCat
// sends EXPIRATION separately when access actually ends. Only EXPIRATION
// moves the account off 'subscribed'.
const LAPSED_EVENTS = new Set(['EXPIRATION']);

function profileDoc(store, uid) {
  return store.collection('users').doc(uid).collection('profile').doc('main');
}

// Webhook auth is a shared-secret string, configured identically in the
// RevenueCat dashboard's webhook "Authorization header" field and in this
// function's own secret. Compared verbatim — no assumed prefix or scheme.
export function verifyWebhookAuth(headerValue, expectedSecret) {
  return !!expectedSecret && !!headerValue && headerValue === expectedSecret;
}

// Returns the entitlement transition applied ('subscribed' | 'lapsed'), or
// null if this event type doesn't change entitlement (BILLING_ISSUE, TEST,
// etc.) or is missing the fields this needs.
export async function applyRevenueCatEvent(event, _store) {
  const uid = event?.app_user_id;
  const type = event?.type;
  if (!uid || !type || !_store) return null;

  let next = null;
  if (SUBSCRIBED_EVENTS.has(type)) next = 'subscribed';
  else if (LAPSED_EVENTS.has(type)) next = 'lapsed';
  else return null;

  await profileDoc(_store, uid).set({ entitlement: next }, { merge: true });
  return next;
}
