import { GoogleAuth } from 'google-auth-library';

const CLOUD_PLATFORM_SCOPE = 'https://www.googleapis.com/auth/cloud-platform.read-only';
const DEFAULT_TIMEOUT_MS = 5000;

function projectIdFromEnvironment() {
  return process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT || null;
}

function errorCodeFromResponse(payload, status) {
  const reason = payload?.error?.details?.find?.((detail) => detail['@type']?.endsWith('ErrorInfo'))?.reason;
  if (reason === 'SERVICE_DISABLED') return 'api_disabled';
  if (status === 401) return 'authentication_required';
  if (status === 403) return 'permission_denied';
  if (status === 429) return 'quota_exhausted';
  if (status >= 500) return 'service_unavailable';
  return reason || `http_${status}`;
}

export function classifyPlatformHealthError(error) {
  const status = Number(error?.status || error?.response?.status || 0);
  const reason = error?.reason || error?.code || error?.message || '';
  if (/SERVICE_DISABLED|api.?disabled/i.test(String(reason))) return 'api_disabled';
  if (/quota|resource.?exhausted|rate.?limit/i.test(String(reason)) || status === 429) return 'quota_exhausted';
  if (/permission|forbidden|access.?denied/i.test(String(reason)) || status === 403) return 'permission_denied';
  if (/auth|credential|token/i.test(String(reason)) || status === 401) return 'authentication_required';
  return status >= 500 ? 'service_unavailable' : 'unknown';
}

async function fetchJson(fetcher, url, accessToken, { signal } = {}) {
  const response = await fetcher(url, {
    method: 'GET',
    headers: { Authorization: `Bearer ${accessToken}` },
    signal,
  });
  let payload = null;
  try { payload = await response.json(); } catch { /* preserve the HTTP status below */ }
  if (!response.ok) {
    const error = new Error(payload?.error?.message || `Google API returned ${response.status}`);
    error.status = response.status;
    error.reason = payload?.error?.details?.find?.((detail) => detail['@type']?.endsWith('ErrorInfo'))?.reason;
    throw error;
  }
  return payload || {};
}

function unknownCheck(error) {
  return { state: 'unknown', reason: classifyPlatformHealthError(error) };
}

function billingCheck(payload) {
  const enabled = payload?.billingEnabled === true;
  return {
    state: enabled ? 'enabled' : 'disabled',
    billingEnabled: enabled,
    billingAccount: payload?.billingAccountName || null,
  };
}

function budgetCheck(payload) {
  const budgets = Array.isArray(payload?.budgets) ? payload.budgets : [];
  return {
    state: 'available',
    count: budgets.length,
    budgets: budgets.slice(0, 20).map((budget) => ({
      name: budget.displayName || budget.name?.split('/').pop() || 'Unnamed budget',
      thresholds: (budget.thresholdRules || [])
        .map((rule) => Number(rule.thresholdPercent))
        .filter(Number.isFinite),
    })),
  };
}

function functionCheck(payload) {
  const functions = Array.isArray(payload?.functions) ? payload.functions : [];
  const entries = functions.slice(0, 50).map((fn) => ({
    name: fn.name?.split('/').pop() || 'unknown',
    state: fn.state || 'UNKNOWN',
    region: fn.name?.split('/')[3] || null,
  }));
  const unhealthy = entries.filter((fn) => fn.state !== 'ACTIVE');
  return {
    state: functions.length > 0 && unhealthy.length === 0 ? 'healthy' : functions.length > 0 ? 'attention' : 'unknown',
    count: functions.length,
    functions: entries,
  };
}

/**
 * D-164: best-effort operator diagnostic for Google Cloud billing visibility
 * and the deployed Functions surface. It never changes billing, budgets, IAM,
 * quotas, or runtime configuration. A missing Billing Budgets API or a
 * service-account permission is reported as unknown rather than as "no budget".
 */
export async function getPlatformHealth({
  projectId = projectIdFromEnvironment(),
  auth = new GoogleAuth({ scopes: [CLOUD_PLATFORM_SCOPE] }),
  fetcher = globalThis.fetch,
  timeoutMs = DEFAULT_TIMEOUT_MS,
} = {}) {
  if (!projectId) {
    return {
      state: 'unknown',
      projectId: null,
      checkedAt: new Date().toISOString(),
      billing: { state: 'unknown', reason: 'project_id_missing' },
      budgets: { state: 'unknown', reason: 'project_id_missing' },
      functions: { state: 'unknown', reason: 'project_id_missing' },
    };
  }
  if (typeof fetcher !== 'function') throw new TypeError('fetcher must be a function');

  let accessToken;
  try {
    const client = await auth.getClient();
    const token = await client.getAccessToken();
    accessToken = typeof token === 'string' ? token : token?.token;
    if (!accessToken) throw new Error('missing_access_token');
  } catch (error) {
    const result = {
      state: 'unknown',
      projectId,
      checkedAt: new Date().toISOString(),
      billing: unknownCheck(error),
      budgets: unknownCheck(error),
      functions: unknownCheck(error),
    };
    return result;
  }

  const call = (url) => {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    return fetchJson(fetcher, url, accessToken, { signal: controller.signal })
      .finally(() => clearTimeout(timer));
  };
  const billingUrl = `https://cloudbilling.googleapis.com/v1/projects/${encodeURIComponent(projectId)}/billingInfo`;
  const functionsUrl = `https://cloudfunctions.googleapis.com/v2/projects/${encodeURIComponent(projectId)}/locations/-/functions?pageSize=100`;

  const [billingResult, functionsResult] = await Promise.allSettled([call(billingUrl), call(functionsUrl)]);
  const billing = billingResult.status === 'fulfilled' ? billingCheck(billingResult.value) : unknownCheck(billingResult.reason);
  const functions = functionsResult.status === 'fulfilled' ? functionCheck(functionsResult.value) : unknownCheck(functionsResult.reason);

  let budgets = { state: 'not_checked', reason: 'billing_account_unavailable' };
  if (billing.state === 'enabled' && billing.billingAccount) {
    const accountId = billing.billingAccount.split('/').pop();
    try {
      budgets = budgetCheck(await call(`https://billingbudgets.googleapis.com/v1/billingAccounts/${encodeURIComponent(accountId)}/budgets?pageSize=20`));
    } catch (error) {
      budgets = unknownCheck(error);
    }
  }

  const state = billing.state === 'disabled' || functions.state === 'attention'
    ? 'attention'
    : billing.state === 'enabled' && functions.state === 'healthy'
      ? 'healthy'
      : 'unknown';
  return { state, projectId, checkedAt: new Date().toISOString(), billing, budgets, functions };
}

export { errorCodeFromResponse };
