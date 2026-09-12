// D-155: the newsfeed's AI-written "news article" — a Claude-authored
// analysis of consistency trends across the whole pyramid, framed exactly
// like a real news article (headline + body), not a chat reply. Modeled
// directly on progress_analysis.js's own prompt-builder shape; the two
// differ in scope (whole-pyramid comparison here vs. a single 30-day log
// review there) and in requiring strict JSON back, since this needs a
// separate headline and body rather than one paragraph.
import { sanitize } from './council.js';

// D-178: [firstName], when present, replaces the old impersonal "one
// person's"/"their" framing that produced generic "this person"-style
// text — owner: "I also do not want to use language like 'this
// person's' and instead... throughout everything in the app, we need to
// be using the user's first name." Sanitized like every other
// user-supplied string reaching a prompt (D-048's own discipline);
// falls back to the original generic framing for an account that
// somehow has none (predates D-178, or the field is blank).
export function buildNewsfeedAnalysisPrompt({ categories = [], firstName = null }) {
  const lines = (categories || [])
    .map((c) => {
      const name = sanitize(c.name, 60);
      const pct7 = Number.isFinite(c.pct7) ? c.pct7 : null;
      const pct30 = Number.isFinite(c.pct30) ? c.pct30 : null;
      const streak = Number.isFinite(c.streak) ? c.streak : 0;
      const essence = c.essence ? sanitize(c.essence, 200) : null;
      const pctText =
        pct7 === null || pct7 < 0
          ? 'no tasks tracked'
          : `last 7 days ${pct7}% complete, last 30 days ${pct30}% complete`;
      return (
        `${name}: ${pctText}, current streak ${streak} day(s)` +
        (essence ? `, essence: "${essence}"` : '')
      );
    })
    .join('\n');

  const name = firstName ? sanitize(firstName, 40) : null;
  const subject = name ? `${name}'s` : "one person's";
  const nameInstruction = name
    ? `The reader's name is ${name} — address them by name at least once, naturally, the way a real ` +
      'personalized newsletter would (never in every sentence, never more than twice). '
    : '';

  const system =
    `You are a data journalist writing a single short news article about ${subject} own life-tracking ` +
    'data — completion rates and streaks across the categories in their "pyramid" of values. ' +
    nameInstruction +
    'Find ONE genuine, specific trend in the numbers below: which category is most consistent right now, which is ' +
    'lagging or has gone quiet, whether things are improving or slipping compared to the 30-day baseline. ' +
    'Write it exactly like a real news article: a punchy, specific headline under 12 words that states the ' +
    'actual finding (for example "Increased Consistency Drives Growth in Craft", never generic or ' +
    'clickbait), then two to four short paragraphs of body text in a clear, analytical, slightly editorial ' +
    'voice. Name the strongest category by name. Give an honorable mention to a category that is lagging ' +
    'behind or has gone quiet, named specifically, without shaming — this is analysis, not a scolding. End ' +
    'with one concrete, encouraging observation grounded in the actual numbers. Never invent a trend the ' +
    'data does not support — if the data is too thin or too even to say anything real, write a short, ' +
    'honest piece about that instead (for example a headline like "Everything Holding Steady"). Never use ' +
    'emoji anywhere in the headline or body. Respond with strict JSON only, no markdown and no code fences: ' +
    '{"headline": "...", "body": "..."}';

  const user =
    `${name ? `${name.toUpperCase()}'S` : 'THEIR'} PYRAMID — completion rate and streak per category:\n` +
    `${lines || '(no categories with any task history yet)'}`;

  return { system, user };
}

// D-157: Claude sometimes wraps its JSON reply in a markdown code fence
// despite being told not to — found live, the very first real article a
// subscribed account generated came back as ```json ... ``` and fell
// through to the generic "Your Pyramid, Analyzed" fallback with the raw
// fenced JSON dumped into the body. The same lesson D-092 already
// learned for Mira's pacing reassurance applies here too: never rely on
// a soft prompt instruction alone when a deterministic fix is possible.
// Strips a single leading/trailing ``` or ```json fence, if present,
// before parsing — the prompt's own "no markdown and no code fences"
// instruction stays as a first line of defense, this is the backstop.
export function parseArticleReply(raw) {
  const trimmed = (raw || '').trim();
  const fenced = trimmed.match(/^```(?:json)?\s*\n?([\s\S]*?)\n?```$/i);
  const jsonText = fenced ? fenced[1].trim() : trimmed;
  try {
    const parsed = JSON.parse(jsonText);
    return {
      headline: String(parsed.headline || '').trim(),
      body: String(parsed.body || '').trim(),
    };
  } catch {
    // Still not parseable JSON even after stripping a fence — fall back
    // to the whole (unfenced-if-we-could) reply as the body, rather than
    // failing the request outright over a formatting slip.
    return { headline: 'Your Pyramid, Analyzed', body: jsonText };
  }
}
