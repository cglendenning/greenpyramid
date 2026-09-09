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

test('D-114: /deriveVisionStatement reads isSetup from the caller instead '
  + 'of hardcoding true — profile.dart\'s regeneration must go through '
  + 'D-016\'s entitlement gate like every other non-setup AI surface, '
  + 'not setup\'s free/bounded one', () => {
  const routeStart = indexSource.indexOf("app.post('/deriveVisionStatement'");
  assert.ok(routeStart > -1, 'expected the /deriveVisionStatement route to exist');
  const routeEnd = indexSource.indexOf('\napp.post(', routeStart + 1);
  const route = indexSource.substring(routeStart, routeEnd);

  assert.doesNotMatch(route, /isSetup:\s*true\s*,\s*sessionId/,
    'must not hardcode isSetup: true anymore');
  assert.match(route, /isSetup:\s*!!isSetup/);
});

test('D-114: /deriveProgressAnalysis exists, is gated the same way every '
  + 'other non-setup AI surface is (D-016), and records its cost — it is '
  + 'never free, since it is never setup', () => {
  const routeStart = indexSource.indexOf("app.post('/deriveProgressAnalysis'");
  assert.ok(routeStart > -1, 'expected the /deriveProgressAnalysis route to exist');
  const routeEnd = indexSource.indexOf('\napp.post(', routeStart + 1);
  const route = routeStart > -1
    ? indexSource.substring(routeStart, routeEnd === -1 ? indexSource.length : routeEnd)
    : '';

  assert.match(route, /guardCouncilCall\(req, res, \{ isSetup: false \}\)/);
  assert.match(route, /buildProgressAnalysisPrompt/);
  assert.match(route, /recordCost\(/);
});

test('D-118/D-119: handleSetupAdvisorTurn appends the wrap-up question '
  + 'only for the non-refining conversation, the first time it becomes '
  + 'ready — the refinement loop must never be intercepted', () => {
    const start = indexSource.indexOf('async function handleSetupAdvisorTurn');
    assert.ok(start > -1, 'expected handleSetupAdvisorTurn to exist');
    const end = indexSource.indexOf('\n}\n', start);
    const body = indexSource.substring(start, end === -1 ? indexSource.length : end);

    assert.match(body, /!existingCategories/);
    assert.match(body, /SETUP_WRAP_UP_QUESTION/);
    assert.match(body, /readyToBuild\s*=\s*false/);
  });

test('D-119: once the wrap-up question already appears in history, the '
  + 'very next turn forces readyToBuild true deterministically — never '
  + 'left to the model\'s own judgment that turn. Regression test for a '
  + 'defect found live: "when I responded, then Mira dropped straight '
  + 'back into yet another question" instead of closing', () => {
  const start = indexSource.indexOf('async function handleSetupAdvisorTurn');
  const end = indexSource.indexOf('\n}\n', start);
  const body = indexSource.substring(start, end === -1 ? indexSource.length : end);

  const wrapUpIdx = body.indexOf('wrapUpAlreadyAsked');
  assert.ok(wrapUpIdx > -1, 'expected a wrapUpAlreadyAsked computation');
  assert.match(body, /hasAskedWrapUpQuestion\(conversationHistory\)/);

  const ifIdx = body.indexOf('if (wrapUpAlreadyAsked)');
  assert.ok(ifIdx > -1);
  const forcedTrueIdx = body.indexOf('readyToBuild = true', ifIdx);
  assert.ok(forcedTrueIdx > ifIdx && forcedTrueIdx < ifIdx + 60,
    'readyToBuild = true must be forced immediately inside the wrapUpAlreadyAsked branch');
});
