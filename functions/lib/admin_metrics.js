// D-165: pure aggregation for the private admin surface. It consumes only
// bounded metadata and never returns user content or provider credentials.
//
// Billing note: Claude figures are the server's token-cost ledger at the
// configured model rates, not an Anthropic invoice. Google Cloud/Firebase
// invoice data is reported as unavailable until a read-only billing export is
// connected; an estimate must never be presented as an all-services total.

function number(value, fallback = 0) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function dateMs(value) {
  if (!value) return null;
  if (typeof value?.toDate === 'function') return dateMs(value.toDate());
  if (value instanceof Date) return Number.isFinite(value.getTime()) ? value.getTime() : null;
  if (typeof value === 'number') {
    const ms = value < 10_000_000_000 ? value * 1000 : value;
    return Number.isFinite(ms) ? ms : null;
  }
  const parsed = Date.parse(String(value));
  return Number.isFinite(parsed) ? parsed : null;
}

function monthKey(date) {
  return `${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, '0')}`;
}

function addUser(users, uidHash) {
  if (typeof uidHash !== 'string' || !uidHash) return null;
  if (!users.has(uidHash)) {
    users.set(uidHash, {
      uidHash,
      spendAllTimeUsd: 0,
      spendCurrentMonthUsd: 0,
      aiCalls: 0,
      entitlement: 'pre_trial',
      setupComplete: false,
      createdAtMs: null,
      trialStartedAtMs: null,
      subscriptionAtMs: null,
      events: new Map(),
    });
  }
  return users.get(uidHash);
}

function applyProfile(user, profile, currentMonth) {
  if (!user || !profile) return;
  const spendByMonth = profile.spendByMonth && typeof profile.spendByMonth === 'object'
    ? profile.spendByMonth
    : null;
  if (spendByMonth) {
    user.spendAllTimeUsd = Object.values(spendByMonth)
      .reduce((sum, value) => sum + number(value), 0);
    user.spendCurrentMonthUsd = number(spendByMonth[currentMonth]);
  } else {
    // Older profiles only have the running ledger field. Its scope is the
    // stored month, so it is not silently relabeled as historical all-time.
    user.spendAllTimeUsd = number(profile.totalSpendUsd);
    user.spendCurrentMonthUsd = profile.spendMonthKey === currentMonth
      ? number(profile.totalSpendUsd)
      : 0;
  }
  user.aiCalls = number(profile.aiCalls);
  if (typeof profile.entitlement === 'string') user.entitlement = profile.entitlement;
  user.setupComplete = user.setupComplete || profile.setupComplete === true || Boolean(profile.setupCompletedAt);
  user.createdAtMs = user.createdAtMs ?? dateMs(profile.createdAt);
  user.trialStartedAtMs = user.trialStartedAtMs ?? dateMs(profile.trialStartedAt);
  user.subscriptionAtMs = user.subscriptionAtMs ?? dateMs(profile.subscriptionEventTimestampMs);
}

function applyAccount(user, account) {
  if (!user || !account) return;
  user.setupComplete = user.setupComplete || account.setupComplete === true ||
    Boolean(account.setupCompletedAt || account.setupCompletionId);
  user.trialStartedAtMs = user.trialStartedAtMs ?? dateMs(account.trialStartedAt);
}

function applyAuthUser(user, authUser) {
  if (!user || !authUser) return;
  user.createdAtMs = user.createdAtMs ?? dateMs(authUser.createdAt);
}

function recordEvent(user, event) {
  if (!user || !event?.eventName) return;
  const name = String(event.eventName);
  if (!user.events.has(name)) user.events.set(name, []);
  const times = user.events.get(name);
  const at = dateMs(event.occurredAt);
  if (at != null) times.push(at);
  else if (times.length === 0) times.push(null);
  if (name === 'setup_complete') user.setupComplete = true;
  if (name === 'trial_started' && at != null) {
    user.trialStartedAtMs = user.trialStartedAtMs == null ? at : Math.min(user.trialStartedAtMs, at);
  }
  if (name === 'subscription_started' && at != null) {
    user.subscriptionAtMs = user.subscriptionAtMs == null ? at : Math.min(user.subscriptionAtMs, at);
  }
}

function firstEventAt(user, eventName) {
  const values = user.events.get(eventName) || [];
  const known = values.filter((value) => value != null);
  return known.length ? Math.min(...known) : null;
}

function ratio(numerator, denominator) {
  return denominator > 0 ? numerator / denominator : 0;
}

function mean(values) {
  return values.length ? values.reduce((sum, value) => sum + value, 0) / values.length : null;
}

function usersCreatedByDay(users, now) {
  const today = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate());
  const days = Array.from({ length: 30 }, (_, index) => {
    const date = new Date(today - (29 - index) * 86_400_000);
    return date.toISOString().slice(0, 10);
  });
  const counts = new Map(days.map((day) => [day, 0]));
  for (const user of users) {
    if (user.createdAtMs == null) continue;
    const day = new Date(user.createdAtMs).toISOString().slice(0, 10);
    if (counts.has(day)) counts.set(day, counts.get(day) + 1);
  }
  return days.map((date) => ({ date, count: counts.get(date) }));
}

