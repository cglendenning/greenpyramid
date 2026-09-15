// Green Pyramid backend — the OpenAI key lives ONLY here, in Firebase Secret
// Manager, and is injected at runtime. It is never shipped in the app binary.
// The app calls this function as an OpenAI-compatible proxy: same request body
// it would send to api.openai.com, but authenticated with a Firebase App Check
// token (proves the request came from the genuine app) and an anonymous
// Firebase ID token (proves an app-minted identity). Mirrors the goal-executor
// backend, plus App Check.
import { setupIdempotency } from './lib/setup_idempotency.js';
import { completeSetup } from './lib/setup_completion.js';
import { onRequest } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { setGlobalOptions } from 'firebase-functions/v2';
import { defineSecret } from 'firebase-functions/params';
import express from 'express';
import cors from 'cors';
import OpenAI from 'openai';
import Anthropic from '@anthropic-ai/sdk';
import admin from 'firebase-admin';
import { randomUUID, createHash } from 'node:crypto';
import { applyPacingReassurance, buildAdvisorTurnPrompt, buildGeneralCouncilTurnPrompt, buildSetupAdvisorTurnPrompt, countMiraTurns, extractReplyText, hasAskedWrapUpQuestion, SETUP_TURN_TOOL, SETUP_WRAP_UP_QUESTION } from './lib/council.js';
import { checkSpendLimit, recordCost, reserveCost, settleCost, releaseCost, SpendLimitError } from './lib/billing.js';
import { guardCallFrequency, RateLimitError } from './lib/rate_limit.js';
import { getCouncilModel, getNotificationModel } from './lib/model_config.js';
import { guardAndCountSetupCall, SetupCallLimitError } from './lib/setup_guard.js';
import { buildDeriveCategoriesPrompt, buildDeriveHabitsPrompt, buildVisionStatementPrompt, CATEGORIES_TOOL, habitsTool } from './lib/setup_derivation.js';
import { buildProgressAnalysisPrompt } from './lib/progress_analysis.js';
import { buildNewsfeedAnalysisPrompt, parseArticleReply } from './lib/newsfeed_analysis.js';
import { isEligibleForTailoredNotification } from './lib/notification_schedule.js';
import { shouldSendBatchCheckin, todaysScheduledHabits, localDateParts } from './lib/batch_checkin_schedule.js';
import { buildNotificationPrompt, NOTIFICATION_TOOL } from './lib/notification_derivation.js';
import { requireEntitlement, EntitlementRequiredError } from './lib/entitlement.js';
import { grantTrialIfEligible, grantMigrationTrial, DeviceTrialError } from './lib/device_trial.js';
import { applyRevenueCatEvent, verifyWebhookAuth } from './lib/revenuecat_webhook.js';
import { buildAdminMetrics } from './lib/admin_metrics.js';
import { applySyncRequest, restoreAccount } from './lib/sync_operations.js';
import { cleanupAnonymousAccounts } from './lib/anonymous_cleanup.js';
import { claimNotificationDispatch, markInboxRead, notificationMessageKey, registerInstallation } from './lib/notification_delivery.js';

// Stored in Firebase Secret Manager (firebase functions:secrets:set
// OPENAI_API_KEY / ANTHROPIC_API_KEY), never in source. OpenAI backs the
// legacy coach/commentary surfaces until D-066 (R6) retires them; Anthropic
// backs the Council (D-030, D-037).
const sOpenAI = defineSecret('OPENAI_API_KEY');
const sAnthropic = defineSecret('ANTHROPIC_API_KEY');
// D-045: Apple DeviceCheck signing key (.p8, PEM). D-054: RevenueCat's
// webhook shared-secret string, configured identically in the RevenueCat
// dashboard's webhook "Authorization header" field.
const sDeviceCheckKey = defineSecret('DEVICECHECK_PRIVATE_KEY');
const sRevenueCatWebhookSecret = defineSecret('REVENUECAT_WEBHOOK_SECRET');

setGlobalOptions({ region: 'us-central1' });

let adminInitialised = false;
function ensureAdmin() {
  if (!adminInitialised) {
    admin.initializeApp();
    adminInitialised = true;
  }
}

// App Check: proves the request came from the genuine, unmodified app binary
// (App Attest on iOS, Play Integrity on Android). This is the sole gate — the
// app has no user accounts, so there is no user identity to verify; App Check
// is what stops non-app callers from reaching the proxy.
async function requireAppCheck(req, res, next) {
  const token = req.header('X-Firebase-AppCheck');
  if (!token) return res.status(401).json({ error: 'Missing App Check token' });
  try {
    ensureAdmin();
    await admin.appCheck().verifyToken(token);
    next();
  } catch {
    res.status(401).json({ error: 'Invalid App Check token' });
  }
}

// D-061: verifies a Firebase ID token passed as "Authorization: Bearer
// <token>" and sets req.uid. Separate from App Check (which proves the
// binary, not the account) — the spend cap is per-account, so the backend
// needs to know which account to charge before it can enforce one.
async function requireFirebaseAuth(req, res, next) {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing Authorization header' });
  }
  try {
    ensureAdmin();
    const decoded = await admin.auth().verifyIdToken(header.slice(7));
    req.uid = decoded.uid;
    next();
  } catch {
    res.status(401).json({ error: 'Invalid or expired ID token' });
  }
}

