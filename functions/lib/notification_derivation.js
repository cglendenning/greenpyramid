// D-149/D-028: the scheduled cloud job's generation logic — a tailored
// push notification synthesized from exactly the enumerated context D-028
// permits, nothing else.
import { sanitize } from './council.js';

export const NOTIFICATION_TOOL = {
  name: 'send_notification',
  description: 'Write one short, tailored push notification with an inspiring preview quip.',
  input_schema: {
    type: 'object',
    properties: {
      title: { type: 'string', minLength: 1, maxLength: 48 },
      body: { type: 'string', minLength: 1, maxLength: 140 },
    },
    required: ['title', 'body'],
  },
};

export const MAX_NOTIFICATION_PREVIEW_WORDS = 5;

function wordCount(value) {
  return value.trim().split(/\s+/).filter(Boolean).length;
}

/**
 * D-021: keep the lock-screen/list preview short even when a model ignores
 * the wording instruction. The fallback is grounded in the same account
 * context that was supplied to the generator; it never invents a result.
 */
export function normalizeNotificationPreview({
  title,
  categories = [],
  recentActivity = [],
  firstName,
}) {
  const candidate = sanitize(typeof title === 'string' ? title : '', 48)
      .replace(/\s+/g, ' ')
      .trim();
  if (candidate && wordCount(candidate) <= MAX_NOTIFICATION_PREVIEW_WORDS) {
    return candidate;
  }

  const category = categories.find((entry) => entry?.name)?.name;
  const recent = recentActivity.find((entry) => entry?.category)?.category;
  const subject = sanitize(category || recent || '', 40).trim();
  if (subject) return `Keep ${subject} close`;
  if (firstName) return `${sanitize(firstName, 24)} keep going`;
  return 'Your next step matters';
}

// D-028 (amended for D-138 to add firstName): exactly this context, nothing else.
// [categories] is [{name, tier, essence}] (essence null for cat4-cat6
// without one, D-008). [recentActivity] is the bounded task_log window
// already synced (D-147).
// [calendarContext] is a short pre-summarized string, present only when the
// user granted calendar access (D-145 step 7) — absent entirely otherwise,
// never a placeholder. [firstName] lets a notification address the reader
// by name instead of writing only in the abstract second person.
export function buildNotificationPrompt({
  categories = [],
  visionStatement,
  recentActivity = [],
  calendarContext,
  firstName,
}) {
  const name = firstName ? sanitize(firstName, 40) : null;
  const categoryLines = categories.map((c) => {
    const name = sanitize(c.name, 60);
    const essence = c.essence ? sanitize(c.essence, 400) : null;
    return `- ${name} (tier ${c.tier})${essence ? `: "${essence}"` : ' (no essence captured yet)'}`;
  }).join('\n');

  const recentLines = recentActivity.slice(0, 250).map((a) => {
    const checked = a.checked === 'true' || a.checked === true;
    return `${sanitize(a.taskdate, 10)} ${sanitize(a.category, 60)} — ${sanitize(a.taskdescription, 120)}: ${checked ? 'done' : 'missed'}`;
  }).join('\n');

  const system =
    'You are the Council, writing one short push notification for someone ' +
    'using their life pyramid app. Lower-tier categories (tier 1) are ' +
    'foundational — weight what you notice there more heavily than tier 2 ' +
    'or 3. Draw on what they said their categories mean to them (their ' +
    'essences) and on recent completions or misses. Never invent urgency, ' +
    'a streak, or a deadline that is not real. Notice one true, specific ' +
    'thing — a pattern, a miss worth naming gently, or a completion worth ' +
    'acknowledging — never a generic reminder. Call send_notification with ' +
    'a title that is an inspiring quip of no more than five words, directly ' +
    'grounded in one named category, value, goal, task, completion, miss, or ' +
    'current pattern, plus a one-sentence body. No generic title, emojis, or ' +
    'invented personal detail.' +
    (name
      ? ` The reader's name is ${name} — use it in the title or body when it reads naturally (e.g. ` +
        `"Nice work, ${name}"), not forced into every notification.`
      : '');

  const user =
    `CATEGORIES:\n${categoryLines}\n\n` +
    (visionStatement ? `THEIR VISION: "${sanitize(visionStatement, 500)}"\n\n` : '') +
    `RECENT ACTIVITY:\n${recentLines || '(none yet)'}` +
    (calendarContext ? `\n\nTODAY'S CALENDAR: ${sanitize(calendarContext, 500)}` : '');

  return { system, user };
}
