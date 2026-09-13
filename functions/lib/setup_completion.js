// D-001: completion is server-acknowledged, linked-account-only and replayable.
export function validateSetupDraft(state) {
  const cs = state?.categories;
  if (!Array.isArray(cs) || cs.length !== 6) throw new Error('six_categories_required');
  const names = new Set(); const slots = new Set();
  for (const c of cs) {
    if (!Number.isInteger(c.position) || c.position < 1 || c.position > 6 || slots.has(c.position)) throw new Error('invalid_category_positions');
    if (typeof c.name !== 'string' || !c.name.trim() || c.name.length > 24 || c.name.trim().split(/\s+/).length > 2 || /<[^>]+>|\{\{/.test(c.name)) throw new Error('invalid_category_name');
    if (names.has(c.name.trim().toLowerCase())) throw new Error('duplicate_category_name');
    if (typeof c.description !== 'string' || !c.description.trim() || c.description.length > 140) throw new Error('invalid_category_description');
    names.add(c.name.trim().toLowerCase()); slots.add(c.position);
  }
  let total = 0;
  for (const c of cs) {
    const hs = state.habits?.[c.name];
    if (!Array.isArray(hs) || hs.length < 1 || hs.length > 2) throw new Error('initial_habit_coverage_required');
    if (hs.some(h => typeof h !== 'string' || !h.trim() || h.length > 40 || /<[^>]+>|\{\{/.test(h)) || new Set(hs.map(h => h.trim().toLowerCase())).size !== hs.length) throw new Error('invalid_habits');
    total += hs.length;
  }
  if (total > 10) throw new Error('initial_habit_limit');
  if (typeof state.vision !== 'string' || state.vision.length > 4000) throw new Error('invalid_vision');
  if (!Array.isArray(state.foundational) || state.foundational.length !== 3 || state.foundational.some(f => typeof (f.essence ?? '') !== 'string' || (f.essence ?? '').length > 1000)) throw new Error('invalid_explanations');
  return state;
}

export async function completeSetup(store, uid, sessionId, now = new Date()) {
  if (!/^[0-9a-f-]{36}$/i.test(sessionId)) throw new Error('invalid_session_id');
  const root = store.collection('users').doc(uid);
  const session = root.collection('councilSessions').doc(sessionId);
  const profile = root.collection('profile').doc('main');
  return store.runTransaction(async tx => {
    const [user, draft, existingProfile] = await Promise.all([tx.get(root), tx.get(session), tx.get(profile)]);
    const p = existingProfile.data() || {};
    const date = value => value == null ? null : (value.toDate?.() || new Date(value)).toISOString();
    const response = pending => ({requestId:sessionId, completionId:sessionId, entitlement:p.entitlement || 'pre_trial', trialGrantPending:pending, trialStartedAt:date(p.trialStartedAt), trialExpiresAt:date(p.trialExpiresAt)});
    if (user.data()?.setupCompletionId) {
      if (user.data().setupCompletionId !== sessionId) throw new Error('setup_already_complete');
      return response(p.trialGrantPending ?? true);
    }
    if (draft.data()?.type !== 'setup' || draft.data()?.isComplete) throw new Error('invalid_setup_session');
    const state = validateSetupDraft(draft.data()?.setupDraft?.state);
    const firstName = state.firstName;
    if (typeof firstName !== 'string' || !firstName.trim() || firstName.length > 100) throw new Error('first_name_required');
    tx.set(root, { setupCompletionId: sessionId, setupCompletedAt: now, setupComplete: true }, { merge: true });
    tx.set(session, { isComplete: true, completedAt: now }, { merge: true });
    tx.set(profile, {
      categories: state.categories.map(c => ({id:c.position, cat:c.name, description:c.description, position:c.position, created:now.toISOString(), activeEssence:state.foundational.find(f=>f.categoryId===c.position)?.essence ?? ''})), visionStatement: state.vision, firstName,
      setupComplete: true, trialGrantPending: true,
    }, { merge: true });
    return response(true);
  });
}