// D-165: the private admin app is authorized by a Firebase custom claim,
// never by a client flag, route obscurity, or an email string in the request.
async function requireAdmin(req, res, next) {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) return res.status(401).json({ error: 'authentication_required' });
  try {
    ensureAdmin();
    const decoded = await admin.auth().verifyIdToken(header.slice(7));
    if (decoded.admin !== true) return res.status(403).json({ error: 'admin_required' });
    req.uid = decoded.uid;
    next();
  } catch (error) {
    console.error('admin auth verification failed:', error?.code, error?.message);
    res.status(401).json({ error: 'authentication_required' });
  }
}

// Server-side spend guardrails, enforced regardless of what the client sends:
// only the app's cheap mini models are permitted, and output tokens are hard
// capped. This is the backstop the client can't bypass.
const ALLOWED_MODELS = new Set([
  'gpt-4o-mini',
  'gpt-4.1-mini',
  'gpt-4.1-mini-2025-04-14',
]);
const MAX_OUTPUT_TOKENS = 500;

const app = express();
app.use(cors());
app.use(express.json({ limit: '256kb' }));

app.get('/health', (_req, res) => res.json({ ok: true }));

// D-165: read-only aggregate endpoint for the separate OTA admin app. It is
// intentionally before the consumer App Check gate: the admin bundle has its
// own distribution and relies on Firebase Auth plus the custom claim.
app.get('/adminMetrics', requireAdmin, async (_req, res) => {
  try {
    const store = admin.firestore();
    const profileSnap = await store.collectionGroup('profile').get();
    const profiles = profileSnap.docs.map((doc) => {
      const uid = doc.ref.path.split('/')[1];
      return {
        uidHash: createHash('sha256').update(uid).digest('hex'),
        totalSpendUsd: doc.data()?.totalSpendUsd,
        aiCalls: doc.data()?.aiCalls,
        entitlement: doc.data()?.entitlement,
        setupComplete: doc.data()?.setupComplete,
      };
    });
    const telemetrySnap = await store.collectionGroup('telemetry').get();
    const telemetry = telemetrySnap.docs.map((doc) => {
      const data = doc.data() || {};
      return { eventName: data.eventName, screenKey: data.screenKey, uidHash: data.uidHash };
    });
    res.json(buildAdminMetrics({ profiles, telemetry }));
  } catch (e) {
    console.error('adminMetrics error:', e.message);
    res.status(500).json({ error: 'service_unavailable' });
  }
});

// D-054: RevenueCat calls this directly from its own servers — never through
// the app, so it carries no App Check token and must sit before that gate.
// Auth is the shared-secret header check above, not App Check or Firebase
// Auth. Always responds quickly so RevenueCat doesn't retry-storm on a slow
// Firestore write; entitlement changes are the only side effect.
app.post('/revenuecatWebhook', async (req, res) => {
  if (!verifyWebhookAuth(req.header('Authorization'), sRevenueCatWebhookSecret.value())) {
    return res.status(401).json({ error: 'invalid_webhook_auth' });
  }
  try {
    ensureAdmin();
    const event = req.body?.event;
    const applied = await applyRevenueCatEvent(event, admin.firestore());
    // D-135: the only visibility into which entitlement transition (or
    // none) a given webhook call actually produced — found live, the
    // hard way, while diagnosing a report of the generate-analysis
    // button failing right after a subscribe: three webhook calls all
    // returned 200 around the same time, and there was no way to tell
    // from logs alone whether any of them had actually granted
    // 'subscribed', or were all no-op event types.
    console.log('revenuecatWebhook applied:', event?.type, '->', applied);
    res.json({ ok: true });
  } catch (e) {
    // D-135: found live — this used to still respond 200 on a genuine
    // Firestore write failure, which tells RevenueCat "handled" and it
    // never retries — a failed entitlement update was silently invisible,
    // discoverable only by grepping this log line, which nobody was
    // watching. A real internal error now gets a 500 so RevenueCat's own
    // retry logic (it retries on 5xx) gets a chance to actually apply the
    // event later; only e.message is logged, never the event body itself.
    console.error('revenuecatWebhook error:', e.message);
    res.status(500).json({ ok: false });
  }
});

app.use(requireAppCheck);

// D-147: all durable writes go through authenticated, transactional operation
// processing.  The uid is taken from the verified token, never the payload.
app.post('/syncOperations', requireFirebaseAuth, async (req, res) => {
  try {
    ensureAdmin();
    res.json(await applySyncRequest(admin.firestore(), req.uid, req.body));
  } catch (e) {
    const status = /invalid|conflict/.test(e.message) ? 400 : 500;
    console.error('syncOperations error:', e.message);
    res.status(status).json({ error: e.message === 'operation_payload_conflict' ? e.message : status === 500 ? 'service_unavailable' : e.message });
  }
});

app.post('/restoreAccount', requireFirebaseAuth, async (req, res) => {
  try {
    ensureAdmin();
    res.json(await restoreAccount(admin.firestore(), req.uid, req.body));
  } catch (e) {
    const status = /invalid/.test(e.message) ? 400 : 500;
    console.error('restoreAccount error:', e.message);
    res.status(status).json({ error: status === 500 ? 'service_unavailable' : e.message });
  }
});

