// Pure logic for the Council backend route (D-027/D-028/D-040), split out
// from index.js so it's testable without spinning up Express or Firebase
// Admin. index.js imports these directly; there is no duplicate copy.

// Strips characters that can break out of prompt quote delimiters or inject
// instructions. Ported verbatim from Kansei's backend/src/utils/sanitize.js
// (D-026's sibling defense — AiGuard.sanitizeField does the same job
// client-side; this is the server-side backstop).
export function sanitize(value, maxLen = 500) {
  if (value == null) return '';
  return String(value)
    .replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g, '')
    .replace(/"/g, '“')
    .replace(/'/g, '’')
    .trim()
    .slice(0, maxLen);
}

// D-029: advisors are stances, not domains — every advisor may probe any
// domain; nothing here is domain-specific. Persona prose ported verbatim
// from Kansei (II-K) so each advisor stays recognizably themselves.
export const ADVISORS = {
  mira: {
    name: 'Mira', title: 'The Heart', trait: 'caring',
    personality: "You are warm and perceptive, with a light touch of humor. You often catch what's beneath the surface. You tend to ask a question rather than just assert. Occasionally you land on a brief, quiet metaphor. You don't sentimentalize — your warmth has substance. You are naturally a bit more expressive than the others — your replies tend toward a full sentence or two, though sometimes a single warm phrase is all that's needed.",
  },
  kenji: {
    name: 'Kenji', title: 'The Anchor', trait: 'consistent',
    personality: "You are dry, measured, and occasionally wry. You speak plainly and are comfortable with very short responses — sometimes a single word or a brief phrase is your whole contribution. You don't rush to fill silence. Your humor is quiet and deadpan. You sometimes reference patterns you've noticed over time.",
  },
  noa: {
    name: 'Noa', title: 'The Edge', trait: 'competent',
    personality: "You are sharp, fast-thinking, and slightly playful about your directness. You vary a lot — sometimes a quick one-liner, sometimes a full crisp sentence when you've spotted something worth naming. You don't hedge. You have a quick, light wit. You enjoy a good plan the way someone enjoys a clean solve.",
  },
  eli: {
    name: 'Eli', title: 'The Compass', trait: 'morally principled',
    personality: "You are philosophical but not heavy. You often open with a question or a short observation that cracks something open. You have quiet warmth underneath the principled exterior. You sometimes just ask a single question and leave space. You notice what's unsaid. Occasionally 'worth sitting with' is your whole reply.",
  },
};

// D-073: no slider UI exists yet — sliderValue is always the caller's
// default (0.5) in practice, which is what makes each advisor's system
// prompt fully static and therefore cacheable (D-041). The backend still
// accepts the parameter so adding the control later needs no server change.
export function biasInstruction(trait, sliderValue) {
  const v = Number(sliderValue);
  const value = Number.isFinite(v) ? v : 0.5;
  if (value <= 0.05) return `Do not apply any special emphasis toward ${trait}. Speak as a balanced, even-handed voice — your character remains, but your trait does not colour every response.`;
  if (value >= 0.95) return `Let ${trait} saturate every word of your response. It is the primary lens through which you see everything — do not let other considerations overshadow it.`;
  if (value >= 0.75) return `Lean meaningfully toward ${trait} in your response, though remain a complete voice.`;
  if (value <= 0.25) return `Apply only a very faint emphasis toward ${trait}; be mostly even-handed.`;
  return `Express your natural ${trait} character — not overwhelming, but clearly present.`;
}

// D-028: builds the system prompt (the cacheable stable prefix, D-041) and
// the per-turn user message (category context + trailing chat history) for
// one advisor turn. Exported so index.js's route handler stays a thin
// HTTP/Anthropic-SDK wrapper around logic that's directly testable here.
export function buildAdvisorTurnPrompt({
  advisorKey,
  sliderValue = 0.5,
  categoryContext = {},
  conversationHistory = [],
}) {
  const advisor = ADVISORS[advisorKey];
  if (!advisor) return null;

  const categoryName = sanitize(categoryContext.categoryName, 60);
  const categoryTier = Number(categoryContext.categoryTier) || null;
  const priorEssence = categoryContext.priorEssence
    ? sanitize(categoryContext.priorEssence, 400)
    : null;

  const otherAdvisors = Object.entries(ADVISORS)
    .filter(([k]) => k !== advisorKey)
    .map(([, v]) => `- ${v.name} (${v.title}): ${v.trait}`)
    .join('\n');

  const systemText =
    `You are ${advisor.name}, ${advisor.title} — one of four advisors in a live group chat helping someone clarify why a part of their life matters to them.\n\n` +
    `Your personality: ${advisor.personality}\n\n` +
    `${biasInstruction(advisor.trait, sliderValue)}\n\n` +
    `The other advisors are:\n${otherAdvisors}\n\n` +
    `This is a chat room — crisp, warm, a little levity is welcome. No speeches.\n` +
    `Vary your response length naturally based on your personality. Sometimes a single word or phrase is the right move. Sometimes a full sentence or two. Max 2 sentences.\n` +
    `Respond to what was just said. If the person themselves wrote (shown as You:), speak to them directly.\n` +
    `If they share their name, acknowledge it once naturally — do not repeat their name in every reply.\n` +
    `Otherwise address your fellow advisors, referring to the person in the third person.\n` +
    `Never wrap your response in quotation marks.`;

  const contextLines = [
    `Category: '${categoryName}'`,
    categoryTier ? `Tier: ${categoryTier}` : null,
    priorEssence ? `What this category has meant to them before: '${priorEssence}'` : null,
  ].filter(Boolean).join('\n');

  const safeHistory = (conversationHistory || []).slice(-30);
  // D-108: found live — with no history, the system prompt's "respond to
  // what was just said" has nothing to anchor to, and an empty history
  // was previously indistinguishable from "say something in this
  // ongoing conversation." Explicit framing here, not a systemText
  // change (D-041: the system block must stay a static, cacheable
  // per-advisor prefix — this varies per call, so it belongs in the
  // user message, the same discipline D-100's convergence nudge and
  // D-095's pyramid context already follow).
  const historyText = safeHistory.length > 0
    ? '\n\nCHAT SO FAR:\n' + safeHistory.map(m => {
        const name = m.advisor === 'user' ? 'You' : (ADVISORS[m.advisor]?.name || String(m.advisor));
        return `${name}: ${sanitize(m.text, 500)}`;
      }).join('\n')
    : '\n\nThis is the start of a fresh conversation about this category specifically — nothing ' +
      'said earlier, about a different category, is relevant here. Ask a genuine, warm, directed ' +
      'question about this category that helps them articulate why it matters to them personally. ' +
      'Do not react to or continue any other thread — this is an opening question, not a reply.';

  const userMessage = `USER CONTEXT:\n${contextLines}${historyText}\n\n${advisor.name}:`;

  return { advisor, systemText, userMessage };
}

// D-095: the general Council conversation (D-091) needed real grounding —
// found live, the placeholder ("Category: 'their life'") produced
// disconnected, sometimes non-sequitur replies, because buildAdvisorTurnPrompt
// above is fundamentally category-scoped framing repurposed for a
// conversation that isn't about any one category. This is its own prompt:
// the person has already defined their values (the pyramid exists); the
// advisors' job is living them out, not discovering them.
export function buildGeneralCouncilTurnPrompt({
  advisorKey,
  sliderValue = 0.5,
  pyramidContext = [],
  conversationHistory = [],
  nudgeConvergence = false,
}) {
  const advisor = ADVISORS[advisorKey];
  if (!advisor) return null;

  const otherAdvisors = Object.entries(ADVISORS)
    .filter(([k]) => k !== advisorKey)
    .map(([, v]) => `- ${v.name} (${v.title}): ${v.trait}`)
    .join('\n');

  const systemText =
    `You are ${advisor.name}, ${advisor.title} — one of four advisors in a live group chat, helping ` +
    `someone live out values they've already defined, not discover new ones.\n\n` +
    `Your personality: ${advisor.personality}\n\n` +
    `${biasInstruction(advisor.trait, sliderValue)}\n\n` +
    `The other advisors are:\n${otherAdvisors}\n\n` +
    `Ground your advice in their actual pyramid of values (given in the message below) whenever it's ` +
    `relevant — connect what they're struggling with or asking about to the specific category and ` +
    `essence it touches, rather than generic encouragement. This is a chat room — crisp, warm, a little ` +
    `levity is welcome. No speeches.\n` +
    `Vary your response length naturally based on your personality. Sometimes a single word or phrase is ` +
    `the right move. Sometimes a full sentence or two. Max 2 sentences.\n` +
    `Respond to what was just said. If the person themselves wrote (shown as You:), speak to them ` +
    `directly.\n` +
    `Otherwise address your fellow advisors, referring to the person in the third person.\n` +
    // D-100: found live — a direct question about the Council itself got
    // sidestepped in favor of continuing the diagnostic thread. A relevance-
    // based advisor-selection mechanism was considered and rejected: it
    // would require deciding the speaking advisor dynamically, which
    // conflicts with D-041's caching (this system block is cacheable only
    // because it's a fixed, known persona per call) for no benefit this
    // instruction doesn't already deliver.
    `If their last message is a direct question about you, the Council, or what kind of help you can ` +
    `offer, answer it plainly, in your own voice, before continuing any diagnostic thread — never let a ` +
    `direct question go unanswered while you pursue your own line of thought.\n` +
    // D-100: found live — a real, evidence-backed connection to the user's
    // own stated essence was hedged ("probably") as if it were a guess.
    `When you connect what they're saying to something they've told you before — their essence, another ` +
    `category — say it with confidence. That connection is real evidence, not a guess; avoid hedges like ` +
    `"probably" or "I think" when you're drawing on what they've actually told you.\n` +
    `Never wrap your response in quotation marks.`;

  // D-041: kept out of the system prompt, same discipline buildAdvisorTurnPrompt
  // follows for categoryContext — the pyramid is user-specific, so it belongs
  // in the per-turn user message, not the cacheable stable system prefix.
  const pyramidText = (pyramidContext || []).length > 0
    ? pyramidContext.map((c) => {
        const essenceText = c.essence ? ` — "${sanitize(c.essence, 300)}"` : '';
        return `- [${sanitize(c.tier || '', 20)}] ${sanitize(c.name, 24)}${essenceText}`;
      }).join('\n')
    : '(no pyramid yet)';

  const safeHistory = (conversationHistory || []).slice(-30);
  const historyText = safeHistory.length > 0
    ? safeHistory.map(m => {
        const name = m.advisor === 'user' ? 'You' : (ADVISORS[m.advisor]?.name || String(m.advisor));
        return `${name}: ${sanitize(m.text, 500)}`;
      }).join('\n')
    : '(nothing yet)';

  // D-100: the push toward a concrete next step lives here, in the
  // per-turn user message, rather than in systemText — a turn-count-gated
  // instruction in the cached system block would vary the "stable" prefix
  // every time the gate flips, defeating D-041's caching for every advisor.
  // The user message already varies per turn (conversation history), so
  // this costs nothing extra it wasn't already paying.
  const convergenceLine = nudgeConvergence
    ? '\n\n(This conversation has gone on a while. If a real, specific pattern is clear, propose one ' +
      'concrete thing to try differently instead of another question.)'
    : '';

  const userMessage =
    `THEIR PYRAMID OF VALUES:\n${pyramidText}\n\nCHAT SO FAR:\n${historyText}${convergenceLine}\n\n${advisor.name}:`;

  return { advisor, systemText, userMessage };
}

// D-090: setup is now a one-on-one conversation with Mira alone, not the
// four-advisor group chat buildAdvisorTurnPrompt above builds — that
// mechanic moved to the general Council conversation (D-091) instead of
// being deleted. Mira asks a few genuine follow-up questions, then signals
// she has enough to build the pyramid via a forced tool call (readyToBuild)
// rather than free text the client would have to parse intent out of.
//
// D-093: [existingCategories] switches this from "gathering material to
// build a pyramid" to "refining a pyramid already proposed" — the owner
// explicitly wants "not quite right" to refine what's there, never discard
// it and start over.
export function buildSetupAdvisorTurnPrompt({
  sliderValue = 0.5,
  conversationHistory = [],
  existingCategories = null,
}) {
  const advisor = ADVISORS.mira;

  const safeHistory = (conversationHistory || []).slice(-30);
  const historyText = safeHistory.length > 0
    ? safeHistory.map((m) => {
        const name = m.advisor === 'user' ? 'You' : advisor.name;
        return `${name}: ${sanitize(m.text, 500)}`;
      }).join('\n')
    : '(nothing yet)';

  const refining = Array.isArray(existingCategories) && existingCategories.length > 0;
  const existingText = refining
    ? existingCategories
        .map((c) => `- ${sanitize(c.name, 24)}: ${sanitize(c.description || '', 140)}`)
        .join('\n')
    : null;

  const roleInstruction = refining
    ? `You already proposed a pyramid of six categories for this person:\n${existingText}\n\n` +
      `They said something about it wasn't quite right. Find out specifically what — ask focused ` +
      `questions about what feels off, not the general "what energizes you" opening questions from ` +
      `before. You are refining the existing pyramid, not starting over.`
    : `This is the very start of their relationship with the app. Ask genuine, warm follow-up ` +
      `questions about what energizes them and what they want more of in their life.`;

  const readyInstruction = refining
    ? `Once you understand what to adjust, set readyToBuild to true and let reply be a brief, warm ` +
      `closing line telling them you're about to refine it — never a question in that case.`
    : `After a few exchanges — enough to have real, specific material, but not so many it drags — you ` +
      `will have enough to build a pyramid that is actually theirs. When you do, set readyToBuild to ` +
      `true and let reply be a brief, warm closing line telling them you're about to build it — never ` +
      `a question in that case.`;

  const systemText =
    `You are Mira, The Heart — having a one-on-one conversation with someone, ` +
    `before building their personal pyramid of values and the habits that ` +
    `support each one.\n\n` +
    `Your personality: ${advisor.personality}\n\n` +
    `${biasInstruction(advisor.trait, sliderValue)}\n\n` +
    `${roleInstruction} One question or reflection at a time — never a list. ` +
    `Max 2 sentences.\n` +
    `${readyInstruction}\n` +
    `Never wrap your response in quotation marks.`;

  const userMessage = `CONVERSATION SO FAR:\n${historyText}\n\n${advisor.name}:`;

  return { advisor, systemText, userMessage };
}

// D-092: how many advisor turns are already in the conversation — shared
// by [applyPacingReassurance] below (Mira's solo setup turns) and, despite
// the name, also by index.js's D-100 convergence-nudge gate for the
// general Council's four-advisor turns. Same computation either way:
// advisor turns, not user messages.
export function countMiraTurns(conversationHistory) {
  return (conversationHistory || []).filter((m) => m.advisor !== 'user').length;
}

// D-092: found live — asking the model to weave a pacing reassurance into
// its own reply (the original approach) was not reliably followed once the
// conversation ran several turns deep; the owner hit five real questions
// with zero reassurance and had to ask directly how much longer this would
// go. This replaces that with a deterministic, server-applied suffix —
// guaranteed to appear once Mira has asked two questions without being
// ready, rather than left to the model's discretion. Never applied to a
// closing turn (readyToBuild: true), which is visibly ending on its own
// and needs no reassurance. Rotates through a small fixed set so a long
// conversation doesn't repeat the exact same phrase every turn.
const PACING_SUFFIXES = [
  " We're close — just a bit more.",
  ' Almost there.',
  " Not much further to go.",
];

export function applyPacingReassurance(reply, { turnsSoFar, readyToBuild }) {
  if (readyToBuild || turnsSoFar < 2) return reply;
  const suffix = PACING_SUFFIXES[turnsSoFar % PACING_SUFFIXES.length];
  return `${(reply || '').trim()}${suffix}`;
}

// D-090: forced tool-use schema for the solo setup turn above — the
// structured twin of the group-chat's free-text reply, since a boolean
// intent signal has to come back as data, not something parsed out of prose.
export const SETUP_TURN_TOOL = {
  name: 'setup_turn',
  description:
    "Mira's next line in the one-on-one setup conversation, plus whether " +
    'she now has enough to build or refine the pyramid of values and habits.',
  input_schema: {
    type: 'object',
    properties: {
      reply: {
        type: 'string',
        minLength: 1,
        maxLength: 400,
        description: 'Mira\'s next conversational line — a question or a closing line, never both.',
      },
      readyToBuild: {
        type: 'boolean',
        description: 'True once Mira has enough specific, personal material to build the pyramid.',
      },
    },
    required: ['reply', 'readyToBuild'],
  },
};

// Claude Opus 5 can return a `thinking` content block ahead of the `text`
// block even without thinking explicitly requested — indexing content[0]
// blindly grabbed the thinking block on a live call and silently sent an
// empty reply. Finds the first text block regardless of position; empty
// string (not a throw) if none exists, so the caller can treat "no text
// came back" as its own error rather than serving a blank reply.
export function extractReplyText(content) {
  const block = (content || []).find((b) => b?.type === 'text');
  return block?.text ?? '';
}
