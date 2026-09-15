// D-165: pure aggregation for the private admin surface. It consumes only
// bounded metadata and never returns user content or provider credentials.
export function buildAdminMetrics({ profiles = [], telemetry = [], now = new Date() }) {
  const users = new Map();
  for (const profile of profiles) {
    const uid = profile.uidHash || 'unknown';
    users.set(uid, {
      uidHash: profile.uidHash || uid,
      spendUsd: Number(profile.totalSpendUsd) || 0,
      aiCalls: Number(profile.aiCalls) || 0,
      entitlement: profile.entitlement || 'pre_trial',
      completed: Boolean(profile.setupComplete || profile.completedAt),
    });
  }
  const counts = new Map();
  const screenUsers = new Map();
  for (const event of telemetry) {
    const name = typeof event.eventName === 'string' ? event.eventName : '';
    counts.set(name, (counts.get(name) || 0) + 1);
    if (name === 'screen_open' && event.screenKey) {
      const key = String(event.screenKey).slice(0, 96);
      if (!screenUsers.has(key)) screenUsers.set(key, new Set());
      if (event.uidHash) screenUsers.get(key).add(event.uidHash);
    }
  }
  const anonymousStarts = counts.get('setup_begin') || 0;
  const accountLinks = counts.get('account_link') || 0;
  const setupCompletions = counts.get('setup_complete') || 0;
  const trials = counts.get('trial_started') || [...users.values()].filter((u) => u.entitlement === 'trialing').length;
  const subscriptions = counts.get('subscription_started') || [...users.values()].filter((u) => u.entitlement === 'subscribed').length;
  const ratio = (a, b) => b ? Math.min(1, a / b) : 0;
  const totalUsd = [...users.values()].reduce((sum, u) => sum + u.spendUsd, 0);
  const screenKeys = [...screenUsers.keys()].map((screenKey) => ({
    screenKey,
    opens: telemetry.filter((e) => e.eventName === 'screen_open' && e.screenKey === screenKey).length,
    uniqueUsers: screenUsers.get(screenKey).size,
  }));
  const topUsers = [...users.values()]
    .sort((a, b) => b.spendUsd - a.spendUsd)
    .slice(0, 5)
    .map(({ uidHash, spendUsd, aiCalls }) => ({ uidHash, spendUsd, aiCalls }));
  const month = now.toISOString().slice(0, 7);
  return {
    generatedAt: now.toISOString(),
    funnel: { anonymousStarts, accountLinks, setupCompletions, trials, subscriptions,
      linkRate: ratio(accountLinks, anonymousStarts),
      completionRate: ratio(setupCompletions, accountLinks || anonymousStarts),
      subscriptionRate: ratio(subscriptions, trials || setupCompletions) },
    screenUsage: screenKeys,
    cost: { month, totalUsd, councilCalls: counts.get('council_call') || 0, notificationCalls: counts.get('notification_call') || 0 },
    topUsers,
  };
}
