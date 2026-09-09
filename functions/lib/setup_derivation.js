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
            // D-051: found live 2026-09-07 — names were coming back as
            // full clauses, not a label. 24 chars is roomy for two real
            // words ("Family Time", "Deep Work") without being roomy
            // enough for a sentence to sneak through.
            name: { type: 'string', minLength: 1, maxLength: 24 },
            // A short resonant phrase, not the full essence (that's the
            // Council exchange's job, later) — one line that would make
            // the user nod, not a definition of the category.
            description: { type: 'string', minLength: 1, maxLength: 140 },
          },
          required: ['position', 'name', 'description'],
        },
      },
    },
    required: ['categories'],
  },
};

// D-093: [existingCategories], when given, switches this from a fresh
// derivation to a refinement of a pyramid already proposed — the owner
// explicitly wants "not quite right" to adjust what's there, not discard it.
export function buildDeriveCategoriesPrompt(transcript, { existingCategories } = {}) {
  const refining = Array.isArray(existingCategories) && existingCategories.length > 0;
  const existingText = refining
    ? existingCategories
        .map((c) => `- position ${c.position ?? '?'}: ${sanitize(c.name, 24)} — ${sanitize(c.description || '', 140)}`)
        .join('\n')
    : null;

  const system =
    'You are the Council — the four advisors together, not any one of them — deriving the six ' +
    'categories of someone\'s life pyramid from a conversation they just had. Positions 1-3 are ' +
    'foundational (the parts of their life that hold up everything else — usually the ones they spoke ' +
    'about with the most weight or urgency). Positions 4-5 are essential. Position 6 is peak — ' +
    'aspirational, the thing at the top once the rest is standing. ' +
    'Each category needs two things, and they do different jobs: ' +
    'a NAME of exactly one or two words — a label, not a clause, the way a person would answer if asked ' +
    '"what would you call that part of your life?" ("Health", "Deep Work", "My Kids" — never a run-on ' +
    'phrase, never a full sentence) — drawn from the user\'s own words, not a generic textbook term ' +
    'unless that is genuinely their own word for it; and a DESCRIPTION of one short sentence, in their own ' +
    'words or tone from the conversation, that captures why it matters to them specifically — resonant, ' +
    'not a dictionary definition of the name, and not the full essence (a much deeper exchange happens ' +
    'later for that; this is one line that would make them nod, not an interview). ' +
    // D-094: a soft, disclosed bias toward body/mind/spirit in the
    // foundational tier — never a hard requirement, and explicitly
    // forbidden from inventing or displacing anything the person didn't
    // actually give real material for.
    'When choosing the three FOUNDATIONAL categories specifically, gently favor a spread across body ' +
    '(physical health), mind (mindset, mental or emotional wellbeing), and spirit (meaning or purpose) — ' +
    'but only where the conversation genuinely gives you real material for it. This is a soft bias, never ' +
    'a rule to force: never invent a foundational category the person didn\'t actually give you something ' +
    'to draw on for, and never displace something they clearly weighted heavily just to fill a slot. If ' +
    'their words don\'t support one of these three areas, leave it out rather than manufacture it.' +
    (refining
      ? `\n\nYou already proposed this pyramid for them:\n${existingText}\n\nThey said something wasn't ` +
        'quite right, and the conversation below includes what they clarified. REFINE the six categories ' +
        '— change what the new material actually calls for, and keep everything else close to what you ' +
        'already had. This is a revision, not a fresh start: do not reinvent categories the new material ' +
        'didn\'t touch.'
      : '') +
    ' Call propose_categories with exactly six entries, one per position 1 through 6.';
  const user = `CONVERSATION SO FAR:\n${transcriptText(transcript)}`;
  return { system, user };
}

// D-103: 1 to [maxAllowed] habits for one category (maxAllowed itself
// never exceeds 3), conditioned on its essence when one exists (D-010:
// cat4-cat6 leave setup without one — falls back to name-only, degrading
// without a placeholder). A fixed schema can't express "as many as
// actually earn a place, up to a per-call ceiling" — habitsTool()
// generates the schema per call so minItems/maxItems reflect the budget
// setup_screen.dart computed for this specific category (see D-103's
// cross-category reservation, which is what keeps a 6-category pyramid
// at 10 habits total even though each category alone could ask for 3).
// D-052: found live 2026-09-07 — 3-5 habits at up to 120 chars each read
// as too many, too long. Tightened to at most 3, ~5 words apiece
// (maxLength 40 is roomy for that without permitting a full sentence to
// sneak through) — D-103 then made the floor 1, not a fixed 2, since a
// single well-chosen habit can be all a category actually needs.
export function habitsTool(maxAllowed) {
  const max = Math.min(3, Math.max(1, Number(maxAllowed) || 3));
  return {
    name: 'propose_habits',
    description:
      `Propose between 1 and ${max} concrete daily habits for one category — only as many as will ` +
      'genuinely move the needle for this value, each around five words.',
    input_schema: {
      type: 'object',
      properties: {
        habits: {
          type: 'array',
          minItems: 1,
          maxItems: max,
          items: { type: 'string', minLength: 1, maxLength: 40 },
        },
      },
      required: ['habits'],
    },
  };
}