// OpenAI-compatible chat-completions passthrough: the app sends the same body
// it would send to OpenAI; we attach the real key here and forward.
app.post('/v1/chat/completions', async (req, res) => {
  try {
    const body = req.body || {};
    if (!ALLOWED_MODELS.has(body.model)) {
      return res.status(400).json({ error: `Model not allowed: ${body.model}` });
    }
    if (!Array.isArray(body.messages) || body.messages.length === 0) {
      return res.status(400).json({ error: 'messages required' });
    }
    const client = new OpenAI({ apiKey: sOpenAI.value() });
    const completion = await client.chat.completions.create({
      model: body.model,
      messages: body.messages,
      max_tokens: Math.min(body.max_tokens || MAX_OUTPUT_TOKENS, MAX_OUTPUT_TOKENS),
      temperature: body.temperature,
      top_p: body.top_p,
    });
    res.json(completion);
  } catch (e) {
    console.error('chat proxy error:', e.message);
    res.status(502).json({ error: e.message });
  }
});

// ── The Council of Advisors (D-022/D-145/D-030/D-037) ──────────────────────
// Prompt-building logic lives in lib/council.js so it's testable without
// spinning up Express or Firebase Admin (node --test lib/*.test.js).

let anthropicClient;
function claude() {
  if (!anthropicClient) anthropicClient = new Anthropic({ apiKey: sAnthropic.value() });
  return anthropicClient;
}

// D-015/D-148: setup is free — bounded by a 40-model-call count per
// session, never by the D-061 dollar cap. Every other Council use (D-014)
// is gated by spend instead. Shared by every setup-conversation route
// (turns and the two derivation endpoints below) so the bound is uniform
// regardless of which kind of call it is.
async function guardCouncilCall(req, res, { isSetup, sessionId }) {
  try {
    await guardCallFrequency(req.uid);
  } catch (e) {
    if (e instanceof RateLimitError) {
      res.status(429).json({ error: 'rate_limited', scope: e.scope, limit: e.limit });
      return false;
    }
    throw e;
  }
  if (isSetup) {
    try {
      await guardAndCountSetupCall(req.uid, sessionId);
      return true;
    } catch (e) {
      if (e instanceof SetupCallLimitError) {
        res.status(409).json({ error: 'setup_call_limit_exceeded', count: e.count });
        return false;
      }
      throw e;
    }
  }
  // D-014: every non-setup AI surface requires an active trial or
  // subscription. Checked before the spend cap — an unentitled account
  // should never even reach that check.
  try {
    await requireEntitlement(req.uid);
  } catch (e) {
    if (e instanceof EntitlementRequiredError) {
      res.status(402).json({ error: 'entitlement_required', entitlement: e.entitlement });
      return false;
    }
    throw e;
  }
  try {
    // D-146: reserve before dispatch. The model and bound are server-owned;
    // client mode flags never decide whether work is free.
    const model = await getCouncilModel();
    const reservationId = req.body?.requestId || randomUUID();
    await reserveCost(req.uid, model, 4000, 400, reservationId);
    req.spendReservation = { reservationId, model };
    return true;
  } catch (e) {
    if (e instanceof SpendLimitError) {
      res.status(402).json({
        error: 'spend_limit_exceeded',
        totalSpendUsd: e.totalSpendUsd,
        spendCapUsd: e.spendCapUsd,
      });
      return false;
    }
    throw e;
  }
}

async function settleReservedCost(req, model, usage) {
  const reservation = req.spendReservation;
  if (!reservation) return;
  await settleCost(req.uid, reservation.reservationId, model,
    usage?.input_tokens ?? 0, usage?.output_tokens ?? 0);
  req.spendReservation = null;
}

async function releaseReservedCost(req) {
  const reservation = req.spendReservation;
  if (!reservation) return;
  await releaseCost(req.uid, reservation.reservationId);
  req.spendReservation = null;
}

// D-146: a timeout or provider 5xx does not prove that the provider rejected
// the request before doing billable work. Keep that reservation for
// reconciliation. Only an explicit non-rate-limit 4xx is safe to release.
function isConfirmedPreBillingRejection(error) {
  const status = Number(error?.status);
  return Number.isInteger(status) && status >= 400 && status < 500 && status !== 429;
}

// D-148/D-045/D-055: called once, right at setup completion (or, for the
// D-027 migration cohort, once at first launch of this build). Device-bound
// for new users; account-bound and device-check-free for the migration
// grant, per D-045's explicit carve-out.
app.post('/completeSetup', requireFirebaseAuth, async (req, res) => {
  try {
    const user = await admin.auth().getUser(req.uid);
    if (!user.providerData.some(p => ['apple.com', 'google.com'].includes(p.providerId))) {
      return res.status(403).json({ error: 'linked_account_required' });
    }
    const result = await completeSetup(admin.firestore(), req.uid, req.body?.sessionId);
    res.json(result);
  } catch (e) {
    const invalid = /required|invalid|duplicate|limit|already_complete/.test(e.message);
    res.status(invalid ? 400 : 503).json({ error: invalid ? e.message : 'completion_unavailable' });
  }
});

