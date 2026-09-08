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

test('D-097: /boardAdvisorTurn routes to the solo-Mira handler on '
  + 'soloSetup, never on isSetup — regression test for a defect found '
  + 'live: isSetup means "billed free" (D-017) and is true for every '
  + 'call inside a setup-typed session, including essence-deepening\'s '
  + 'four-advisor rotation; routing on it instead of a dedicated signal '
  + 'silently sent essence-deepening through the solo-Mira pyramid-'
  + 'building logic, ignoring the advisor and category it was actually '
  + 'meant to address', () => {
  const routeStart = indexSource.indexOf("app.post('/boardAdvisorTurn'");
  assert.ok(routeStart > -1, 'expected the /boardAdvisorTurn route to exist');
  const routeEnd = indexSource.indexOf('\napp.post(', routeStart + 1);
  const route = indexSource.substring(routeStart, routeEnd === -1 ? undefined : routeEnd);

  assert.match(route, /if\s*\(\s*soloSetup\s*\)\s*return\s+handleSetupAdvisorTurn/,
      'the solo-Mira handler must be gated on soloSetup');
  assert.doesNotMatch(route, /if\s*\(\s*isSetup\s*\)\s*return\s+handleSetupAdvisorTurn/,
      'must not route to the solo-Mira handler on isSetup — that flag only means "billed free"');
});

test('D-100: /boardAdvisorTurn computes nudgeConvergence from the general '
  + 'Council conversation\'s own turn count and passes it into the prompt '
  + 'builder — never a hardcoded true/false', () => {
  const routeStart = indexSource.indexOf("app.post('/boardAdvisorTurn'");
  const routeEnd = indexSource.indexOf('\napp.post(', routeStart + 1);
  const route = indexSource.substring(routeStart, routeEnd);

  assert.match(route, /nudgeConvergence:\s*countMiraTurns\(conversationHistory\)\s*>=/);
});

test('D-100: /deriveDomainFindings branches to the general (whole-pyramid) '
  + 'prompt and tool only when pyramidContext is present, leaving the '
  + 'existing single-category path untouched', () => {
  const routeStart = indexSource.indexOf("app.post('/deriveDomainFindings'");
  assert.ok(routeStart > -1, 'expected the /deriveDomainFindings route to exist');
  const routeEnd = indexSource.indexOf('\napp.post(', routeStart + 1);
  const route = indexSource.substring(routeStart, routeEnd);

  assert.match(route, /Array\.isArray\(pyramidContext\)/);
  assert.match(route, /buildDeriveGeneralDomainFindingsPrompt/);
  assert.match(route, /GENERAL_DOMAIN_FINDING_TOOL/);
  assert.match(route, /buildDeriveDomainFindingsPrompt/);
  assert.match(route, /DOMAIN_FINDING_TOOL/);
});