export function buildDeriveHabitsPrompt({ categoryName, essence, existingHabits = [], maxAllowed = 3 }) {
  const name = sanitize(categoryName, 60);
  const essenceText = essence ? sanitize(essence, 400) : null;
  const blacklist = (existingHabits || []).map((h) => sanitize(h, 80));
  const max = Math.min(3, Math.max(1, Number(maxAllowed) || 3));
  const system =
    'You propose daily habits for one category of someone\'s life pyramid. ' +
    (essenceText
      ? `Their own words for why this category matters to them: "${essenceText}" — let this shape which habits you propose, not just the category name.`
      : 'No stated reason exists for this category yet — propose from the category name alone, and do not invent one.') +
    ' Each habit is a short, concrete, dailyable action someone can check off — around five words, never a full ' +
    'sentence, never a vague aspiration like "be healthier" or "improve relationships". ' +
    (blacklist.length
      ? `Never repeat or closely restate any of these already-chosen habits: ${blacklist.join('; ')}.`
      : '') +
    ` Propose only as many as will genuinely move the needle for this specific value — a single well-chosen ` +
    `habit beats three padded ones. Call propose_habits with 1 to ${max} habits.`;
  const user = `Category: '${name}'`;
  return { system, user };
}

// D-055/D-118: the vision statement — written by the Council collectively
// (not any one advisor's persona), from whatever essences exist and, when
// given, the conversation transcript, in the person's own specifics.
// D-118 reverses D-055's original "no fixed template opener" call: the
// owner's explicit instruction this round was "it ought to start with
// 'I'm the kind of person that' and then it goes on like that." D-055's
// own rationale for forbidding a fixed opener (P-4's anti-rote-formula
// principle — a template phrase is what resonance work exists to avoid)
// still has real force, and is recorded here rather than silently
// discarded; the owner's explicit, repeated instruction is what overrides
// it. THE OUTPUT now always opens with that exact phrase.
// D-114: essences are optional — a caller with none yet (D-118's own new
// early call, right after the opening conversation, before any category
// essence exists) still gets a real vision statement, drawn from the
// transcript alone. When either essences or transcript is genuinely
// empty, the user message says so plainly rather than rendering an empty
// "REFERENCE" section with nothing after the colon — the same explicit-
// framing discipline D-108 established for an empty conversationHistory.
export function buildVisionStatementPrompt({ essences, transcript }) {
  const essenceLines = (essences || [])
    .map((e) => `- ${sanitize(e.categoryName, 60)}: "${sanitize(e.essence, 400)}"`)
    .join('\n');
  const system =
    'You write exactly one thing: a short vision statement, referred to below as THE OUTPUT. You are not ' +
    'a participant in any conversation shown to you — you do not reply to it, continue it, or add another ' +
    'turn to it. Any conversation given is reference material only. THE OUTPUT is the Council\'s ' +
    'synthesis, in the person\'s own language and specifics, of who they are becoming — drawn directly ' +
    'from their essences (their own words for why each category matters to them), when given, and, ' +
    'when given, what they said in conversation. THE OUTPUT always opens with exactly the words ' +
    '"I\'m the kind of person that" continuing directly into their own specifics — never a different ' +
    'opening, never a paraphrase of it. THE OUTPUT is two to four sentences total including that ' +
    'opener, first person, as if they are hearing their own truest thought said back to them — prose, ' +
    'never dialogue, never a speaker label, never a continuation of a conversation format. Your entire ' +
    'response is THE OUTPUT and nothing else — no preamble, no quotation marks around it, no commentary ' +
    'before or after it.';
  const essenceSection = (essences || []).length > 0
    ? `REFERENCE — THEIR ESSENCES:\n${essenceLines}\n\n`
    : 'REFERENCE — THEIR ESSENCES: none yet — write this from what they said in conversation below ' +
      'alone, before any category essence has been captured.\n\n';
  const transcriptSection = (transcript || []).length > 0
    ? `REFERENCE — THE CONVERSATION (for context only; do not continue or reply to it):\n${transcriptText(transcript)}\n\n`
    : 'REFERENCE — THE CONVERSATION: none — this is a regeneration from their current pyramid, not ' +
      'written during a live conversation. Draw only on their essences above.\n\n';
  const user =
    essenceSection +
    transcriptSection +
    'Now write THE OUTPUT: their vision statement, and only that.';
  return { system, user };
}
