import { createHash } from 'node:crypto';

const EVENT_ID = /^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$/;
const EVENT_TYPES = new Set([
  'task', 'checkbox', 'intervention', 'interaction', 'context', 'experiment', 'model',
]);

function fingerprint(event) {
  return createHash('sha256').update(JSON.stringify({
    type: event.type,
    source: event.source,
    schemaVersion: event.schemaVersion,
    provenance: event.provenance,
    data: event.data,
  })).digest('hex');
}

export function validateBehavioralEvent(event) {
  if (!event || typeof event !== 'object' || Array.isArray(event)) throw new Error('event_invalid');
  if (!EVENT_ID.test(event.eventId ?? '')) throw new Error('event_id_invalid');
  if (!EVENT_TYPES.has(event.type)) throw new Error('event_type_invalid');
  if (typeof event.source !== 'string' || event.source.length < 1 || event.source.length > 64) {
    throw new Error('event_source_invalid');
  }
  if (!Number.isInteger(event.schemaVersion) || event.schemaVersion < 1) throw new Error('event_schema_invalid');
  if (!event.provenance || typeof event.provenance !== 'object' || Array.isArray(event.provenance)) {
    throw new Error('event_provenance_invalid');
  }
  if (!event.data || typeof event.data !== 'object' || Array.isArray(event.data)) throw new Error('event_data_invalid');
  return event;
}

/**
 * D-153: append-only, account-scoped behavioral history. The uid is supplied
 * by verified Firebase Auth at the boundary; it is never accepted from an
 * event payload. Existing IDs are replay-safe, while a changed payload is a
 * conflict rather than an overwrite.
 */
export async function appendBehavioralEvents(store, uid, rawEvents, now = new Date()) {
  if (!uid) throw new Error('account_uid_required');
  if (!Array.isArray(rawEvents) || rawEvents.length < 1 || rawEvents.length > 100) throw new Error('events_invalid');
  const events = rawEvents.map(validateBehavioralEvent);
  const ids = new Set();
  for (const event of events) {
    if (ids.has(event.eventId)) throw new Error('duplicate_event_id');
    ids.add(event.eventId);
  }

  const collection = store.collection('users').doc(uid).collection('behavioralEvents');
  const results = [];
  await store.runTransaction(async tx => {
    const refs = events.map((event) => collection.doc(event.eventId));
    const snapshots = await Promise.all(refs.map((ref) => tx.get(ref)));
    events.forEach((event, index) => {
      const ref = refs[index];
      const prior = snapshots[index];
      const hash = fingerprint(event);
      if (prior.exists) {
        if (prior.data()?.fingerprint !== hash) throw new Error('event_payload_conflict');
        results.push({ eventId: event.eventId, outcome: 'duplicate' });
        return;
      }
      tx.create(ref, {
        eventId: event.eventId,
        accountUid: uid,
        type: event.type,
        source: event.source,
        schemaVersion: event.schemaVersion,
        provenance: event.provenance,
        data: event.data,
        occurredAt: now.toISOString(),
        fingerprint: hash,
      });
      results.push({ eventId: event.eventId, outcome: 'appended' });
    });
  });
  return { results };
}

