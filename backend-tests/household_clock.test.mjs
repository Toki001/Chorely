import { test } from "node:test";
import assert from "node:assert/strict";
import { householdClockAt } from "../functions/lib/household_clock.js";
test("Household clock chooses the household date rather than the UTC/device date", () => {
  const now = Date.parse("2026-10-29T20:00:00Z");
  const clock = householdClockAt(now, "Asia/Manila");
  assert.equal(clock.today, "2026-10-30");
  assert.equal(clock.serverNowMillis, now);
  assert.equal(
    new Date(clock.nextMidnightMillis).toISOString(),
    "2026-10-30T16:00:00.000Z",
  );
});
test("Next household midnight follows the 23-hour DST day", () => {
  const now = Date.parse("2026-03-08T05:00:00Z"),
    clock = householdClockAt(now, "America/New_York");
  assert.equal(clock.today, "2026-03-08");
  assert.equal(clock.nextMidnightMillis - now, 23 * 3_600_000);
});
test("Next household midnight follows the 25-hour DST day", () => {
  const now = Date.parse("2026-11-01T04:00:00Z"),
    clock = householdClockAt(now, "America/New_York");
  assert.equal(clock.today, "2026-11-01");
  assert.equal(clock.nextMidnightMillis - now, 25 * 3_600_000);
});
test("Clock skips a missing civil date and rejects an invalid zone", () => {
  const now = Date.parse("2011-12-29T10:00:00Z"),
    clock = householdClockAt(now, "Pacific/Apia");
  assert.equal(clock.today, "2011-12-29");
  assert.equal(
    new Date(clock.nextMidnightMillis).toISOString(),
    "2011-12-30T10:00:00.000Z",
  );
  assert.throws(() => householdClockAt(now, "Unknown/Place"));
});