export function buildAdminMetrics({
  profiles = [],
  accounts = [],
  authUsers = [],
  telemetry = [],
  now = new Date(),
} = {}) {
  const currentMonth = monthKey(now);
  const users = new Map();
  for (const authUser of authUsers) {
    const user = addUser(users, authUser.uidHash);
    applyAuthUser(user, authUser);
  }
  for (const account of accounts) {
    const user = addUser(users, account.uidHash);
    applyAccount(user, account);
  }
  for (const profile of profiles) {
    const user = addUser(users, profile.uidHash);
    applyProfile(user, profile, currentMonth);
  }
  for (const event of telemetry) recordEvent(addUser(users, event.uidHash), event);

  const allUsers = [...users.values()];
  const downloadedUsers = allUsers.filter((user) => user.createdAtMs != null).length;
  const setupStartedUsers = allUsers.filter((user) => user.events.has('setup_begin')).length;
  const linkedUsers = allUsers.filter((user) => user.events.has('account_link')).length;
  const setupCompleteUsers = allUsers.filter((user) => user.setupComplete).length;
  const completedStartedUsers = allUsers.filter((user) =>
    user.events.has('setup_begin') && user.setupComplete).length;
  const setupAbandonedUsers = allUsers.filter((user) => user.events.has('setup_begin') && !user.setupComplete).length;
  const trialStartedUsers = allUsers.filter((user) => user.trialStartedAtMs != null || user.events.has('trial_started')).length;
  const preTrialUsers = allUsers.filter((user) => user.entitlement === 'pre_trial').length;
  const trialingUsers = allUsers.filter((user) => user.entitlement === 'trialing').length;
  const lapsedUsers = allUsers.filter((user) => user.entitlement === 'lapsed').length;
  const subscribedUsers = allUsers.filter((user) => user.entitlement === 'subscribed').length;

  const downloadToSubscriptionDays = [];
  const trialToSubscriptionDays = [];
  for (const user of allUsers) {
    const subscriptionAt = user.subscriptionAtMs ?? firstEventAt(user, 'subscription_started');
    const trialAt = user.trialStartedAtMs ?? firstEventAt(user, 'trial_started');
    if (subscriptionAt != null && user.createdAtMs != null && subscriptionAt >= user.createdAtMs) {
      downloadToSubscriptionDays.push((subscriptionAt - user.createdAtMs) / 86_400_000);
    }
    if (subscriptionAt != null && trialAt != null && subscriptionAt >= trialAt) {
      trialToSubscriptionDays.push((subscriptionAt - trialAt) / 86_400_000);
    }
  }

  const totalClaudeUsd = allUsers.reduce((sum, user) => sum + user.spendAllTimeUsd, 0);
  const currentMonthClaudeUsd = allUsers.reduce((sum, user) => sum + user.spendCurrentMonthUsd, 0);
  const eventCounts = new Map();
  const screenUsers = new Map();
  for (const event of telemetry) {
    const name = typeof event.eventName === 'string' ? event.eventName : '';
    eventCounts.set(name, (eventCounts.get(name) || 0) + 1);
    if (name === 'screen_open' && event.screenKey) {
      const key = String(event.screenKey).slice(0, 96);
      if (!screenUsers.has(key)) screenUsers.set(key, new Set());
      if (event.uidHash) screenUsers.get(key).add(event.uidHash);
    }
  }
  const screenKeys = [...screenUsers.keys()].map((screenKey) => ({
    screenKey,
    opens: telemetry.filter((event) => event.eventName === 'screen_open' && event.screenKey === screenKey).length,
    uniqueUsers: screenUsers.get(screenKey).size,
  }));
  const topUsers = [...allUsers]
    .sort((a, b) => b.spendAllTimeUsd - a.spendAllTimeUsd)
    .slice(0, 5)
    .map((user) => ({ uidHash: user.uidHash, spendUsd: user.spendAllTimeUsd, aiCalls: user.aiCalls }));

  return {
    generatedAt: now.toISOString(),
    funnel: {
      anonymousStarts: setupStartedUsers,
      accountLinks: linkedUsers,
      setupCompletions: setupCompleteUsers,
      trials: trialStartedUsers,
      subscriptions: subscribedUsers,
      linkRate: ratio(linkedUsers, setupStartedUsers),
      completionRate: ratio(
        setupStartedUsers > 0 ? completedStartedUsers : setupCompleteUsers,
        setupStartedUsers,
      ),
      subscriptionRate: ratio(subscribedUsers, trialStartedUsers),
    },
    cohorts: {
      downloadedUsers,
      setupStartedUsers,
      setupAbandonedUsers,
      setupCompleteUsers,
      preTrialUsers,
      trialingUsers,
      lapsedUsers,
      subscribedUsers,
    },
    conversion: {
      setupStartRate: ratio(setupStartedUsers, downloadedUsers),
      setupCompletionRate: ratio(
        setupStartedUsers > 0 ? completedStartedUsers : setupCompleteUsers,
        setupStartedUsers,
      ),
      trialToSubscriptionRate: ratio(subscribedUsers, trialStartedUsers),
      downloadToSubscriptionRate: ratio(subscribedUsers, downloadedUsers),
      meanDownloadToSubscriptionDays: mean(downloadToSubscriptionDays),
      meanTrialToSubscriptionDays: mean(trialToSubscriptionDays),
      downloadToSubscriptionSample: downloadToSubscriptionDays.length,
      trialToSubscriptionSample: trialToSubscriptionDays.length,
    },
    usersCreatedByDay: usersCreatedByDay(allUsers, now),
    screenUsage: screenKeys,
    cost: {
      month: currentMonth,
      claude: {
        allTimeUsd: totalClaudeUsd,
        currentMonthUsd: currentMonthClaudeUsd,
        basis: 'server_token_ledger',
        confidence: 'ledger_not_invoice',
      },
      firebase: { state: 'not_connected', amountUsd: null, basis: 'cloud_billing_export_required' },
      allServices: { state: 'incomplete', amountUsd: null, missingSources: ['firebase_google_cloud'] },
      // Compatibility field; the admin UI uses the explicitly named fields.
      totalUsd: totalClaudeUsd,
      councilCalls: eventCounts.get('council_call') || 0,
      notificationCalls: eventCounts.get('notification_call') || 0,
    },
    topUsers,
  };
}
