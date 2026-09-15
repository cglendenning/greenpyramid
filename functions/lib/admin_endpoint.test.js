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
