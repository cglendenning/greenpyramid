// D-147: durable, idempotent cloud operations.  The client may retry an
// operation after a timeout, so the operation record and entity mutation are
// committed in one Firestore transaction.
import { createHash } from 'node:crypto';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const ENTITIES = new Set(['category', 'habit', 'occurrence', 'explanation', 'vision', 'profile', 'pyramid']);

function fingerprint(value) {
  const keys = value && typeof value === 'object' && !Array.isArray(value) ? Object.keys(value).sort() : undefined;
  return createHash('sha256').update(JSON.stringify(value, keys)).digest('hex');
}

export function validateSyncRequest(body) {
  if (!body || !UUID.test(body.requestId ?? '')) throw new Error('request_id_invalid');
  if (!Array.isArray(body.operations) || body.operations.length < 1 || body.operations.length > 100) {
    throw new Error('operations_invalid');
  }
  const ids = new Set();
  for (const op of body.operations) {
    if (!op || !UUID.test(op.operationId ?? '') || ids.has(op.operationId)) throw new Error('operation_id_invalid');
    ids.add(op.operationId);
    if (!ENTITIES.has(op.entity) || !UUID.test(op.entityId ?? '') || !Number.isInteger(op.expectedRevision) || op.expectedRevision < 0) {
      throw new Error('operation_invalid');
    }
    if (!['upsert', 'delete', 'rearrange'].includes(op.kind)) throw new Error('operation_kind_invalid');
    if (op.kind !== 'delete' && op.value == null) throw new Error('operation_value_required');
  }
  return body;
}

function entityKey(op) { return `${op.entity}:${op.entityId}`; }

export async function applySyncRequest(store, uid, rawBody) {
  const body = validateSyncRequest(rawBody);
  const metaRef = store.collection('users').doc(uid).collection('sync').doc('meta');
  const results = [];
  await store.runTransaction(async tx => {
    const metaSnap = await tx.get(metaRef);
    let revision = Number(metaSnap.data()?.revision ?? 0);
    for (const op of body.operations) {
      const opRef = store.collection('users').doc(uid).collection('syncOperations').doc(op.operationId);
      const entityRef = store.collection('users').doc(uid).collection('syncEntities').doc(entityKey(op));
      const prior = await tx.get(opRef);
      if (prior.exists) {
        const saved = prior.data();
        if (saved.fingerprint !== fingerprint(op)) throw new Error('operation_payload_conflict');
        results.push(saved.result);
        continue;
      }
      const currentSnap = await tx.get(entityRef);
      const current = currentSnap.data() ?? { revision: 0, deleted: false, value: null };
      let result;
      if (op.expectedRevision !== Number(current.revision ?? 0)) {
        result = { operationId: op.operationId, outcome: 'conflict', serverRevision: Number(current.revision ?? 0), conflictId: current.lastOperationId ?? null };
      } else {
        const sameValue = op.kind === 'upsert' && !current.deleted && fingerprint(current.value) === fingerprint(op.value);
        if (sameValue) {
          result = { operationId: op.operationId, outcome: 'no_op', serverRevision: Number(current.revision ?? 0), conflictId: null };
        } else {
          revision += 1;
          const deleted = op.kind === 'delete';
          tx.set(entityRef, { revision, entity: op.entity, entityId: op.entityId, deleted, value: deleted ? null : op.value, lastOperationId: op.operationId });
          result = { operationId: op.operationId, outcome: deleted ? 'deleted' : 'acknowledged', serverRevision: revision, conflictId: null };
        }
      }
      tx.create(opRef, { fingerprint: fingerprint(op), result });
      results.push(result);
    }
    tx.set(metaRef, { revision }, { merge: true });
  });
  const checkpoint = String((await metaRef.get()).data()?.revision ?? 0);
  return { requestId: body.requestId, results, checkpoint };
}

export function validateRestoreRequest(body) {
  if (!body || !UUID.test(body.requestId ?? '')) throw new Error('request_id_invalid');
  if (body.checkpoint !== null && (typeof body.checkpoint !== 'string' || body.checkpoint.length < 1 || body.checkpoint.length > 256)) {
    throw new Error('checkpoint_invalid');
  }
  return body;
}

export async function restoreAccount(store, uid, rawBody) {
  const body = validateRestoreRequest(rawBody);
  const after = body.checkpoint === null ? 0 : Number(body.checkpoint);
  if (!Number.isInteger(after) || after < 0) throw new Error('checkpoint_invalid');
  const snap = await store.collection('users').doc(uid).collection('syncEntities').get();
  const rows = snap.docs.map(doc => doc.data()).filter(row => !row.deleted && Number(row.revision) > after);
  const grouped = { categories: [], habits: [], occurrences: [], explanations: [], visions: [] };
  for (const row of rows) {
    const key = `${row.value?.id ?? ''}`;
    if (row.value && key) {
      const bucket = row.entity === 'category' ? 'categories' : `${row.entity ?? ''}s`;
      if (bucket in grouped) grouped[bucket].push(row.value);
    }
  }
  const meta = await store.collection('users').doc(uid).collection('sync').doc('meta').get();
  const checkpoint = String(meta.data()?.revision ?? after);
  return { requestId: body.requestId, checkpoint, complete: true, ...grouped };
}