app.post('/requestTrial', requireFirebaseAuth, async (req, res) => {
  const { platform, androidIdHash, deviceCheckToken, isDevelopmentBuild, isMigration } = req.body || {};
  try {
    ensureAdmin();
    const store = admin.firestore();
    const result = isMigration
      ? await grantMigrationTrial(req.uid, store)
      : await grantTrialIfEligible(req.uid, {
        platform,
        androidIdHash,
        deviceCheckToken,
        deviceCheckConfig: { privateKeyPem: sDeviceCheckKey.value(), isDevelopmentBuild: !!isDevelopmentBuild },
      }, store);
    res.json(result);
  } catch (e) {
    if (e instanceof DeviceTrialError) {
      return res.status(e.status).json({ error: e.message });
    }
    console.error('requestTrial error:', e.message);
    res.status(502).json({ error: e.message });
  }
});

// D-149: installation identity and token lifecycle are account-scoped, but
// deliberately separate from profile data. A stable installation id can move
// during account linking; registering it disables any outgoing account copy.
app.post('/registerInstallation', requireFirebaseAuth, async (req, res) => {
  try {
    ensureAdmin();
    res.json(await registerInstallation(admin.firestore(), req.uid, req.body || {}));
  } catch (e) {
    const status = e.status || 503;
    res.status(status).json({ error: status === 503 ? 'installation_unavailable' : e.message });
  }
});

// D-149: read acknowledgement is best-effort and account-bound. Unknown or
// already-deleted keys still receive the contract acknowledgement.
app.post('/markInboxRead', requireFirebaseAuth, async (req, res) => {
  try {
    ensureAdmin();
    res.json(await markInboxRead(admin.firestore(), req.uid, req.body || {}));
  } catch (e) {
    const status = e.status || 503;
    res.status(status).json({ error: status === 503 ? 'inbox_unavailable' : e.message });
  }
});

app.post('/boardAdvisorTurn', requireFirebaseAuth, (req, res, next) => req.body?.isSetup ? setupIdempotency(() => admin.firestore())(req, res, next) : next(), async (req, res) => {
  // D-074/D-080: soloSetup — not isSetup — is a solo conversation with
  // Mira, forced through a tool call so her readiness to build the pyramid
  // comes back as data, not free text. isSetup only ever meant "billed
  // free" (D-015); every call inside a setup-typed session sets it,
  // including essence-deepening's four-advisor rotation (D-007 step 3),
  // which must NOT be routed through the solo-Mira path — found live,
  // conflating the two silently broke essence-deepening (always Mira,
  // wrong framing, D-076's pacing suffix leaking into a conversation it
  // was never meant to touch). Every non-solo-setup caller (category
  // re-clarification, essence-deepening, D-075's general Council chat)
  // keeps the original four-advisor free-text path.
  const { isSetup, soloSetup, sessionId, sliderValue, conversationHistory, existingCategories, pyramidContext } = req.body || {};
  if (soloSetup) return handleSetupAdvisorTurn(req, res, { sessionId, sliderValue, conversationHistory, existingCategories });

  // D-079: pyramidContext, present only from GeneralCouncilScreen (D-075),
  // switches this from the category-scoped clarification framing to the
  // pyramid-grounded "help them live out values they've already defined"
  // framing — real context instead of the "their life" placeholder that
  // produced disconnected, non-sequitur replies.
  // D-082: nudgeConvergence fires once the general Council conversation has
  // run two full four-advisor rounds without converging — enough room for
  // real diagnosis (D-074's "not so many it drags" ethos) before pushing
  // toward a concrete next step. Never applies to the category-scoped or
  // solo-setup paths, which have their own convergence signals already
  // (essence acceptance; readyToBuild).
  const GENERAL_CONVERGENCE_TURN_THRESHOLD = 8;
  // D-150: Council replies need enough room to finish a useful thought.
  // Keep this bounded for cost control, but do not cap normal conversation
  // at the old 120-token budget, which could return a sentence fragment.
  const GENERAL_COUNCIL_MAX_OUTPUT_TOKENS = 320;
  const built = pyramidContext
    ? buildGeneralCouncilTurnPrompt({
        ...(req.body || {}),
        pyramidContext,
        nudgeConvergence: countMiraTurns(conversationHistory) >= GENERAL_CONVERGENCE_TURN_THRESHOLD,
      })
    : buildAdvisorTurnPrompt(req.body || {});
  if (!built) return res.status(400).json({ error: 'Invalid advisorKey' });
  const { advisor, systemText, userMessage } = built;

  // D-061/D-148: refused before the model is ever called — the guard
  // protects against cost/overuse, not against a request that already
  // spent money.
  if (!(await guardCouncilCall(req, res, { isSetup, sessionId }))) return;

  const model = await getCouncilModel();
  try {
    const msg = await claude().messages.create({
      model,
      max_tokens: GENERAL_COUNCIL_MAX_OUTPUT_TOKENS,
      // Thinking is off, not just unrequested: Opus 5 can emit a `thinking`
      // block ahead of the reply even without it, which both costs extra
      // output tokens and (if not parsed defensively) can return an empty
      // reply — a live one/two-sentence chat line gets nothing from
      // reasoning that's worth either cost.
      thinking: { type: 'disabled' },
      // D-145: this block is the stable prefix — constant per advisor while
      // the intensity slider stays at its default (D-056) — so it carries
      // the cache breakpoint. Nothing user-derived is in this block.
      system: [{ type: 'text', text: systemText, cache_control: { type: 'ephemeral' } }],
      messages: [{ role: 'user', content: userMessage }],
    });
    // D-015: setup is free — its cost is never recorded against the D-061
    // dollar ledger, only counted against D-148's call limit (already done
    // above, before the model call).
    if (!isSetup) {
      await settleReservedCost(req, model, msg.usage);
    }
    const reply = extractReplyText(msg.content);
    if (!reply) {
      console.error('boardAdvisorTurn: no text block in response — advisor:', advisor.name, 'stop_reason:', msg.stop_reason);
      return res.status(502).json({ error: 'empty_reply' });
    }
    res.json({
      reply,
      usage: { inputTokens: msg.usage.input_tokens, outputTokens: msg.usage.output_tokens },
    });
  } catch (e) {
    if (!isSetup && isConfirmedPreBillingRejection(e)) {
      await releaseReservedCost(req).catch(() => {});
    }
    console.error('boardAdvisorTurn error:', e.message, '— advisor:', advisor.name, '— model:', model);
    res.status(502).json({ error: e.message });
  }
});

