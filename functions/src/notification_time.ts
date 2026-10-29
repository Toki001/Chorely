import { resolveLocalMinute } from "./local_time.js";
import { householdDate, addCivilDays } from "./recurrence_engine.js";

export type QuietHours = { enabled: boolean; start: string; end: string };

/** Quiet intervals use actual instants, including the entire repeated hour.
 * Start = earlier overlap; end = later overlap; gap = first valid minute.
 * This clock only delays a best-effort alert; it never moves a chore slot. */
export function afterQuietHours(
  instant: number,
  zone: string,
  quiet: QuietHours,
): number {
  const date = householdDate(instant, zone);
  if (!quiet.enabled) return instant;
  if (
    !/^([01]\d|2[0-3]):[0-5]\d$/.test(quiet.start) ||
    !/^([01]\d|2[0-3]):[0-5]\d$/.test(quiet.end) ||
    quiet.start === quiet.end
  ) {
    throw new RangeError("Choose distinct valid quiet-hour times.");
  }
  let result = instant;
  for (const startDate of [addCivilDays(date, -1), date]) {
    const endDate =
      quiet.end < quiet.start ? addCivilDays(startDate, 1) : startDate;
    const start = resolveLocalMinute(
      `${startDate}T${quiet.start}`,
      zone,
    ).utcMillis;
    const end = resolveLocalMinute(
      `${endDate}T${quiet.end}`,
      zone,
      "later",
    ).utcMillis;
    if (instant >= start && instant < end) result = Math.max(result, end);
  }
  return result;
}
