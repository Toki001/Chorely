import { resolveLocalMinute, validateLocalDate } from "./local_time.js";

export interface RecurrenceRule {
  frequency: "daily" | "weekdays" | "weekly" | "monthly";
  startDate: string;
  endDate: string | null;
  count: number | null;
  weekdays: number[]; // ISO Monday=1 ... Sunday=7.
  monthDay: number | null;
  timing: {
    kind: "none" | "time" | "deadline" | "range";
    at: string | null;
    endAt: string | null;
    endDayOffset: number;
  };
  timezoneIana: string;
  rotation: {
    order: string[];
    policy: "preserve_turn" | "give_to_next_eligible";
  };
  exceptions: { date: string; excludedActorIds: string[] }[];
}
export interface RecurrenceSlot {
  date: string;
  ordinal: number;
  slotKey: string;
  plannedActorId: string;
  assignedActorIds: string[];
  status: "scheduled" | "skipped";
  reason:
    | "unavailable_assignee"
    | "substitute"
    | "clock_change_window"
    | "reviewer_unavailable"
    | null;
  timezoneIana: string;
  timingKind: string;
  requestedSchedule: {
    kind: string;
    date: string;
    at: string | null;
    startLocal: string | null;
    endLocal: string | null;
  };
  dueAtMillis: number | null;
  windowStartAtMillis: number | null;
  effectiveDueLocal: string | null;
  effectiveStartLocal: string | null;
  timeAdjusted: boolean;
}
const dayMillis = 86_400_000;
function epoch(date: string): number {
  validateLocalDate(date);
  return Date.parse(`${date}T00:00:00Z`);
}
export function addCivilDays(date: string, days: number): string {
  return new Date(epoch(date) + days * dayMillis).toISOString().slice(0, 10);
}
export function householdDate(nowMillis: number, zone: string): string {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: zone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(nowMillis);
  const get = (type: string) => parts.find((p) => p.type === type)!.value;
  return `${get("year")}-${get("month")}-${get("day")}`;
}
export function validateRule(rule: RecurrenceRule): void {
  const start = epoch(rule.startDate);
  if (!["daily", "weekdays", "weekly", "monthly"].includes(rule.frequency))
    throw new RangeError("Invalid frequency");
  if (rule.endDate !== null && epoch(rule.endDate) < start)
    throw new RangeError("End precedes start");
  if (
    rule.count !== null &&
    (!Number.isSafeInteger(rule.count) || rule.count < 1 || rule.count > 3660)
  )
    throw new RangeError("Count must be 1–3660");
  if (
    !Array.isArray(rule.weekdays) ||
    rule.weekdays.length > 7 ||
    new Set(rule.weekdays).size !== rule.weekdays.length ||
    rule.weekdays.some((d) => !Number.isInteger(d) || d < 1 || d > 7)
  )
    throw new RangeError("Invalid weekdays");
  if (rule.frequency === "weekdays" && rule.weekdays.length === 0)
    throw new RangeError("Select weekdays");
  if (
    rule.frequency === "monthly" &&
    (!Number.isInteger(rule.monthDay) ||
      rule.monthDay! < 1 ||
      rule.monthDay! > 31)
  )
    throw new RangeError("Invalid month day");
  if (
    !rule.rotation ||
    !Array.isArray(rule.rotation.order) ||
    rule.rotation.order.length < 1 ||
    rule.rotation.order.length > 20 ||
    new Set(rule.rotation.order).size !== rule.rotation.order.length ||
    rule.rotation.order.some(
      (id) => typeof id !== "string" || !/^[A-Za-z0-9_-]{1,128}$/.test(id),
    ) ||
    !["preserve_turn", "give_to_next_eligible"].includes(rule.rotation.policy)
  )
    throw new RangeError("Invalid rotation");
  if (
    !Array.isArray(rule.exceptions) ||
    rule.exceptions.length > 100 ||
    new Set(rule.exceptions.map((e) => e.date)).size !== rule.exceptions.length
  )
    throw new RangeError("Invalid exceptions");
  for (const exception of rule.exceptions) {
    epoch(exception.date);
    if (
      !Array.isArray(exception.excludedActorIds) ||
      exception.excludedActorIds.length > 20 ||
      new Set(exception.excludedActorIds).size !==
        exception.excludedActorIds.length ||
      exception.excludedActorIds.some((id) => !rule.rotation.order.includes(id))
    )
      throw new RangeError("Invalid exception assignee");
  }
  const t = rule.timing;
  if (!t || !["none", "time", "deadline", "range"].includes(t.kind))
    throw new RangeError("Invalid timing");
  const time = (v: unknown) =>
    typeof v === "string" && /^([01]\d|2[0-3]):[0-5]\d$/.test(v);
  if (t.kind !== "none" && !time(t.at)) throw new RangeError("Invalid time");
  if (
    t.kind === "range" &&
    (!time(t.endAt) ||
      !Number.isInteger(t.endDayOffset) ||
      t.endDayOffset < 0 ||
      t.endDayOffset > 7 ||
      (t.endDayOffset === 0 && t.endAt! <= t.at!) ||
      (t.endDayOffset === 7 && t.endAt! > t.at!))
  )
    throw new RangeError("Invalid window");
  // Validate timezone even for a no-time rule.
  if (typeof rule.timezoneIana !== "string" || !rule.timezoneIana.trim())
    throw new RangeError("A household timezone is required");
  new Intl.DateTimeFormat("en-US", { timeZone: rule.timezoneIana }).format(0);
}
function scheduled(rule: RecurrenceRule, date: string): boolean {
  const d = new Date(`${date}T00:00:00Z`);
  const weekday = d.getUTCDay() || 7;
  switch (rule.frequency) {
    case "daily":
      return true;
    case "weekdays":
      return rule.weekdays.includes(weekday);
    case "weekly":
      return (
        weekday === (new Date(`${rule.startDate}T00:00:00Z`).getUTCDay() || 7)
      );
    case "monthly":
      return d.getUTCDate() === rule.monthDay;
  }
}
export function previewRecurrence(
  rule: RecurrenceRule,
  fromDate: string,
  days: number,
  eligibleActorIds: ReadonlySet<string>,
): RecurrenceSlot[] {
  validateRule(rule);
  const from = epoch(fromDate);
  if (!Number.isInteger(days) || days < 1 || days > 31)
    throw new RangeError("Preview horizon must be 1–31 days");
  const end = from + (days - 1) * dayMillis;
  // 2000–2100 bounds cap deterministic ordinal scanning independently of query date.
  const scanEnd = Math.min(
    end,
    rule.endDate === null ? end : epoch(rule.endDate),
    epoch("2100-12-31"),
  );
  const result: RecurrenceSlot[] = [];
  let ordinal = 0;
  for (
    let cursor = epoch(rule.startDate);
    cursor <= scanEnd;
    cursor += dayMillis
  ) {
    const date = new Date(cursor).toISOString().slice(0, 10);
    if (!scheduled(rule, date)) continue;
    if (rule.count !== null && ordinal >= rule.count) break;
    const index = ordinal++;
    if (cursor < from) continue;
    const order = rule.rotation.order;
    const plannedActorId = order[index % order.length]!;
    const excluded =
      rule.exceptions.find((e) => e.date === date)?.excludedActorIds ?? [];
    const available = (id: string) =>
      eligibleActorIds.has(id) && !excluded.includes(id);
    let assigned = available(plannedActorId) ? plannedActorId : null;
    if (assigned === null && rule.rotation.policy === "give_to_next_eligible") {
      for (let step = 1; step < order.length; step++) {
        const candidate = order[(index + step) % order.length]!;
        if (available(candidate)) {
          assigned = candidate;
          break;
        }
      }
    }
    const timing = rule.timing;
    const startLocal = timing.kind === "range" ? `${date}T${timing.at}` : null;
    const endLocal =
      timing.kind === "range"
        ? `${addCivilDays(date, timing.endDayOffset)}T${timing.endAt}`
        : null;
    const start = startLocal
      ? resolveLocalMinute(startLocal, rule.timezoneIana)
      : null;
    const due =
      timing.kind === "none"
        ? null
        : resolveLocalMinute(
            endLocal ?? `${date}T${timing.at}`,
            rule.timezoneIana,
          );
    const collapsed =
      start !== null &&
      due !== null &&
      (due.utcMillis <= start.utcMillis ||
        due.utcMillis - start.utcMillis > 7 * 86_400_000);
    result.push({
      date,
      ordinal: index,
      slotKey: `date:${date}`,
      plannedActorId,
      assignedActorIds: assigned === null ? [] : [assigned],
      status: assigned === null || collapsed ? "skipped" : "scheduled",
      reason:
        assigned === null
          ? "unavailable_assignee"
          : collapsed
            ? "clock_change_window"
            : assigned !== plannedActorId
              ? "substitute"
              : null,
      timezoneIana: rule.timezoneIana,
      timingKind: timing.kind,
      requestedSchedule: {
        kind: timing.kind,
        date,
        at: timing.kind === "range" ? null : timing.at,
        startLocal,
        endLocal,
      },
      dueAtMillis: due?.utcMillis ?? null,
      windowStartAtMillis: start?.utcMillis ?? null,
      effectiveDueLocal: due?.effectiveLocal ?? null,
      effectiveStartLocal: start?.effectiveLocal ?? null,
      timeAdjusted: (due?.adjusted ?? false) || (start?.adjusted ?? false),
    });
  }
  return result;
}