// D-074: the solo-Mira half of /boardAdvisorTurn, split out so the
// four-advisor free-text path above stays exactly as it was for its other
// two callers (category re-clarification, D-075's general Council chat).
async function handleSetupAdvisorTurn(req, res, { sessionId, sliderValue, conversationHistory, existingCategories }) {
  if (!(await guardCouncilCall(req, res, { isSetup: true, sessionId }))) return;

  const { systemText, userMessage } = buildSetupAdvisorTurnPrompt({ sliderValue, conversationHistory, existingCategories });
  const model = await getCouncilModel();
  try {
    const msg = await claude().messages.create({
      model,
      max_tokens: 150,
      thinking: { type: 'disabled' },
      // D-145: stable prefix, same cache treatment as the group-chat path.
      system: [{ type: 'text', text: systemText, cache_control: { type: 'ephemeral' } }],
      messages: [{ role: 'user', content: userMessage }],
      tools: [SETUP_TURN_TOOL],
      tool_choice: { type: 'tool', name: SETUP_TURN_TOOL.name },
    });
    const toolUse = msg.content.find((b) => b.type === 'tool_use');
    if (!toolUse) {
      console.error('boardAdvisorTurn(setup): no tool_use in response, stop_reason:', msg.stop_reason);
      return res.status(502).json({ error: 'no_tool_use_in_response' });
    }
    let readyToBuild = !!toolUse.input.readyToBuild;
    let reply = toolUse.input.reply;
    const wrapUpAlreadyAsked = !existingCategories && hasAskedWrapUpQuestion(conversationHistory);
    const turnsSoFar = countMiraTurns(conversationHistory);
    // D-095: once D-076's pacing reassurance has already fired once (at
    // turnsSoFar == 2), only one more question is allowed — found live:
    // several "almost there"/"not much further to go" reassurances in a
    // row, across multiple turns the model kept deciding weren't ready
    // yet, read as being dragged along rather than reassured. Forced the
    // same deterministic way as D-094, never left to the model's own
    // per-turn judgment.
    const mustWrapUpNow = !existingCategories && !wrapUpAlreadyAsked && turnsSoFar >= 3;
    // D-094: once the wrap-up question has already been asked (and just
    // answered), the very next turn is the real close — forced
    // deterministically, regardless of what the model itself returned for
    // readyToBuild this turn. Found live: leaving this to the model's own
    // per-turn judgment let it ask yet another follow-up question instead
    // of closing, exactly the defect this guarantees can't happen —
    // matching D-076's own lesson that a soft, once-per-conversation
    // instruction is not something to trust the model to reliably follow
    // on its own.
    if (wrapUpAlreadyAsked) {
      readyToBuild = true;
    } else if (!existingCategories && (readyToBuild || mustWrapUpNow)) {
      // D-093: the first time Mira decides she's ready (or D-095: the
      // conversation has hit its post-reassurance cap regardless of what
      // she decided) — the initial (non-refining) conversation only,
      // never the refinement loop — this is intercepted: instead of
      // actually closing, the summary reply gets the fixed wrap-up
      // question appended and readyToBuild is forced back to false, so
      // the conversation continues for exactly one more round.
      reply = `${(reply || '').trim()} ${SETUP_WRAP_UP_QUESTION}`;
      readyToBuild = false;
    } else {
      // D-076: applied server-side, deterministically — found live that
      // asking the model to weave this into its own reply wasn't reliably
      // followed several turns into a real conversation.
      reply = applyPacingReassurance(reply, { turnsSoFar, readyToBuild });
    }
    // D-015: setup is free — never charged against D-061's dollar ledger,
    // only counted against D-148's call limit (already done above).
    res.json({
      reply,
      readyToBuild,
      usage: { inputTokens: msg.usage.input_tokens, outputTokens: msg.usage.output_tokens },
    });
  } catch (e) {
    console.error('boardAdvisorTurn(setup) error:', e.message, '— model:', model);
    res.status(502).json({ error: e.message });
  }
}

// ── Setup derivation (D-038/D-039/D-042) ────────────────────────────────────
// All three are setup-only: always free (D-015), always bounded by D-148's
// call count, never by D-061's spend cap.

