// D-036/D-037: the scheduled cloud job's generation logic — a tailored
// push notification synthesized from exactly the enumerated context D-037
// permits, nothing else.
import { sanitize } from './council.js';

export const NOTIFICATION_TOOL = {
  name: 'send_notification',
  description: 'Write one short, tailored push notification.',
  input_schema: {
    type: 'object',
    properties: {
      title: { type: 'string', minLength: 1, maxLength: 60 },
      body: { type: 'string', minLength: 1, maxLength: 140 },
    },
    required: ['title', 'body'],
  },
};

// D-037 (amended for R9 to add domainFindings/calendarContext — D-048's own
// text always said findings feed notification generation, but D-037's
// enumerated context never listed them until now): exactly this context,
// nothing else. [categories] is [{name, tier, essence}] (essence null for
// cat4-cat6 without one, D-010). [recentActivity] is the bounded task_log
// window already synced (D-075). [domainFindings] is [{domain, note}].
// [calendarContext] is a short pre-summarized string, present only when the
// user granted calendar access (D-025 step 7) — absent entirely otherwise,
// never a placeholder.
export function buildNotificationPrompt({
  categories = [],
  visionStatement,
  recentActivity = [],
  domainFindings = [],
  calendarContext,
}) {
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
    'a short title and a one-sentence body. No emojis.';

  const findingLines = domainFindings.slice(0, 50).map((f) =>
    `- ${sanitize(f.domain, 20)}: ${sanitize(f.note, 200)}`).join('\n');

  const user =
    `CATEGORIES:\n${categoryLines}\n\n` +
    (visionStatement ? `THEIR VISION: "${sanitize(visionStatement, 500)}"\n\n` : '') +
    `RECENT ACTIVITY:\n${recentLines || '(none yet)'}` +
    (findingLines ? `\n\nDOMAIN FINDINGS (impediments named in past Council sessions):\n${findingLines}` : '') +
    (calendarContext ? `\n\nTODAY'S CALENDAR: ${sanitize(calendarContext, 500)}` : '');

  return { system, user };
}
