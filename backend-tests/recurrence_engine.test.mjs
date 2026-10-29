import { test } from "node:test";
import assert from "node:assert/strict";
import {
  previewRecurrence,
  validateRule,
  householdDate,
} from "../functions/lib/recurrence_engine.js";
const eligible = new Set(["alex", "sam", "lee"]);
const rule = (patch = {}) => ({
  frequency: "daily",
  startDate: "2026-10-29",
  endDate: null,
  count: null,
  weekdays: [],
  monthDay: null,
  timing: { kind: "none", at: null, endAt: null, endDayOffset: 0 },
  timezoneIana: "Asia/Manila",
  rotation: { order: ["alex", "sam", "lee"], policy: "preserve_turn" },
  exceptions: [],
  ...patch,
});
const preview = (r, from = r.startDate, days = 14, active = eligible) =>
  previewRecurrence(r, from, days, active);
test("Fourteen daily turns match an anchored three-person rotation and partial previews", () => {
  const r = rule();
  const slots = preview(r);
  assert.equal(slots.length, 14);
  assert.deepEqual(
    slots.map((s) => s.assignedActorIds[0]),
    Array.from({ length: 14 }, (_, i) => ["alex", "sam", "lee"][i % 3]),
  );
  assert.deepEqual(preview(r, "2026-11-03", 3), slots.slice(5, 8));
  assert.deepEqual(preview(r), slots);
  assert.equal(new Set(slots.map((s) => s.slotKey)).size, 14);
});
test("Selected weekdays omit weekends and weekly cadence stays on its anchor weekday", () => {
  const weekdays = preview(
    rule({
      frequency: "weekdays",
      weekdays: [1, 2, 3, 4, 5],
      startDate: "2026-10-30",
    }),
    "2026-10-30",
    7,
  );
  assert.deepEqual(
    weekdays.map((s) => s.date),
    ["2026-10-30", "2026-11-02", "2026-11-03", "2026-11-04", "2026-11-05"],
  );
  const weekly = preview(
    rule({ frequency: "weekly", startDate: "2026-10-28" }),
  );
  assert.deepEqual(
    weekly.map((s) => s.date),
    ["2026-10-28", "2026-11-04"],
  );
});
test("Month 31 skips nonexistent dates and count is global across independent query horizons", () => {
  const r = rule({
    frequency: "monthly",
    startDate: "2028-01-31",
    monthDay: 31,
    count: 3,
  });
  assert.equal(preview(r, "2028-02-01", 29).length, 0);
  const march = preview(r, "2028-03-01", 31);
  assert.equal(march[0].date, "2028-03-31");
  assert.equal(march[0].ordinal, 1);
  assert.equal(march[0].plannedActorId, "sam");
  assert.equal(preview(r, "2028-05-01", 31)[0].ordinal, 2);
  assert.equal(preview(r, "2028-07-01", 31).length, 0);
});
test("Leap day, inclusive end and maximum count produce exact calendar slots", () => {
  const slots = preview(
    rule({ startDate: "2028-02-28", endDate: "2028-03-01" }),
    "2028-02-28",
    4,
  );
  assert.deepEqual(
    slots.map((s) => s.date),
    ["2028-02-28", "2028-02-29", "2028-03-01"],
  );
  assert.equal(preview(rule({ count: 2 })).length, 2);
  assert.equal(preview(rule({ count: 2 }), "2026-11-01", 3).length, 0);
});
test("Unavailable members preserve their turn; substitution never shifts later rotation history", () => {
  const active = new Set(["alex", "lee"]);
  const keep = preview(rule(), "2026-10-29", 4, active);
  assert.equal(keep[1].status, "skipped");
  assert.equal(keep[1].reason, "unavailable_assignee");
  assert.deepEqual(keep[1].assignedActorIds, []);
  assert.equal(keep[2].plannedActorId, "lee");
  const r = rule({
    rotation: {
      order: ["alex", "sam", "lee"],
      policy: "give_to_next_eligible",
    },
  });
  const replace = preview(r, r.startDate, 4, active);
  assert.deepEqual(
    replace.map((s) => s.assignedActorIds[0]),
    ["alex", "lee", "lee", "alex"],
  );
  assert.equal(replace[1].reason, "substitute");
  assert.deepEqual(
    preview(r, r.startDate, 4, new Set()).map((s) => s.status),
    Array(4).fill("skipped"),
  );
});
test("Explicit absence affects one date and keeps all later ordinals and scheduled owners", () => {
  const r = rule({
    exceptions: [{ date: "2026-10-30", excludedActorIds: ["sam"] }],
  });
  const slots = preview(r, r.startDate, 5);
  assert.equal(slots[1].status, "skipped");
  assert.equal(slots[2].plannedActorId, "lee");
  assert.equal(slots[4].plannedActorId, "sam");
});
test("DST gap/overlap and household zone are resolved explicitly without mutating rule inputs", () => {
  const r = rule({
    startDate: "2026-03-07",
    timezoneIana: "America/New_York",
    timing: { kind: "time", at: "02:30", endAt: null, endDayOffset: 0 },
  });
  const before = JSON.stringify(r);
  const slots = preview(r, r.startDate, 3);
  assert.deepEqual(
    slots.map((s) => new Date(s.dueAtMillis).toISOString()),
    [
      "2026-03-07T07:30:00.000Z",
      "2026-03-08T07:00:00.000Z",
      "2026-03-09T06:30:00.000Z",
    ],
  );
  assert.equal(slots[1].timeAdjusted, true);
  assert.equal(slots[1].effectiveDueLocal, "2026-03-08T03:00");
  assert.equal(JSON.stringify(r), before);
  const overlap = preview(
    rule({
      startDate: "2026-11-01",
      timezoneIana: "America/New_York",
      timing: { kind: "deadline", at: "01:30", endAt: null, endDayOffset: 0 },
    }),
    "2026-11-01",
    1,
  );
  assert.equal(
    new Date(overlap[0].dueAtMillis).toISOString(),
    "2026-11-01T05:30:00.000Z",
  );
  assert.equal(
    householdDate(Date.parse("2026-10-29T20:00:00Z"), "Asia/Manila"),
    "2026-10-30",
  );
});
test("Cross-midnight recurring windows have concrete start/end instants", () => {
  const r = rule({
    timing: { kind: "range", at: "22:00", endAt: "01:00", endDayOffset: 1 },
  });
  const slot = preview(r, r.startDate, 1)[0];
  assert.equal(
    new Date(slot.windowStartAtMillis).toISOString(),
    "2026-10-29T14:00:00.000Z",
  );
  assert.equal(
    new Date(slot.dueAtMillis).toISOString(),
    "2026-10-29T17:00:00.000Z",
  );
  assert.equal(slot.requestedSchedule.endLocal, "2026-10-30T01:00");
});
test("Invalid rules, impossible dates, empty rotation and invalid preview horizons fail", () => {
  for (const patch of [
    { startDate: "2026-02-30" },
    { endDate: "2026-10-01" },
    { count: 0 },
    { count: 3661 },
    { frequency: "weekdays", weekdays: [] },
    { frequency: "monthly", monthDay: 32 },
    { rotation: { order: [], policy: "preserve_turn" } },
    { rotation: { order: ["alex", "alex"], policy: "preserve_turn" } },
    { weekdays: [1, 1] },
    { timezoneIana: "Invalid/Zone" },
    { timing: { kind: "range", at: "22:00", endAt: "21:00", endDayOffset: 0 } },
  ])
    assert.throws(() => validateRule(rule(patch)));
  assert.throws(() => preview(rule(), "2026-10-29", 0));
  assert.throws(() => preview(rule(), "2026-10-29", 32));
});

test("A DST gap that collapses a window is explicitly skipped while later slots survive", () => {
  const r = rule({
    startDate: "2026-03-08",
    timezoneIana: "America/New_York",
    timing: { kind: "range", at: "02:15", endAt: "02:45", endDayOffset: 0 },
  });
  const slots = preview(r, r.startDate, 2);
  assert.equal(slots[0].status, "skipped");
  assert.equal(slots[0].reason, "clock_change_window");
  assert.equal(slots[1].status, "scheduled");
  assert.equal(slots[1].ordinal, 1);
});

test("A clock change cannot create a recurring window longer than seven UTC days", () => {
  const r = rule({
    startDate: "2026-10-26",
    timezoneIana: "America/New_York",
    timing: { kind: "range", at: "00:00", endAt: "23:59", endDayOffset: 6 },
  });
  const slot = preview(r, r.startDate, 1)[0];
  assert.equal(slot.status, "skipped");
  assert.equal(slot.reason, "clock_change_window");
});
