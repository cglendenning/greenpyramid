// D-114: the profile screen's 30-day progress analysis — a new AI surface,
// migrated onto Claude from day one (it never had a Claude equivalent; the
// legacy version this replaces called OpenAI directly through profile.dart,
// the one AI surface D-069/D-083's retirement of the legacy AI screens
// missed).
import { sanitize } from './council.js';

// D-178: [firstName] lets the analysis open with or include the reader's
// actual name instead of only ever writing generically in the second
// person — sanitized like every other user-supplied string reaching a
// prompt.
export function buildProgressAnalysisPrompt({ taskLogs = [], firstName = null }) {
  const lines = (taskLogs || [])
    .map((t) => {
      const date = sanitize(t.date, 10);
      const category = sanitize(t.category, 60);
      const task = sanitize(t.taskDescription, 120);
      const checked = t.checked === 'true' ? 'done' : 'skipped';
      return `${date} | ${category} | ${task} | ${checked}`;
    })
    .join('\n');

  const name = firstName ? sanitize(firstName, 40) : null;
  const nameInstruction = name
    ? `The reader's name is ${name} — open by addressing them by name naturally (e.g. "${name}, ..."), the ` +
      'way an advisor who knows them would, rather than only writing in the abstract second person. '
    : '';

  const system =
    'You are one of a person\'s advisors, reviewing their last 30 days of daily habit check-offs across ' +
    'their pyramid of values. ' +
    nameInstruction +
    'Write a short, warm, specific analysis: what they\'re genuinely doing well, ' +
    'one real pattern worth naming (a category slipping, a day of the week that\'s hard, a streak worth ' +
    'celebrating), and one encouraging, concrete next step. Two to four sentences, plain prose, second ' +
    'person. Never a bulleted list, never generic encouragement disconnected from what the data actually ' +
    'shows. If there is too little data to say anything real and specific, say that plainly and warmly ' +
    'instead of inventing a pattern that isn\'t there.';

  const user =
    `THEIR LAST 30 DAYS (date | category | habit | done or skipped):\n` +
    `${lines || '(no check-offs logged in this window)'}`;

  return { system, user };
}
