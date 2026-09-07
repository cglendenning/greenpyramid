/// Guardrail against raw model output reaching the screen unvalidated —
/// found live: a placeholder token like `<UNKNOWN>` surfaced as a category
/// name, verbatim, because nothing between a tool-call response and the
/// widget tree ever checked it looked like a real name. Deliberately
/// narrow: this catches placeholder/template leakage, not content quality
/// — P-4's resonance bar is judged elsewhere (`ResonanceService`), not here.
bool looksLikePlaceholder(String s) {
  final t = s.trim();
  if (t.isEmpty) return true;
  if (t.startsWith('<') && t.endsWith('>')) return true;
  const junk = {'unknown', 'undefined', 'null', 'n/a', 'none', 'todo'};
  return junk.contains(t.toLowerCase());
}
