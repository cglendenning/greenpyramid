// D-039: notifications fire in the user's local time. The scheduled job
// runs frequently (every SCHEDULE_INTERVAL_MINUTES) in UTC; this decides,
// per account, whether *this* run falls inside one of the three daily
// local-time windows — the only way a fixed-cadence UTC cron can serve
// every timezone, including half-hour-offset ones (UTC+5:30 etc.), without
// per-timezone cron entries.

// D-023: same three-times-daily cadence as the existing local notification
// times (settings.dart: 9am / 12pm / 8pm).
export const DAILY_SLOTS = [
  { hour: 9, minute: 0 },
  { hour: 12, minute: 0 },
  { hour: 20, minute: 0 },
];

export const SCHEDULE_INTERVAL_MINUTES = 15;

// Exported for tests; throws on an invalid IANA timezone string, which the
// caller treats as "never matches" rather than guessing a default.
export function localTimeParts(timezone, now = new Date()) {
  const fmt = new Intl.DateTimeFormat('en-US', {
    timeZone: timezone,
    hour: 'numeric',
    minute: 'numeric',
    hour12: false,
  });
  const parts = fmt.formatToParts(now);
  const hour = Number(parts.find((p) => p.type === 'hour').value) % 24;
  const minute = Number(parts.find((p) => p.type === 'minute').value);
  return { hour, minute };
}

// True if `now`, viewed in `timezone`, falls within SCHEDULE_INTERVAL_MINUTES
// after one of DAILY_SLOTS — i.e. this is the job run that should fire for
// this account right now.
export function isNotificationWindow(timezone, now = new Date()) {
  if (!timezone) return false;
  let hour, minute;
  try {
    ({ hour, minute } = localTimeParts(timezone, now));
  } catch {
    return false;
  }
  const minutesOfDay = hour * 60 + minute;
  return DAILY_SLOTS.some((slot) => {
    const target = slot.hour * 60 + slot.minute;
    const diff = Math.abs(minutesOfDay - target);
    return diff < SCHEDULE_INTERVAL_MINUTES;
  });
}

// D-036: lapsed accounts are excluded from the job entirely — no server or
// model cost. trialing and subscribed accounts both receive tailored
// notifications (D-021: a trial has identical capability to a subscription);
// pre_trial never reaches this in practice, since a pre_trial account has no
// completed setup and therefore no vision statement or categories to draw a
// tailored notification from.
export function isEligibleForTailoredNotification(profileData, now = new Date()) {
  if (!profileData) return false;
  if (profileData.entitlement === 'lapsed') return false;
  return isNotificationWindow(profileData.timezone, now);
}
