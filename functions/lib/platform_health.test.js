import test from 'node:test';
import assert from 'node:assert/strict';
import { classifyPlatformHealthError, getPlatformHealth } from './platform_health.js';

// D-165-AC-07: the admin-facing diagnostic stays claim-gated at the route and
// distinguishes platform state from application/provider spend controls.

test('D-164-AC-06: platform health never treats a disabled budget API as no budget', async () => {
  const calls = [];
  const result = await getPlatformHealth({
    projectId: 'life-ops',
    auth: { getClient: async () => ({ getAccessToken: async () => 'token' }) },
    fetcher: async (url) => {
      calls.push(url);
      if (url.includes('cloudbilling')) {
        return new Response(JSON.stringify({ billingEnabled: true, billingAccountName: 'billingAccounts/abc' }), { status: 200 });
      }
      if (url.includes('cloudfunctions')) {
        return new Response(JSON.stringify({ functions: [{ name: 'projects/life-ops/locations/us-central1/functions/api', state: 'ACTIVE' }] }), { status: 200 });
      }
      return new Response(JSON.stringify({ error: { details: [{ '@type': 'type.googleapis.com/google.rpc.ErrorInfo', reason: 'SERVICE_DISABLED' }] } }), { status: 403 });
    },
  });
  assert.equal(result.state, 'healthy');
  assert.equal(result.billing.state, 'enabled');
  assert.deepEqual(result.budgets, { state: 'unknown', reason: 'api_disabled' });
  assert.equal(calls.length, 3);
});

test('D-164-AC-06: platform health reports permission and quota failures distinctly', () => {
  assert.equal(classifyPlatformHealthError({ status: 403, reason: 'PERMISSION_DENIED' }), 'permission_denied');
  assert.equal(classifyPlatformHealthError({ status: 429 }), 'quota_exhausted');
  assert.equal(classifyPlatformHealthError({ reason: 'SERVICE_DISABLED' }), 'api_disabled');
});
