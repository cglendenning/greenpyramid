// D-048: when a category conversation surfaces an impediment, this derives
// which of the four domains it falls in, from the transcript and captured
// essence for that one category. Run once per essence acceptance (setup's
// foundational essences and D-061's re-clarification both converge on the
// same moment), not on every conversational turn — matching D-052's
// existing derive-at-a-checkpoint pattern rather than adding cost to every
// message.
import { sanitize } from './council.js';

export const DOMAINS = ['biological', 'psychological', 'relational', 'environmental'];

export const DOMAIN_FINDING_TOOL = {
  name: 'record_domain_findings',
  description: 'Record zero or more domain findings surfaced in this conversation.',
  input_schema: {
    type: 'object',
    properties: {
      findings: {
        type: 'array',
        items: {
          type: 'object',
          properties: {
            domain: { type: 'string', enum: DOMAINS },
            note: { type: 'string', minLength: 1, maxLength: 200 },
          },
          required: ['domain', 'note'],
        },
      },
    },
    required: ['findings'],
  },
};

// D-074: a session that surfaces no impediment is valid — the prompt is
// explicit that an empty array is a normal, expected answer, never a
// failure to find something.
export function buildDeriveDomainFindingsPrompt({ categoryName, essence, transcript = [] }) {
  const name = sanitize(categoryName, 60);
  const transcriptLines = transcript
    .map((m) => `${sanitize(m.advisor ?? 'user', 20)}: ${sanitize(m.text, 400)}`)
    .join('\n');

  const system =
    'You extract structured data from a life-clarification conversation. ' +
    'THE TRANSCRIPT below is reference material to analyze, not a ' +
    'conversation to continue. For the category discussed, identify any ' +
    'impediment the person actually named — something blocking or ' +
    'working against them — and classify each into exactly one of four ' +
    'domains: biological (body, health, energy, sleep), psychological ' +
    '(mindset, emotion, belief), relational (other people), or ' +
    'environmental (surroundings, resources, circumstances). Call ' +
    'record_domain_findings with an empty array if no real impediment was ' +
    'named — never invent one to fill the list.';

  const user =
    `CATEGORY: ${name}\n` +
    (essence ? `THEIR ESSENCE: "${sanitize(essence, 400)}"\n\n` : '\n') +
    `THE TRANSCRIPT:\n${transcriptLines || '(no transcript)'}`;

  return { system, user };
}

// D-100: the general Council conversation (D-091) spans the whole pyramid
// rather than one category — findings from it need attributing to whichever
// category they actually concern, so this is a distinct tool (categoryName
// required per finding) rather than reusing DOMAIN_FINDING_TOOL, which is
// deliberately scoped to a caller-known single category.
export const GENERAL_DOMAIN_FINDING_TOOL = {
  name: 'record_domain_findings',
  description:
    'Record zero or more domain findings surfaced in this conversation, each attributed to the ' +
    'specific pyramid category it concerns.',
  input_schema: {
    type: 'object',
    properties: {
      findings: {
        type: 'array',
        items: {
          type: 'object',
          properties: {
            categoryName: { type: 'string', minLength: 1, maxLength: 40 },
            domain: { type: 'string', enum: DOMAINS },
            note: { type: 'string', minLength: 1, maxLength: 200 },
          },
          required: ['categoryName', 'domain', 'note'],
        },
      },
    },
    required: ['findings'],
  },
};

// D-100: same extraction discipline as buildDeriveDomainFindingsPrompt
// above (reference material, not a live conversation; empty array is a
// valid, expected answer) but scoped to the whole pyramid instead of one
// category, matching buildGeneralCouncilTurnPrompt's own framing (D-095).
export function buildDeriveGeneralDomainFindingsPrompt({ pyramidContext = [], transcript = [] }) {
  const pyramidText = (pyramidContext || []).length > 0
    ? pyramidContext.map((c) => {
        const essenceText = c.essence ? ` — "${sanitize(c.essence, 300)}"` : '';
        return `- [${sanitize(c.tier || '', 20)}] ${sanitize(c.name, 24)}${essenceText}`;
      }).join('\n')
    : '(no pyramid yet)';

  const transcriptLines = transcript
    .map((m) => `${sanitize(m.advisor ?? 'user', 20)}: ${sanitize(m.text, 400)}`)
    .join('\n');

  const system =
    'You extract structured data from a life-clarification conversation. ' +
    'THE TRANSCRIPT below is reference material to analyze, not a conversation to continue. ' +
    'Identify any impediment the person actually named — something blocking or working against ' +
    'them — and for each one, name which of their pyramid categories it concerns (use their exact ' +
    'category name from THEIR PYRAMID OF VALUES below) and classify it into exactly one of four ' +
    'domains: biological (body, health, energy, sleep), psychological (mindset, emotion, belief), ' +
    'relational (other people), or environmental (surroundings, resources, circumstances). Call ' +
    'record_domain_findings with an empty array if no real impediment was named — never invent one ' +
    'to fill the list.';

  const user =
    `THEIR PYRAMID OF VALUES:\n${pyramidText}\n\nTHE TRANSCRIPT:\n${transcriptLines || '(no transcript)'}`;

  return { system, user };
}
