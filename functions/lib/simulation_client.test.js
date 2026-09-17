import test from 'node:test';
import assert from 'node:assert/strict';
import { requestSimulation } from './simulation_client.js';

test('D-162-AC-05: CLI transport sends the admin app request shape to one protected endpoint', async () => {
  let request;
  const report = {
    virtualMonths: 1,
    selectedTypes: { NONE: 1, REMINDER: 0 },
    scenarios: [{ name: 'autonomous', metrics: { selectedTypes: { NONE: 1 } } }],
  };
  const result = await requestSimulation({
    endpoint: 'http://localhost:5001/api/adminSimulation',
    token: 'admin-token',
    months: 1,
    seed: 11,
    scenarios: ['autonomous'],
    failureMode: 'none',
    fetchImpl: async (url, options) => {
      request = { url, options };
      return { ok: true, status: 200, json: async () => report };
    },
  });
  assert.deepEqual(result, report);
  assert.deepEqual(result.selectedTypes, { NONE: 1, REMINDER: 0 });
  assert.deepEqual(result.scenarios[0].metrics.selectedTypes, { NONE: 1 });
  assert.equal(request.url, 'http://localhost:5001/api/adminSimulation');
  assert.equal(request.options.method, 'POST');
  assert.equal(request.options.headers.Authorization, 'Bearer admin-token');
  assert.deepEqual(JSON.parse(request.options.body), {
    months: 1, seed: 11, scenarios: ['autonomous'], failureMode: 'none',
  });
});

test('D-162-AC-05: CLI transport never proceeds without an admin token', async () => {
  await assert.rejects(() => requestSimulation({ fetchImpl: async () => ({}) }), /admin_token_required/);
});
