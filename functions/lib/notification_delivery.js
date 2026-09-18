import { createHash } from 'node:crypto';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export class NotificationDeliveryError extends Error {
  constructor(message, status = 400) {
    super(message);
    this.status = status;
  }
}

function requireUuid(value, name) {
  if (typeof value !== 'string' || !UUID.test(value)) {
    throw new NotificationDeliveryError(`${name}_invalid`);
  }
}

function installationRef(store, uid, installationId) {
  return store.collection('users').doc(uid).collection('installations').doc(installationId);
}

function inboxRef(store, uid, messageKey) {
  const id = createHash('sha256').update(messageKey).digest('hex');
  return store.collection('users').doc(uid).collection('inbox').doc(id);
}

function dispatchRef(store, uid, messageKey) {
  const id = createHash('sha256').update(messageKey).digest('hex');
  return store.collection('users').doc(uid).collection('notificationClaims').doc(id);
}

/** Atomically claims one logical notification. Retries return false. */
export async function claimNotificationDispatch(store, uid, messageKey, now = new Date()) {
  if (typeof messageKey !== 'string' || messageKey.length === 0 || messageKey.length > 256) {
    throw new NotificationDeliveryError('message_key_invalid');
  }
  const ref = dispatchRef(store, uid, messageKey);
  return store.runTransaction(async (tx) => {
    const existing = await tx.get(ref);
    if (existing.exists) {
      const state = existing.data()?.state;
      if (state === 'failed') {
        tx.set(ref, { state: 'claimed', claimedAt: now }, { merge: true });
        return true;
      }
      return false;
    }
    tx.set(ref, { uid, messageKey, state: 'claimed', claimedAt: now });
    return true;
  });
}

/** Records that the provider accepted this logical notification. */
export async function completeNotificationDispatch(store, uid, messageKey, now = new Date()) {
  const ref = dispatchRef(store, uid, messageKey);
  await ref.set({ state: 'sent', sentAt: now }, { merge: true });
}

/** Releases a failed claim so the same stable key can be retried. */
export async function failNotificationDispatch(store, uid, messageKey, now = new Date()) {
  const ref = dispatchRef(store, uid, messageKey);
  await ref.set({ state: 'failed', failedAt: now }, { merge: true });
}

export async function registerInstallation(store, uid, request, now = new Date()) {
  requireUuid(request?.requestId, 'request_id');
  requireUuid(request?.installationId, 'installation_id');
  if (typeof request.token !== 'string' || request.token.length === 0 || request.token.length > 4096) {
    throw new NotificationDeliveryError('token_invalid');
  }
  if (typeof request.enabled !== 'boolean' || typeof request.timezone !== 'string' || !request.timezone) {
    throw new NotificationDeliveryError('installation_fields_invalid');
  }
  try {
    new Intl.DateTimeFormat('en-US', { timeZone: request.timezone }).format();
  } catch {
    throw new NotificationDeliveryError('timezone_invalid');
  }
  if (!Number.isInteger(request.expectedRevision) || request.expectedRevision < 0) {
    throw new NotificationDeliveryError('revision_invalid');
  }

  const target = installationRef(store, uid, request.installationId);
  return store.runTransaction(async (tx) => {
    const current = await tx.get(target);
    const currentData = current.exists ? current.data() : null;
    const currentRevision = currentData?.revision ?? 0;
    if (currentRevision !== request.expectedRevision) {
      throw new NotificationDeliveryError('revision_conflict', 409);
    }

    // An installation id is stable across account linking. Disable the old
    // account's copy before enabling it for the authenticated uid.
    const oldCopies = await tx.get(store.collectionGroup('installations'));
    for (const doc of oldCopies.docs ?? []) {
      if (doc.ref.path === target.path) continue;
      if (doc.data()?.installationId === request.installationId && doc.data()?.enabled) {
        tx.set(doc.ref, { enabled: false, revision: (doc.data()?.revision ?? 0) + 1, updatedAt: now }, { merge: true });
      }
    }
    tx.set(target, {
      installationId: request.installationId,
      uid,
      token: request.token,
      enabled: request.enabled,
      timezone: request.timezone,
      revision: currentRevision + 1,
      updatedAt: now,
    }, { merge: true });
    return { requestId: request.requestId, acknowledged: true };
  });
}

export async function upsertInboxItem(store, uid, item, now = new Date()) {
  if (!item?.messageKey || !item?.type || !item?.occurrenceDate) {
    throw new NotificationDeliveryError('inbox_item_invalid');
  }
  const ref = inboxRef(store, uid, item.messageKey);
  return store.runTransaction(async (tx) => {
    const existing = await tx.get(ref);
    if (!existing.exists) {
      tx.set(ref, { ...item, uid, read: false, createdAt: now, updatedAt: now });
    }
    return { created: !existing.exists, messageKey: item.messageKey };
  });
}

/**
 * D-149: the one delivery path for account-scoped user-facing messages.
 * Inbox persistence happens before provider delivery so the account still has
 * a durable record when push permission, token registration, or FCM transport
 * is unavailable. The caller supplies the already-selected semantic result;
 * this helper never chooses policy.
 */
export async function deliverNotification({
  store,
  messaging,
  uid,
  item,
  payload = {},
  now = new Date(),
}) {
  const claimed = await claimNotificationDispatch(store, uid, item.messageKey, now);
  if (!claimed) return { state: 'duplicate', inbox: false, delivered: false };

  await upsertInboxItem(store, uid, item, now);
  const installationSnap = await store.collection('users').doc(uid)
      .collection('installations').where('enabled', '==', true).get();
  const installations = installationSnap.docs.map((doc) => doc.data())
      .filter((installation) => installation.token);
  if (installations.length === 0) {
    await failNotificationDispatch(store, uid, item.messageKey, now);
    return { state: 'no_installation', inbox: true, delivered: false };
  }

  try {
    const response = await messaging.sendEachForMulticast({
      tokens: installations.map((installation) => installation.token),
      notification: { title: item.title, body: item.body },
      data: payload,
    });
    if (response.successCount > 0) {
      await completeNotificationDispatch(store, uid, item.messageKey, now);
      return { state: 'sent', inbox: true, delivered: true };
    }
    await failNotificationDispatch(store, uid, item.messageKey, now);
    return { state: 'failed', inbox: true, delivered: false };
  } catch (error) {
    await failNotificationDispatch(store, uid, item.messageKey, now);
    return { state: 'failed', inbox: true, delivered: false, error };
  }
}

export async function markInboxRead(store, uid, request, now = new Date()) {
  requireUuid(request?.requestId, 'request_id');
  if (typeof request.messageKey !== 'string' || request.messageKey.length === 0 || request.messageKey.length > 256) {
    throw new NotificationDeliveryError('message_key_invalid');
  }
  const ref = inboxRef(store, uid, request.messageKey);
  return store.runTransaction(async (tx) => {
    const existing = await tx.get(ref);
    if (existing.exists) tx.set(ref, { read: true, readAt: now, updatedAt: now }, { merge: true });
    return { requestId: request.requestId, acknowledged: true };
  });
}

export function notificationMessageKey({ type, occurrenceDate, slot = 'default', habitIds = [] }) {
  return `${type}:${occurrenceDate}:${slot}:${[...habitIds].sort().join(',')}`;
}
