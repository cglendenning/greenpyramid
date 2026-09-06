// D-051/D-052/D-055: the structured moments inside the single continuous
// setup conversation (D-043) where the Council doesn't just chat — it
// proposes the six tiered categories, proposes habits per category, and
// writes the closing vision statement. Each uses a forced tool call so the
// response is guaranteed-valid structured data, not text to parse.
import { sanitize } from './council.js';

function transcriptText(transcript) {
  return (transcript || [])
    .map((m) => `${m.advisor === 'user' ? 'User' : m.advisor}: ${sanitize(m.text, 500)}`)
    .join('\n');
}

// D-051: exactly six categories, already arranged by pyramid position
// (1-3 foundational, 4-5 essential, 6 peak) — never a preset list, always
// drawn from what the user actually said.
export const CATEGORIES_TOOL = {
  name: 'propose_categories',
  description: 'Propose the six pyramid categories, positioned 1-6, derived from the conversation so far.',
  input_schema: {
    type: 'object',
    properties: {
      categories: {
        type: 'array',
        minItems: 6,
        maxItems: 6,
        items: {
          type: 'object',
          properties: {
            position: { type: 'integer', minimum: 1, maximum: 6 },
            name: { type: 'string', minLength: 1, maxLength: 60 },
          },
          required: ['position', 'name'],
        },
      },
    },
    required: ['categories'],
  },
};

export function buildDeriveCategoriesPrompt(transcript) {
  const system =
    'You are the Council — the four advisors together, not any one of them — deriving the six ' +
    'categories of someone\'s life pyramid from a conversation they just had. Positions 1-3 are ' +
    'foundational (the parts of their life that hold up everything else — usually the ones they spoke ' +
    'about with the most weight or urgency). Positions 4-5 are essential. Position 6 is peak — ' +
    'aspirational, the thing at the top once the rest is standing. Every category name must come from ' +
    'the user\'s own words and specifics in the conversation — never a generic label like "Health" or ' +
    '"Career" unless that is genuinely how they put it themselves. Call propose_categories with exactly ' +
    'six entries, one per position 1 through 6.';
  const user = `CONVERSATION SO FAR:\n${transcriptText(transcript)}`;
  return { system, user };
}

// D-052: 3-5 habits for one category, conditioned on its essence when one
// exists (D-010: cat4-cat6 leave setup without one — falls back to
// name-only, degrading without a placeholder).
export const HABITS_TOOL = {
  name: 'propose_habits',
  description: 'Propose 3-5 concrete daily habits for one category.',
  input_schema: {
    type: 'object',
    properties: {
      habits: {
        type: 'array',
        minItems: 3,
        maxItems: 5,
        items: { type: 'string', minLength: 1, maxLength: 120 },
      },
    },
    required: ['habits'],
  },
};

export function buildDeriveHabitsPrompt({ categoryName, essence, existingHabits = [] }) {
  const name = sanitize(categoryName, 60);
  const essenceText = essence ? sanitize(essence, 400) : null;
  const blacklist = (existingHabits || []).map((h) => sanitize(h, 80));
  const system =
    'You propose daily habits for one category of someone\'s life pyramid. ' +
    (essenceText
      ? `Their own words for why this category matters to them: "${essenceText}" — let this shape which habits you propose, not just the category name.`
      : 'No stated reason exists for this category yet — propose from the category name alone, and do not invent one.') +
    ' Habits must be concrete, dailyable actions someone can check off — never vague aspirations like ' +
    '"be healthier" or "improve relationships". ' +
    (blacklist.length
      ? `Never repeat or closely restate any of these already-chosen habits: ${blacklist.join('; ')}.`
      : '') +
    ' Call propose_habits with 3 to 5 habits.';
  const user = `Category: '${name}'`;
  return { system, user };
}

// D-055: the closing synthesis. Written by the Council collectively (not
// any one advisor's persona), from the three foundational essences and the
// full transcript, in the user's own language — no fixed template opener.
export function buildVisionStatementPrompt({ essences, transcript }) {
  const essenceLines = (essences || [])
    .map((e) => `- ${sanitize(e.categoryName, 60)}: "${sanitize(e.essence, 400)}"`)
    .join('\n');
  const system =
    'You write exactly one thing: a short vision statement, referred to below as THE OUTPUT. You are not ' +
    'a participant in the conversation shown to you — you do not reply to it, continue it, or add another ' +
    'turn to it. The conversation is reference material only, describing someone who just finished a ' +
    'setup exchange with a support system called the Council. THE OUTPUT is the Council\'s closing ' +
    'synthesis, in their own language and specifics from the conversation, of who they are becoming. Draw ' +
    'directly on the essences and what they said. Do not open with "I will become the kind of person ' +
    'that" or any fixed template phrase — that formula is exactly what THE OUTPUT must avoid. THE OUTPUT ' +
    'is two to four sentences, first person, as if they are hearing their own truest thought said back to ' +
    'them — prose, never dialogue, never a speaker label, never a continuation of the conversation format. ' +
    'Your entire response is THE OUTPUT and nothing else — no preamble, no quotation marks around it, no ' +
    'commentary before or after it.';
  const user =
    `REFERENCE — THEIR ESSENCES:\n${essenceLines}\n\n` +
    `REFERENCE — THE CONVERSATION (for context only; do not continue or reply to it):\n${transcriptText(transcript)}\n\n` +
    'Now write THE OUTPUT: their vision statement, and only that.';
  return { system, user };
}
