import { createHash } from 'node:crypto';

function canonical(value) {
  if (Array.isArray(value)) return value.map(canonical);
  if (value && typeof value === 'object') return Object.fromEntries(Object.keys(value).sort().map((key) => [key, canonical(value[key])]));
  return value;
}

/** D-163: one explainable, append-only record for an engine evaluation. */
export function createAuditRecord({ accountUid, event = null, decision, lifecycle = null, safety = null, deliveryState = null, outcome = null, duplicate = false }) {
  if (!accountUid || !decision?.decisionId) throw new Error('audit_input_invalid');
  const record = {
    recordId: decision.decisionId,
    accountUid,
    event,
    decision: {
      decisionId: decision.decisionId,
      type: decision.type,
      target: decision.target,
      objective: decision.objective,
      context: decision.context || null,
      alternatives: decision.policy?.candidates || [],
      selection: decision.policy?.selectedType || decision.type,
      suppression: decision.rationale || null,
    },
    lifecycle,
    safety,
    deliveryState,
    outcome,
    duplicate,
    retained: true,
  };
  return { ...record, fingerprint: createHash('sha256').update(JSON.stringify(canonical(record))).digest('hex') };
}

export function replayAudit(records, { version = 'engine-v1', seed = 0, clock = 'virtual' } = {}) {
  const ordered = [...records].sort((a, b) => String(a.recordId).localeCompare(String(b.recordId)));
  const input = canonical({ version, seed, clock, records: ordered });
  return { fingerprint: createHash('sha256').update(JSON.stringify(input)).digest('hex'), records: ordered };
}

export function buildOperationalMetrics(records) {
  const count = (predicate) => records.filter(predicate).length;
  return {
    evaluations: records.length,
    none: count((record) => record.decision?.type === 'NONE'),
    delivery: count((record) => record.deliveryState === 'sent'),
    expiry: count((record) => record.lifecycle?.status === 'expired'),
    suppression: count((record) => record.lifecycle?.status === 'suppressed' || record.decision?.suppression),
    duplicates: count((record) => record.duplicate === true),
    outcomes: count((record) => record.outcome != null),
    safety: count((record) => record.safety?.action === 'suppress'),
  };
}

