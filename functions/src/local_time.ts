// Resolve household wall-clock minutes without depending on the server's timezone.
// Intl uses the pinned Node runtime's IANA data. Earlier overlap; first valid gap minute.
const localPattern = /^(20\d{2}|2100)-(\d{2})-(\d{2})T(\d{2}):(\d{2})$/;
function parseLocal(value: string): number {
  const match = localPattern.exec(value);
  if (!match) throw new RangeError("Invalid local date/time.");
  const parts = match.slice(1).map(Number);
  const [year = 0, month = 0, day = 0, hour = -1, minute = -1] = parts;
  const millis = Date.UTC(year, month - 1, day, hour, minute);
  const d = new Date(millis);
  if (
    d.getUTCFullYear() !== year ||
    d.getUTCMonth() !== month - 1 ||
    d.getUTCDate() !== day ||
    d.getUTCHours() !== hour ||
    d.getUTCMinutes() !== minute
  )
    throw new RangeError("Invalid calendar date/time.");
  return millis;
}
function localString(millis: number): string {
  return new Date(millis).toISOString().slice(0, 16);
}
export function resolveLocalMinute(
  requested: string,
  zone: string,
  overlap: "earlier" | "later" = "earlier",
) {
  const naive = parseLocal(requested);
  const formatter = new Intl.DateTimeFormat("en-US", {
    timeZone: zone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  });
  const wallAt = (instant: number) => {
    const parts = formatter.formatToParts(instant);
    const n = (type: Intl.DateTimeFormatPartTypes) =>
      Number(parts.find((p) => p.type === type)?.value);
    return Date.UTC(
      n("year"),
      n("month") - 1,
      n("day"),
      n("hour"),
      n("minute"),
    );
  };
  const offsets = new Set(
    [-36, 0, 36].map((hours) => {
      const anchor = naive + hours * 3_600_000;
      return anchor - wallAt(anchor);
    }),
  );
  // Include a skipped civil day; no silent normalization of invalid dates.
  for (let minutes = 0; minutes <= 1440; minutes++) {
    const wall = naive + minutes * 60_000;
    const candidates = [...offsets]
      .map((offset) => wall + offset)
      .filter((instant) => wallAt(instant) === wall)
      .sort((a, b) => a - b);
    if (candidates.length)
      return {
        utcMillis:
          overlap === "later"
            ? candidates[candidates.length - 1]!
            : candidates[0]!,
        effectiveLocal: localString(wall),
        adjusted: minutes !== 0,
      };
  }
  throw new RangeError("No valid local minute near the requested date.");
}
export function validateLocalDate(date: string): void {
  parseLocal(`${date}T00:00`);
}