app.post('/deriveCategories', requireFirebaseAuth, setupIdempotency(() => admin.firestore()), async (req, res) => {
  const { sessionId, transcript, existingCategories } = req.body || {};
  if (!(await guardCouncilCall(req, res, { isSetup: true, sessionId }))) return;

  const { system, user } = buildDeriveCategoriesPrompt(transcript, { existingCategories });
  const model = await getCouncilModel();
  try {
    const msg = await claude().messages.create({
      model,
      max_tokens: 400,
      thinking: { type: 'disabled' },
      system: [{ type: 'text', text: system }],
      messages: [{ role: 'user', content: user }],
      tools: [CATEGORIES_TOOL],
      tool_choice: { type: 'tool', name: CATEGORIES_TOOL.name },
    });
    const toolUse = msg.content.find((b) => b.type === 'tool_use');
    if (!toolUse) return res.status(502).json({ error: 'no_tool_use_in_response' });
    res.json({ categories: toolUse.input.categories });
  } catch (e) {
    console.error('deriveCategories error:', e.message);
    res.status(502).json({ error: e.message });
  }
});

app.post('/deriveHabits', requireFirebaseAuth, setupIdempotency(() => admin.firestore()), async (req, res) => {
  const { sessionId, categoryName, essence, existingHabits, maxAllowed } = req.body || {};
  if (!(await guardCouncilCall(req, res, { isSetup: true, sessionId }))) return;

  // D-068: maxAllowed is setup_screen.dart's own reservation across all
  // six categories (never more than 10 habits total, never less than 1
  // per category) — the tool schema's maxItems is generated per call, not
  // a fixed constant, so the model is never even offered more room than
  // this specific category has left in the budget.
  const tool = habitsTool(maxAllowed);
  const model = await getCouncilModel();
  try {
    const saved = await admin.firestore().collection('users').doc(req.uid).collection('councilSessions').doc(sessionId).get();
    const transcript = (saved.data()?.messages || []).map(m => ({ advisor: m.advisorKey, text: m.text }));
    const { system, user } = buildDeriveHabitsPrompt({ categoryName, essence, existingHabits, maxAllowed, transcript });
    const msg = await claude().messages.create({
      model,
      max_tokens: 300,
      thinking: { type: 'disabled' },
      system: [{ type: 'text', text: system }],
      messages: [{ role: 'user', content: user }],
      tools: [tool],
      tool_choice: { type: 'tool', name: tool.name },
    });
    const toolUse = msg.content.find((b) => b.type === 'tool_use');
    if (!toolUse) return res.status(502).json({ error: 'no_tool_use_in_response' });
    res.json({ habits: toolUse.input.habits });
  } catch (e) {
    console.error('deriveHabits error:', e.message);
    res.status(502).json({ error: e.message });
  }
});

// D-089: isSetup now comes from the caller instead of being hardcoded
// true — setup's own closing synthesis (D-042) still passes true and
// stays free (D-015); profile.dart's regeneration, outside any setup
// session, passes false and goes through D-014's entitlement gate like
// every other non-setup AI surface. sessionId/transcript are optional —
// a regeneration has neither, only the pyramid's current essences.
app.post('/deriveVisionStatement', requireFirebaseAuth, (req, res, next) => req.body?.isSetup ? setupIdempotency(() => admin.firestore())(req, res, next) : next(), async (req, res) => {
  const { sessionId, essences, transcript, isSetup } = req.body || {};
  if (!(await guardCouncilCall(req, res, { isSetup: !!isSetup, sessionId }))) return;

  const { system, user } = buildVisionStatementPrompt({ essences, transcript });
  const model = await getCouncilModel();
  try {
    const msg = await claude().messages.create({
      model,
      max_tokens: 300,
      thinking: { type: 'disabled' },
      system: [{ type: 'text', text: system }],
      messages: [{ role: 'user', content: user }],
    });
    if (!isSetup) {
      await settleReservedCost(req, model, msg.usage);
    }
    const vision = extractReplyText(msg.content);
    if (!vision) return res.status(502).json({ error: 'empty_reply' });
    res.json({ vision });
  } catch (e) {
    if (!isSetup && isConfirmedPreBillingRejection(e)) {
      await releaseReservedCost(req).catch(() => {});
    }
    console.error('deriveVisionStatement error:', e.message);
    res.status(502).json({ error: e.message });
  }
});

// D-089: the profile screen's 30-day progress analysis — a new AI
// surface, never gated by anything but D-014's standard entitlement
// check (never free, since it isn't setup).
app.post('/deriveProgressAnalysis', requireFirebaseAuth, async (req, res) => {
  const { taskLogs, firstName } = req.body || {};
  if (!(await guardCouncilCall(req, res, { isSetup: false }))) return;

  const { system, user } = buildProgressAnalysisPrompt({ taskLogs, firstName });
  const model = await getCouncilModel();
  try {
    const msg = await claude().messages.create({
      model,
      max_tokens: 300,
      thinking: { type: 'disabled' },
      system: [{ type: 'text', text: system }],
      messages: [{ role: 'user', content: user }],
    });
    await settleReservedCost(req, model, msg.usage);
    const analysis = extractReplyText(msg.content);
    if (!analysis) return res.status(502).json({ error: 'empty_reply' });
    res.json({ analysis });
  } catch (e) {
    if (isConfirmedPreBillingRejection(e)) {
      await releaseReservedCost(req).catch(() => {});
    }
    console.error('deriveProgressAnalysis error:', e.message);
    res.status(502).json({ error: e.message });
  }
});

