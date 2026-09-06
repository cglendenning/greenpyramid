import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const pkg = JSON.parse(readFileSync(new URL('../package.json', import.meta.url)));
const indexSource = readFileSync(new URL('../index.js', import.meta.url), 'utf8');

test('D-050: the Anthropic SDK is a direct dependency; no routing/proxy '
  + 'layer package is present', () => {
  assert.ok(pkg.dependencies['@anthropic-ai/sdk'], 'expected @anthropic-ai/sdk as a direct dependency');
  const routingPackages = Object.keys(pkg.dependencies).filter(
    (name) => /openrouter|litellm|portkey/i.test(name),
  );
  assert.deepEqual(routingPackages, []);
});

test('D-050: the Council route imports Anthropic directly, not through a '
  + 'provider-abstraction module', () => {
  assert.match(indexSource, /from ['"]@anthropic-ai\/sdk['"]/);
});
