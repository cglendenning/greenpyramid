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
  const historyText = safeHistory.length > 0
    ? '\n\nCHAT SO FAR:\n' + safeHistory.map(m => {
        const name = m.advisor === 'user' ? 'You' : (ADVISORS[m.advisor]?.name || String(m.advisor));
        return `${name}: ${sanitize(m.text, 500)}`;
      }).join('\n')
    : '';

  const userMessage = `USER CONTEXT:\n${contextLines}${historyText}\n\n${advisor.name}:`;

  return { advisor, systemText, userMessage };
}