// D-122: the newsfeed's AI-written analysis article — gated by entitlement
// and the spend cap exactly like every other non-setup AI surface
// (guardCouncilCall's isSetup: false branch). Never called more than once
// a day per NewsfeedService's own dedupeKey, but that throttling lives
// client-side; this endpoint itself is stateless like the others.
app.post('/deriveNewsfeedArticle', requireFirebaseAuth, async (req, res) => {
  const { categories, firstName } = req.body || {};
  if (!(await guardCouncilCall(req, res, { isSetup: false }))) return;

  const { system, user } = buildNewsfeedAnalysisPrompt({ categories, firstName });
  const model = await getCouncilModel();
  try {
    const msg = await claude().messages.create({
      model,
      max_tokens: 400,
      thinking: { type: 'disabled' },
      system: [{ type: 'text', text: system }],
      messages: [{ role: 'user', content: user }],
    });
    await settleReservedCost(req, model, msg.usage);
    const raw = extractReplyText(msg.content);
    if (!raw) return res.status(502).json({ error: 'empty_reply' });
    res.json(parseArticleReply(raw));
  } catch (e) {
    if (isConfirmedPreBillingRejection(e)) {
      await releaseReservedCost(req).catch(() => {});
    }
    console.error('deriveNewsfeedArticle error:', e.message);
    res.status(502).json({ error: e.message });
  }
});

export const api = onRequest(
  {
    secrets: [sOpenAI, sAnthropic, sDeviceCheckKey, sRevenueCatWebhookSecret],
    timeoutSeconds: 60,
    memory: '256MiB',
    invoker: 'public',
  },
  app,
);

