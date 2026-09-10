// D-124: the batched end-of-day check-in's server-side timing logic.
// Distinct from D-036/notification_schedule.js's fixed three-times-daily
// cadence — here the "when" is per-account, per-day, and data-dependent
// (the latest scheduled_time among today's active scheduled habits), not
// a fixed clock slot, so it can't reuse isNotificationWindow's narrow
// fixed-slot check. Instead an explicit "already sent today" guard
// (lastSentDate) does the same job a narrow window does for a fixed slot:
// stopping a repeat fire on every later 15-minute run of the same day.

const DAY_FIELDS = [
  'sunday', 'monday', 'tuesday', 'wednesday',
  'thursday', 'friday', 'saturday',
];

function isTruthyFlag(v) {
  return v != null && v !== '0' && v !== 'false' && v !== '';
}

// D-039: "today" and "now" both read in the account's own local
// timezone — a fixed-cadence UTC job must never decide a Tokyo account's
// day, or its day-of-week, using another timezone's clock. Throws on an
// invalid IANA timezone string, which callers treat as "never matches"
// rather than guessing a default (same contract as notification_schedule.js's
// localTimeParts).
export function localDateParts(timezone, now = new Date()) {
  const fmt = new Intl.DateTimeFormat('en-US', {
    timeZone: timezone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: 'numeric',
    minute: 'numeric',
    hour12: false,
    weekday: 'long',
  });
  const parts = fmt.formatToParts(now);
  const get = (type) => parts.find((p) => p.type === type).value;
  const dateString = `${get('year')}-${get('month')}-${get('day')}`;
  const hour = Number(get('hour')) % 24;
  const minute = Number(get('minute'));
  const weekday = get('weekday').toLowerCase();
  return { dateString, hour, minute, weekday };
}

function parseScheduledMinutes(scheduledtime) {
  if (typeof scheduledtime !== 'string') return null;
  const parts = scheduledtime.split(':');
  if (parts.length !== 2) return null;
  const hour = Number(parts[0]);
  const minute = Number(parts[1]);
  if (Number.isNaN(hour) || Number.isNaN(minute)) return null;
  return hour * 60 + minute;
}

// A habit is part of today's batch when it has a scheduled_time AND
// today's day-of-week flag (the same field D-123's own scheduling screen
// reads) is true — mirrors HabitScheduleRow.activeOn on the client.
function isScheduledActiveOn(task, weekday) {
  if (!DAY_FIELDS.includes(weekday)) return false;
  if (!task || !task.scheduledtime) return false;
  return isTruthyFlag(task[weekday]);
}

// The latest scheduled_time among today's active scheduled habits, in
// minutes-of-day local time — null if there are none.
export function latestScheduledMinutes(tasks, weekday) {
  let latest = null;
  for (const task of tasks) {
    if (!isScheduledActiveOn(task, weekday)) continue;
    const minutes = parseScheduledMinutes(task.scheduledtime);
    if (minutes == null) continue;
    if (latest == null || minutes > latest) latest = minutes;
  }
  return latest;
}

// The specific scheduled+active habits today's check-in is about — the
// push payload's own source of truth (D-124's acceptance criterion: "the
// push's payload names the specific habits it's asking about").
export function todaysScheduledHabits(tasks, weekday) {
  return tasks
      .filter((t) => isScheduledActiveOn(t, weekday))
      .map((t) => ({
        id: t.id,
        category: t.category ?? null,
        description: t.taskdescription ?? null,
        scheduledtime: t.scheduledtime,
      }));
}

// True exactly on the job run that should send today's batch check-in for
// this account: at least one habit is scheduled and active today, local
// "now" has reached or passed the latest such habit's time, and today's
// date hasn't already been sent (lastSentDate is the account's own
// previous send date, or undefined/null for an account that's never sent
// one).
export function shouldSendBatchCheckin({
  tasks,
  timezone,
  now = new Date(),
  lastSentDate,
}) {
  if (!timezone) return false;
  let dateString, hour, minute, weekday;
  try {
    ({ dateString, hour, minute, weekday } = localDateParts(timezone, now));
  } catch {
    return false;
  }
  if (lastSentDate === dateString) return false;

  const latest = latestScheduledMinutes(tasks, weekday);
  if (latest == null) return false;

  return hour * 60 + minute >= latest;
}
