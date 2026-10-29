import { test } from "node:test";
import assert from "node:assert/strict";
import { planOccurrenceNotifications } from "../functions/lib/notification_plan.js";
import { defaultNotificationPreferences } from "../functions/lib/notification_preferences.js";
const t = (s) => Date.parse(`2026-10-${s}Z`);
const row = (patch = {}) => ({
  id: "occurrence",
  localDate: "2026-10-29",
  timezoneIana: "Asia/Manila",
  recurring: false,
  status: "scheduled",
  assignedActorIds: ["child"],
  contributedActorIds: [],
  assignmentRevision: 1,
  completionRevision: 0,
  reviewMode: "guardian",
  createdAtMillis: t("29T03:00:00"),
  assignmentAtMillis: null,
  dueAtMillis: t("29T10:00:00"),
  windowStartAtMillis: null,
  completedAtMillis: null,
  reviewedAtMillis: null,
  helpRequests: [],
  ...patch,
});
const people = [
  { id: "child", role: "child", canManage: false },
  { id: "guardian", role: "guardian", canManage: true },
  { id: "adult", role: "adult", canManage: true },
];
const plan = (occurrence = row(), preferences = new Map(), patch = {}) =>
  planOccurrenceNotifications({
    householdId: "home",
    householdTimezone: "Asia/Manila",
    occurrence,
    recipients: people,
    preferences,
    nowMillis: t("29T04:00:00"),
    ...patch,
  });
test("Stable notification IDs survive retries, unrelated state revisions and preference edits", () => {
  const initial = plan();
  assert.deepEqual(
    initial.map((j) => j.event),
    ["assigned", "upcoming", "due", "overdue"],
  );
  assert.equal(new Set(initial.map((j) => j.id)).size, 4);
  assert.deepEqual(plan(), initial);
  const preferences = new Map([
    [
      "child",
      {
        version: 2,
        preferences: {
          ...defaultNotificationPreferences(),
          reminderMinutes: 30,
        },
      },
    ],
  ]);
  assert.deepEqual(
    plan(row({ completionRevision: 4 }), preferences).map((j) => j.id),
    initial.map((j) => j.id),
  );
  assert.notEqual(plan(row({ assignmentRevision: 2 }))[0].id, initial[0].id);
  assert.notEqual(
    plan(row({ dueAtMillis: t("29T11:00:00") }))[0].id,
    initial[0].id,
  );
});
test("Partial work suppresses that actor's reminders; terminal/cancelled slots do not nag", () => {
  assert.equal(
    plan(
      row({
        assignedActorIds: ["child", "adult"],
        contributedActorIds: ["child"],
      }),
    ).every((j) => j.actorId === "adult"),
    true,
  );
  for (const status of ["completed", "cancelled", "skipped"])
    assert.deepEqual(plan(row({ status })), []);
  assert.deepEqual(plan(row(), new Map(), { recipients: [] }), []);
});
test("Pending review goes only to a separate current guardian and uses its completion revision", () => {
  const occurrence = row({
    status: "pending_review",
    assignedActorIds: ["child", "guardian"],
    contributedActorIds: ["child", "guardian"],
    completionRevision: 3,
    completedAtMillis: t("29T04:00:00"),
  });
  const jobs = plan(occurrence, new Map(), {
    recipients: [
      ...people,
      { id: "reviewer", role: "guardian", canManage: true },
    ],
  });
  assert.deepEqual(
    jobs.map((j) => [j.event, j.actorId, j.sourceRevision]),
    [["review", "reviewer", "3"]],
  );
});
test("Review/help outcomes use actual actor scopes and fixed content without names or notes", () => {
  const jobs = plan(
    row({
      status: "approved",
      reviewedAtMillis: t("29T04:00:00"),
      completionRevision: 3,
      title: "Private title",
      nickname: "Private child",
      helpRequests: [
        {
          actorId: "child",
          requestId: "request",
          status: "resolved",
          requestedAtMillis: t("29T03:00:00"),
          resolvedAtMillis: t("29T04:00:00"),
          note: "Private note",
        },
      ],
    }),
  );
  assert.deepEqual(jobs.map((j) => j.event).sort(), [
    "approved",
    "help_resolved",
  ]);
  assert.equal(
    jobs.every((j) => j.actorId === "child"),
    true,
  );
  assert.equal(JSON.stringify(jobs).includes("Private"), false);
  const help = plan(
    row({
      helpRequests: [
        {
          actorId: "child",
          requestId: "request",
          status: "open",
          requestedAtMillis: t("29T04:00:00"),
          resolvedAtMillis: null,
        },
      ],
    }),
  ).filter((j) => j.event === "help");
  assert.deepEqual(help.map((j) => j.actorId).sort(), ["adult", "guardian"]);
});
test("Quiet delays expire obsolete due/upcoming alerts and keep one gentle overdue prompt", () => {
  const preferences = new Map([
    [
      "child",
      {
        version: 1,
        preferences: { ...defaultNotificationPreferences(), channel: "push" },
      },
    ],
  ]);
  const jobs = plan(row({ dueAtMillis: t("29T12:15:00") }), preferences);
  assert.deepEqual(
    jobs.map((j) => j.event),
    ["assigned", "overdue"],
  );
  assert.equal(
    jobs.find((j) => j.event === "overdue").notifyAtMillis,
    t("30T00:00:00"),
  );
  assert.equal(jobs.filter((j) => j.event === "overdue").length, 1);
  assert.deepEqual(plan(row(), new Map(), { nowMillis: t("30T10:00:00") }), []);
});
test("Future recurring assignments wait for their own slot and event settings are honored", () => {
  const jobs = plan(
    row({
      recurring: true,
      localDate: "2026-10-30",
      dueAtMillis: t("30T10:00:00"),
    }),
  );
  assert.equal(
    jobs.find((j) => j.event === "assigned").availableAtMillis,
    t("30T00:00:00"),
  );
  const preferences = new Map([
    [
      "child",
      {
        version: 1,
        preferences: { ...defaultNotificationPreferences(), enabled: false },
      },
    ],
  ]);
  assert.deepEqual(plan(row(), preferences), []);
  preferences.set("child", {
    version: 2,
    preferences: {
      ...defaultNotificationPreferences(),
      assignment: false,
      reminderMinutes: 0,
      overdue: false,
    },
  });
  assert.deepEqual(
    plan(row(), preferences).map((j) => j.event),
    ["due"],
  );
});
