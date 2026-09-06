// Green Pyramid backend — the OpenAI key lives ONLY here, in Firebase Secret
// Manager, and is injected at runtime. It is never shipped in the app binary.
// The app calls this function as an OpenAI-compatible proxy: same request body
// it would send to api.openai.com, but authenticated with a Firebase App Check
// token (proves the request came from the genuine app) and an anonymous
// Firebase ID token (proves an app-minted identity). Mirrors the goal-executor
// backend, plus App Check.
import { onRequest } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { setGlobalOptions } from 'firebase-functions/v2';
import { defineSecret } from 'firebase-functions/params';
import express from 'express';
import cors from 'cors';
import OpenAI from 'openai';
import Anthropic from '@anthropic-ai/sdk';
import admin from 'firebase-admin';
import { buildAdvisorTurnPrompt, extractReplyText } from './lib/council.js';
import { checkSpendLimit, recordCost, SpendLimitError } from './lib/billing.js';
import { getCouncilModel, getNotificationModel } from './lib/model_config.js';
import { guardAndCountSetupCall, SetupCallLimitError } from './lib/setup_guard.js';
import { buildDeriveCategoriesPrompt, buildDeriveHabitsPrompt, buildVisionStatementPrompt, CATEGORIES_TOOL, HABITS_TOOL } from './lib/setup_derivation.js';
import { isEligibleForTailoredNotification } from './lib/notification_schedule.js';
import { buildNotificationPrompt, NOTIFICATION_TOOL } from './lib/notification_derivation.js';
import { requireEntitlement, EntitlementRequiredError } from './lib/entitlement.js';
import { grantTrialIfEligible, grantMigrationTrial, DeviceTrialError } from './lib/device_trial.js';
import { applyRevenueCatEvent, verifyWebhookAuth } from './lib/revenuecat_webhook.js';

// Stored in Firebase Secret Manager (firebase functions:secrets:set
// OPENAI_API_KEY / ANTHROPIC_API_KEY), never in source. OpenAI backs the
// legacy coach/commentary surfaces until D-083 (R6) retires them; Anthropic
// backs the Council (D-040, D-050).
const sOpenAI = defineSecret('OPENAI_API_KEY');
const sAnthropic = defineSecret('ANTHROPIC_API_KEY');
// D-059: Apple DeviceCheck signing key (.p8, PEM). D-070: RevenueCat's
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

// D-087: verifies a Firebase ID token passed as "Authorization: Bearer
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

// D-070: RevenueCat calls this directly from its own servers — never through
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
    await applyRevenueCatEvent(req.body?.event, admin.firestore());
    res.json({ ok: true });
  } catch (e) {
    console.error('revenuecatWebhook error:', e.message);
    // Still 200s: a transient Firestore error here should not make
    // RevenueCat retry-storm an event that may partially have applied.
    res.status(200).json({ ok: false });
  }
});

app.use(requireAppCheck);

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

// ── The Council of Advisors (D-027/D-028/D-040/D-050) ──────────────────────
// Prompt-building logic lives in lib/council.js so it's testable without
// spinning up Express or Firebase Admin (node --test lib/*.test.js).

let anthropicClient;
function claude() {
  if (!anthropicClient) anthropicClient = new Anthropic({ apiKey: sAnthropic.value() });
  return anthropicClient;
}

