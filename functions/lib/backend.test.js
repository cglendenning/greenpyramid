import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const pkg = JSON.parse(readFileSync(new URL('../package.json', import.meta.url)));
const indexSource = readFileSync(new URL('../index.js', import.meta.url), 'utf8');

test('D-030/D-014/D-016: retired OpenAI proxy has no route, SDK, or server secret', () => {
  assert.equal(pkg.dependencies.openai, undefined);
  assert.doesNotMatch(indexSource, /from ['"]openai['"]/);
  assert.doesNotMatch(indexSource, /OPENAI_API_KEY|sOpenAI/);
  assert.doesNotMatch(indexSource, /app\.post\(['"]\/v1\/chat\/completions/);
});

test('D-037: the Anthropic SDK is a direct dependency; no routing/proxy '
  + 'layer package is present', () => {
  assert.ok(pkg.dependencies['@anthropic-ai/sdk'], 'expected @anthropic-ai/sdk as a direct dependency');
  const routingPackages = Object.keys(pkg.dependencies).filter(
    (name) => /openrouter|litellm|portkey/i.test(name),
  );
  assert.deepEqual(routingPackages, []);
});

test('D-037: the Council route imports Anthropic directly, not through a '
  + 'provider-abstraction module', () => {
  assert.match(indexSource, /from ['"]@anthropic-ai\/sdk['"]/);
});

test('D-080: /boardAdvisorTurn routes to the solo-Mira handler on '
  + 'soloSetup, never on isSetup — regression test for a defect found '
  + 'live: isSetup means "billed free" (D-015) and is true for every '
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

test('D-080/D-146: non-setup mode reserves server-priced spend before provider dispatch and cannot use client setup flags as authority', () => {
  const guardStart = indexSource.indexOf('async function guardCouncilCall');
  const guardEnd = indexSource.indexOf('async function settleReservedCost');
  const guard = indexSource.substring(guardStart, guardEnd);
  assert.match(guard, /requireEntitlement/);
  assert.match(guard, /reserveCost\(/);
  assert.doesNotMatch(guard, /req\.body\?\.isSetup/);
  assert.match(indexSource, /await settleReservedCost\(req, model, msg\.usage\)/);
});

test('D-146: ambiguous provider failures retain reservations for reconciliation, '
  + 'while confirmed pre-billing 4xx rejections release them', () => {
  assert.match(indexSource, /function isConfirmedPreBillingRejection\(error\)/);
  assert.match(indexSource, /status !== 429/);
  assert.match(indexSource, /if \(!isSetup && isConfirmedPreBillingRejection\(e\)\)/);
  assert.match(indexSource, /if \(isConfirmedPreBillingRejection\(e\)\)/);
});

test('D-082: /boardAdvisorTurn computes nudgeConvergence from the general '
  + 'Council conversation\'s own turn count and passes it into the prompt '
  + 'builder — never a hardcoded true/false', () => {
  const routeStart = indexSource.indexOf("app.post('/boardAdvisorTurn'");
  const routeEnd = indexSource.indexOf('\napp.post(', routeStart + 1);
  const route = indexSource.substring(routeStart, routeEnd);

  assert.match(route, /nudgeConvergence:\s*countMiraTurns\(conversationHistory\)\s*>=/);
});

test('D-150: general Council replies have enough bounded output budget to '
  + 'finish a conversational response instead of ending mid-sentence', () => {
  const routeStart = indexSource.indexOf("app.post('/boardAdvisorTurn'");
  const routeEnd = indexSource.indexOf('\napp.post(', routeStart + 1);
  const route = indexSource.substring(routeStart, routeEnd);
  assert.match(route, /GENERAL_COUNCIL_MAX_OUTPUT_TOKENS\s*=\s*320/);
  assert.match(route, /max_tokens:\s*GENERAL_COUNCIL_MAX_OUTPUT_TOKENS/);
  assert.doesNotMatch(route, /max_tokens:\s*120\b/);
});

test('D-089: /deriveVisionStatement reads isSetup from the caller instead '
  + 'of hardcoding true — profile.dart\'s regeneration must go through '
  + 'D-014\'s entitlement gate like every other non-setup AI surface, '
  + 'not setup\'s free/bounded one', () => {
  const routeStart = indexSource.indexOf("app.post('/deriveVisionStatement'");
  assert.ok(routeStart > -1, 'expected the /deriveVisionStatement route to exist');
  const routeEnd = indexSource.indexOf('\napp.post(', routeStart + 1);
  const route = indexSource.substring(routeStart, routeEnd);

  assert.doesNotMatch(route, /isSetup:\s*true\s*,\s*sessionId/,
    'must not hardcode isSetup: true anymore');
  assert.match(route, /isSetup:\s*!!isSetup/);
});

test('D-089: /deriveProgressAnalysis exists, is gated the same way every '
  + 'other non-setup AI surface is (D-014), and records its cost — it is '
  + 'never free, since it is never setup', () => {
  const routeStart = indexSource.indexOf("app.post('/deriveProgressAnalysis'");
  assert.ok(routeStart > -1, 'expected the /deriveProgressAnalysis route to exist');
  const routeEnd = indexSource.indexOf('\napp.post(', routeStart + 1);
  const route = routeStart > -1
    ? indexSource.substring(routeStart, routeEnd === -1 ? indexSource.length : routeEnd)
    : '';

  assert.match(route, /guardCouncilCall\(req, res, \{ isSetup: false \}\)/);
  assert.match(route, /buildProgressAnalysisPrompt/);
  assert.match(route, /settleReservedCost\(/);
});

test('D-093/D-094: handleSetupAdvisorTurn appends the wrap-up question '
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

test('D-094: once the wrap-up question already appears in history, the '
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

test('D-095: mustWrapUpNow is computed from turnsSoFar >= 3 and forces '
  + 'the wrap-up append the same way an already-ready model decision '
  + 'does — regression test for the owner\'s report that multiple '
  + '"almost there"/"not much further to go" reassurances in a row felt '
  + 'like being dragged along', () => {
  const start = indexSource.indexOf('async function handleSetupAdvisorTurn');
  const end = indexSource.indexOf('\n}\n', start);
  const body = indexSource.substring(start, end === -1 ? indexSource.length : end);

  assert.match(body, /mustWrapUpNow\s*=\s*!existingCategories\s*&&\s*!wrapUpAlreadyAsked\s*&&\s*turnsSoFar\s*>=\s*3/);
  assert.match(body, /readyToBuild \|\| mustWrapUpNow/);
});
