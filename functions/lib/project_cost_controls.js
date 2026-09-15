import { createHash } from 'node:crypto';

export const ALLOWED_PROVIDERS = Object.freeze(['anthropic', 'openai']);
export const ALLOWED_MODELS = Object.freeze([
  'claude-opus-5', 'claude-sonnet-5', 'claude-haiku-4-5',
  'gpt-4o-mini', 'gpt-4.1-mini', 'gpt-4.1-mini-2025-04-14',
]);

export function validateCostConfiguration({ provider, model, functionName, reason, maxOutputTokens, scheduleMinutes }) {
  if (!ALLOWED_PROVIDERS.includes(provider) || !ALLOWED_MODELS.includes(model)) throw new Error('provider_or_model_not_allowlisted');
  if (!functionName || !reason || !Number.isInteger(maxOutputTokens) || maxOutputTokens < 1 || maxOutputTokens > 2000) {
    throw new Error('cost_guard_missing');
  }
  if (scheduleMinutes != null && (!Number.isInteger(scheduleMinutes) || scheduleMinutes < 1 || scheduleMinutes > 60)) {
    throw new Error('schedule_unbounded');
  }
  return true;
}

export function validateScheduleConfig({ intervalMinutes, concurrency, timeoutSeconds, maxOutbound }) {
  if (!Number.isInteger(intervalMinutes) || intervalMinutes < 1 || intervalMinutes > 60 ||
      !Number.isInteger(concurrency) || concurrency < 1 || concurrency > 20 ||
      !Number.isInteger(timeoutSeconds) || timeoutSeconds < 1 || timeoutSeconds > 300 ||
      !Number.isInteger(maxOutbound) || maxOutbound < 1 || maxOutbound > 1000) throw new Error('schedule_unbounded');
  return true;
}

/** D-164: synchronous in-memory equivalent of the server transaction boundary. */
export class ProjectCostLedger {
  constructor({ projectAllowanceUsd = 100, accountAllowanceUsd = 5, killSwitch = false } = {}) {
    this.projectAllowanceUsd = projectAllowanceUsd;
    this.accountAllowanceUsd = accountAllowanceUsd;
    this.killSwitch = killSwitch;
    this.reservations = new Map();
    this.settlements = new Map();
  }

  reserve(request) {
    validateCostConfiguration(request);
    if (this.killSwitch) throw new Error('project_cost_kill_switch');
    const key = request.slotKey
      ? `${request.accountUid}:${request.logicalInterventionId}:${request.slotKey}`
      : request.reservationId;
    if (!request.accountUid || !request.reservationId || !request.maxCostUsd || !request.billingPeriod || !key) throw new Error('reservation_metadata_missing');
    if (this.reservations.has(key) || this.settlements.has(key)) return { reservationId: request.reservationId, outcome: 'duplicate' };
    const projectOutstanding = [...this.reservations.values()].reduce((sum, item) => sum + item.maxCostUsd, 0);
    const accountOutstanding = [...this.reservations.values()].filter((item) => item.accountUid === request.accountUid).reduce((sum, item) => sum + item.maxCostUsd, 0);
    if (projectOutstanding + request.maxCostUsd > this.projectAllowanceUsd || accountOutstanding + request.maxCostUsd > (request.accountAllowanceUsd ?? this.accountAllowanceUsd)) {
      throw new Error('cost_allowance_exceeded');
    }
    const record = { ...request, key, state: 'reserved', actualCostUsd: null };
    this.reservations.set(key, record);
    return { reservationId: request.reservationId, outcome: 'reserved' };
  }

  settle({ reservationId, outcome, actualCostUsd = 0 }) {
    const entry = [...this.reservations.entries()].find(([, value]) => value.reservationId === reservationId);
    if (!entry) return { reservationId, outcome: 'already_settled' };
    const [key, record] = entry;
    this.reservations.delete(key);
    this.settlements.set(key, { ...record, state: 'settled', outcome, actualCostUsd });
    return { reservationId, outcome: 'settled' };
  }

  setKillSwitch(value) { this.killSwitch = value === true; }

  telemetry() {
    const all = [...this.settlements.values()];
    return {
      external: all.reduce((sum, item) => sum + (Number(item.actualCostUsd) || 0), 0),
      firebase: 0,
      byProvider: Object.fromEntries(ALLOWED_PROVIDERS.map((provider) => [provider, all.filter((item) => item.provider === provider).length])),
      byFunction: Object.fromEntries([...new Set(all.map((item) => item.functionName))].map((name) => [name, all.filter((item) => item.functionName === name).length])),
    };
  }
}

export function scheduleSlotKey({ accountUid, logicalInterventionId, timezone, occurrenceDate, slot }) {
  if (!accountUid || !logicalInterventionId || !timezone || !occurrenceDate || !slot) throw new Error('schedule_slot_invalid');
  return createHash('sha256').update(`${accountUid}:${logicalInterventionId}:${timezone}:${occurrenceDate}:${slot}`).digest('hex');
}