// D-017/D-072: setup is free — bounded by a 40-model-call count per
// session, never by the D-087 dollar cap. Every other Council use (D-016)
// is gated by spend instead. Shared by every setup-conversation route
// (turns and the two derivation endpoints below) so the bound is uniform
// regardless of which kind of call it is.
async function guardCouncilCall(req, res, { isSetup, sessionId }) {
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
  // D-016: every non-setup AI surface requires an active trial or
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
    await checkSpendLimit(req.uid);
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

// D-058/D-059/D-071: called once, right at setup completion (or, for the
// D-034 migration cohort, once at first launch of this build). Device-bound
// for new users; account-bound and device-check-free for the migration
// grant, per D-059's explicit carve-out.
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

app.post('/boardAdvisorTurn', requireFirebaseAuth, async (req, res) => {
  const built = buildAdvisorTurnPrompt(req.body || {});
  if (!built) return res.status(400).json({ error: 'Invalid advisorKey' });
  const { advisor, systemText, userMessage } = built;

  // D-087/D-072: refused before the model is ever called — the guard
  // protects against cost/overuse, not against a request that already
  // spent money.
  const { isSetup, sessionId } = req.body || {};
  if (!(await guardCouncilCall(req, res, { isSetup, sessionId }))) return;

  const model = await getCouncilModel();
  try {
    const msg = await claude().messages.create({
      model,
      max_tokens: 120,
      // Thinking is off, not just unrequested: Opus 5 can emit a `thinking`
      // block ahead of the reply even without it, which both costs extra
      // output tokens and (if not parsed defensively) can return an empty
      // reply — a live one/two-sentence chat line gets nothing from
      // reasoning that's worth either cost.
      thinking: { type: 'disabled' },
      // D-041: this block is the stable prefix — constant per advisor while
      // the intensity slider stays at its default (D-073) — so it carries
      // the cache breakpoint. Nothing user-derived is in this block.
      system: [{ type: 'text', text: systemText, cache_control: { type: 'ephemeral' } }],
      messages: [{ role: 'user', content: userMessage }],
    });
    // D-017: setup is free — its cost is never recorded against the D-087
    // dollar ledger, only counted against D-072's call limit (already done
    // above, before the model call).
    if (!isSetup) {
      recordCost(req.uid, model, msg.usage.input_tokens, msg.usage.output_tokens)
        .catch((e) => console.error('recordCost error:', e.message));
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
    console.error('boardAdvisorTurn error:', e.message, '— advisor:', advisor.name, '— model:', model);
    res.status(502).json({ error: e.message });
  }
});

// ── Setup derivation (D-051/D-052/D-055) ────────────────────────────────────
// All three are setup-only: always free (D-017), always bounded by D-072's
// call count, never by D-087's spend cap.

app.post('/deriveCategories', requireFirebaseAuth, async (req, res) => {
  const { sessionId, transcript } = req.body || {};
  if (!(await guardCouncilCall(req, res, { isSetup: true, sessionId }))) return;

  const { system, user } = buildDeriveCategoriesPrompt(transcript);
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

app.post('/deriveHabits', requireFirebaseAuth, async (req, res) => {
  const { sessionId, categoryName, essence, existingHabits } = req.body || {};
  if (!(await guardCouncilCall(req, res, { isSetup: true, sessionId }))) return;

  const { system, user } = buildDeriveHabitsPrompt({ categoryName, essence, existingHabits });
  const model = await getCouncilModel();
  try {
    const msg = await claude().messages.create({
      model,
      max_tokens: 300,
      thinking: { type: 'disabled' },
      system: [{ type: 'text', text: system }],
      messages: [{ role: 'user', content: user }],
      tools: [HABITS_TOOL],
      tool_choice: { type: 'tool', name: HABITS_TOOL.name },
    });
    const toolUse = msg.content.find((b) => b.type === 'tool_use');
    if (!toolUse) return res.status(502).json({ error: 'no_tool_use_in_response' });
    res.json({ habits: toolUse.input.habits });
  } catch (e) {
    console.error('deriveHabits error:', e.message);
    res.status(502).json({ error: e.message });
  }
});

app.post('/deriveVisionStatement', requireFirebaseAuth, async (req, res) => {
  const { sessionId, essences, transcript } = req.body || {};
  if (!(await guardCouncilCall(req, res, { isSetup: true, sessionId }))) return;

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
    const vision = extractReplyText(msg.content);
    if (!vision) return res.status(502).json({ error: 'empty_reply' });
    res.json({ vision });
  } catch (e) {
    console.error('deriveVisionStatement error:', e.message);
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

// ── Notifications (D-036/D-037/D-039) ───────────────────────────────────────
//
// D-037: exactly this context, read from profile/main — the array already
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

  const { system, user } = buildNotificationPrompt({
    categories,
    visionStatement: profileData.visionStatement,
    recentActivity,
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

  // D-038: cached so the client's local fallback has the most recent
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
    await admin.messaging().send({ token: fcmToken, notification: { title, body } });
  } catch (e) {
    // D-038: a delivery failure is logged and surfaced, never swallowed —
    // lastNotificationTitle/Body above is what lets the client recover.
    console.error(`notificationJob: FCM send failed for ${uid}:`, e.message);
  }
}

// D-036: runs every 15 minutes (D-039's timezone-bucketing granularity,
// notification_schedule.js); D-036's exclusion of lapsed accounts is
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