// ── Notifications (D-149/D-028/D-149) ───────────────────────────────────────
//
// D-028: exactly this context, read from profile/main — the array already
// synced by the client (SyncService), never a separate model call to
// assemble it.
async function sendTailoredNotification(uid, profileData) {
  const db = admin.firestore();
  const categories = (profileData.categories || []).map((c) => ({
    name: c.cat,
    tier: c.position <= 3 ? 1 : c.position <= 5 ? 2 : 3,
    essence: c.activeEssence ?? null,
  }));

  const recentSnap = await db
      .collection('users').doc(uid).collection('recentActivity').get();
  const recentActivity = recentSnap.docs.map((d) => d.data());

  // D-145 step 7: present only when the user granted calendar access —
  // absent entirely otherwise (buildNotificationPrompt already omits the
  // section when this is undefined).
  const calendarContext = profileData.calendarContext;

  const { system, user } = buildNotificationPrompt({
    categories,
    visionStatement: profileData.visionStatement,
    recentActivity,
    calendarContext,
    // D-138: already present on profileData — synced by the client's
    // SyncService the same way every other profile/main field is.
    firstName: profileData.firstName,
  });

  const model = await getNotificationModel();
  const msg = await claude().messages.create({
    model,
    max_tokens: 200,
    thinking: { type: 'disabled' },
    system: [{ type: 'text', text: system }],
    messages: [{ role: 'user', content: user }],
    tools: [NOTIFICATION_TOOL],
    tool_choice: { type: 'tool', name: NOTIFICATION_TOOL.name },
  });
  const toolUse = msg.content.find((b) => b.type === 'tool_use');
  if (!toolUse) throw new Error('no_tool_use_in_response');
  const { title, body } = toolUse.input;

  recordCost(uid, model, msg.usage.input_tokens, msg.usage.output_tokens)
      .catch((e) => console.error('recordCost error:', e.message));

  // D-149: cached so the client's local fallback has the most recent
  // server-generated content if push was never granted or delivery fails.
  await db.collection('users').doc(uid).collection('profile').doc('main').set({
    lastNotificationTitle: title,
    lastNotificationBody: body,
    lastNotificationAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  const fcmToken = profileData.fcmToken;
  if (!fcmToken) {
    console.log(`notificationJob: ${uid} has no fcmToken registered — relying on the client's local fallback.`);
    return;
  }

  try {
    // D-066 amendment / Phase 6 fix (2026-09-10): this send previously
    // carried no `data` field at all — the reason a tap on a real
    // tailored push had nothing to route on. `type: 'tailored'` is all a
    // tap handler needs here; unlike batchCheckinJob's push there's no
    // per-notification payload to carry, since every tailored
    // notification's destination is the same (the pyramid tab).
    await admin.messaging().send({
      token: fcmToken,
      notification: { title, body },
      data: { type: 'tailored' },
    });
  } catch (e) {
    // D-149: a delivery failure is logged and surfaced, never swallowed —
    // lastNotificationTitle/Body above is what lets the client recover.
    console.error(`notificationJob: FCM send failed for ${uid}:`, e.message);
  }
}

// D-149: runs every 15 minutes (D-149's timezone-bucketing granularity,
// notification_schedule.js); D-149's exclusion of lapsed accounts is
// enforced in isEligibleForTailoredNotification, which also implements
// R7's "every account is entitled until R8" carve-out. A full
// collectionGroup scan every 15 minutes is the simplest correct
// implementation for the current account volume; revisit with
// timezone-bucketed queries or a fan-out if volume grows enough to matter.
export const notificationJob = onSchedule(
  {
    schedule: 'every 15 minutes',
    secrets: [sAnthropic],
    timeoutSeconds: 300,
    memory: '256MiB',
  },
  async () => {
    ensureAdmin();
    const db = admin.firestore();
    const now = new Date();

    const snapshot = await db.collectionGroup('profile').get();
    for (const doc of snapshot.docs) {
      if (doc.id !== 'main') continue;
      const data = doc.data();
      if (!isEligibleForTailoredNotification(data, now)) continue;

      const uid = doc.ref.parent.parent.id;
      try {
        await sendTailoredNotification(uid, data);
      } catch (e) {
        console.error(`notificationJob: failed for ${uid}:`, e.message);
      }
    }
  },
);

// D-147: prune only abandoned, never-linked anonymous accounts after their
// server-owned ttlAt. The helper rechecks Auth/profile state and records a
// per-uid audit outcome, so transient deletion failures can be retried.
export const anonymousCleanupJob = onSchedule(
  {
    schedule: 'every 24 hours',
    timeoutSeconds: 300,
    memory: '256MiB',
  },
  async () => {
    ensureAdmin();
    const outcomes = await cleanupAnonymousAccounts(
        admin.firestore(), admin.auth(), new Date());
    console.log('anonymousCleanupJob outcomes:', outcomes.map(({ uid, outcome }) => ({ uid, outcome })));
  },
);

// D-099: once per account per day, after the *latest* scheduled habit
// (D-098) of that day has passed in the account's own local time (D-149),
// sends a single push naming every one of that day's scheduled, active
// habits — replacing Kansei's per-session "Did you do it?" with one
// batched push, per the owner's explicit choice that Green Pyramid's
// higher daily habit volume makes a per-habit notification the wrong
// design here. batch_checkin_schedule.js's shouldSendBatchCheckin decides
// the "when" (data-dependent, unlike D-149's fixed clock slots) and its
// own "already sent today" field is the once-per-day guard.
//
// Unlike notificationJob, this calls no model and costs nothing to run —
// so it is NOT restricted to non-lapsed accounts, matching D-013's
// tracker-is-free-forever and D-098's own "scheduling is available
// regardless of entitlement."
async function maybeSendBatchCheckin(uid, profileData, now) {
  const db = admin.firestore();
  const timezone = profileData?.timezone;
  if (!timezone) return;

  const tasksSnap = await db.collection('users').doc(uid).collection('tasks').get();
  const tasks = tasksSnap.docs.map((d) => ({ id: d.id, ...d.data() }));

  const shouldSend = shouldSendBatchCheckin({
    tasks,
    timezone,
    now,
    lastSentDate: profileData.lastBatchCheckinSentDate,
  });
  if (!shouldSend) return;

  const { dateString, weekday } = localDateParts(timezone, now);
  const habits = todaysScheduledHabits(tasks, weekday);
  if (habits.length === 0) return; // defensive — shouldSendBatchCheckin already checked this.

  const messageKey = notificationMessageKey({
    type: 'batch_checkin',
    occurrenceDate: dateString,
    habitIds: habits.map((habit) => String(habit.id)),
  });
  const claimed = await claimNotificationDispatch(db, uid, messageKey, now);
  if (!claimed) return;

  // D-099: the payload the batch check-in screen renders from, not a
  // fresh query — so what the user sees on tap matches what the push was
  // actually about even if the pyramid changes in between. Also the
  // once-per-day guard for every later run today.
  await db.collection('users').doc(uid).collection('profile').doc('main').set({
    lastBatchCheckinSentDate: dateString,
    lastBatchCheckinHabits: habits,
  }, { merge: true });

  const fcmToken = profileData.fcmToken;
  if (!fcmToken) {
    console.log(`batchCheckinJob: ${uid} has no fcmToken registered — nothing to send.`);
    return;
  }

  const body = habits.length === 1
    ? `${habits[0].description} — how did it go?`
    : `${habits.length} habits scheduled today — how did they go?`;

  try {
    await admin.messaging().send({
      token: fcmToken,
      notification: { title: 'Did you do it?', body },
      // D-066's amendment noted real FCM pushes carry no `data` field at
      // all today — this is the first push that needs one, so it's added
      // here rather than for every push type at once.
      data: {
        type: 'batch_checkin',
        messageKey,
        accountUid: uid,
        occurrenceDate: dateString,
        habitIds: JSON.stringify(habits.map((habit) => String(habit.id))),
      },
    });
  } catch (e) {
    console.error(`batchCheckinJob: FCM send failed for ${uid}:`, e.message);
  }
}

export const batchCheckinJob = onSchedule(
  {
    schedule: 'every 15 minutes',
    timeoutSeconds: 300,
    memory: '256MiB',
  },
  async () => {
    ensureAdmin();
    const db = admin.firestore();
    const now = new Date();

    const snapshot = await db.collectionGroup('profile').get();
    for (const doc of snapshot.docs) {
      if (doc.id !== 'main') continue;
      const data = doc.data();

      const uid = doc.ref.parent.parent.id;
      try {
        await maybeSendBatchCheckin(uid, data, now);
      } catch (e) {
        console.error(`batchCheckinJob: failed for ${uid}:`, e.message);
      }
    }
  },
);
