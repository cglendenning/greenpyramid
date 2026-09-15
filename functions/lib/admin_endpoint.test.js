import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

test('D-165 admin endpoint is claim-gated and reads aggregate sources', () => {
  // D-165-AC-02
  const source = fs.readFileSync(new URL('../index.js', import.meta.url), 'utf8');
  assert.match(source, /decoded\.admin !== true/);
  assert.match(source, /app\.get\('\/adminMetrics', requireAdmin/);
  assert.match(source, /collectionGroup\('profile'\)/);
  assert.match(source, /collectionGroup\('telemetry'\)/);
  assert.match(source, /buildAdminMetrics/);
});

test('D-162/D-165 admin simulation fixes the sandbox and bounds client options', () => {
  const source = fs.readFileSync(new URL('../index.js', import.meta.url), 'utf8');
  assert.match(source, /app\.post\('\/adminSimulation', requireAdmin/);
  assert.match(source, /projectId: 'greenpyramid-sandbox'/);
  assert.match(source, /months > 6/);
  assert.match(source, /simulation_options_invalid/);
});
