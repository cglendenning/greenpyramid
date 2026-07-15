// Green Pyramid backend — the OpenAI key lives ONLY here, in Firebase Secret
// Manager, and is injected at runtime. It is never shipped in the app binary.
// The app calls this function as an OpenAI-compatible proxy: same request body
// it would send to api.openai.com, but authenticated with a Firebase App Check
// token (proves the request came from the genuine app) and an anonymous
// Firebase ID token (proves an app-minted identity). Mirrors the goal-executor
// backend, plus App Check.
import { onRequest } from 'firebase-functions/v2/https';
import { setGlobalOptions } from 'firebase-functions/v2';
import { defineSecret } from 'firebase-functions/params';
import express from 'express';
import cors from 'cors';
import OpenAI from 'openai';
import admin from 'firebase-admin';

// Stored in Firebase Secret Manager (firebase functions:secrets:set
// OPENAI_API_KEY), never in source.
const sOpenAI = defineSecret('OPENAI_API_KEY');

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

export const api = onRequest(
  {
    secrets: [sOpenAI],
    timeoutSeconds: 60,
    memory: '256MiB',
    invoker: 'public',
  },
  app,
);
