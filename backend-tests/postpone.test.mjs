import { before, beforeEach, after, test } from "node:test";
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { initializeApp, deleteApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { createHousehold } from "../functions/lib/households.js";
import { addChildProfile } from "../functions/lib/child_access.js";
import { writeOneOffChore } from "../functions/lib/chores.js";
import { postponeOccurrence } from "../functions/lib/postpone.js";
import {
  householdDate,
  addCivilDays,
} from "../functions/lib/recurrence_engine.js";
import {
  saveRule,
  materializeRule,
} from "../functions/lib/recurrence_service.js";
import { reconcileOccurrenceNotifications } from "../functions/lib/notification_jobs.js";
let app, db, hid, childId, now, today;
const guardian = {
  uid: "fictional-guardian",
  emailVerified: true,
  provider: "password",
  scopedChild: false,
};
before(() => {
  assert.equal(process.env.FIRESTORE_EMULATOR_HOST, "127.0.0.1:8080");
  app = initializeApp({ projectId: "demo-chorely" }, "postpone-tests");
  db = getFirestore(app);
});
after(() => deleteApp(app));
beforeEach(async () => {
  assert.equal(
    (
      await fetch(
        `http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/demo-chorely/databases/(default)/documents`,
        { method: "DELETE" },
      )
    ).ok,
    true,
  );
  now = Date.now();
  today = householdDate(now, "Asia/Manila");
  hid = (
    await createHousehold(db, guardian, {
      name: "Fictional home",
      nickname: "Alex",
      timezone: "Asia/Manila",
      commandId: randomUUID(),
    })
  ).householdId;
  childId = (
    await addChildProfile(db, guardian, {
      householdId: hid,
      nickname: "Fictional child",
      commandId: randomUUID(),
    })
  ).profileId;
});
const create = (patch = {}) =>
  writeOneOffChore(db, guardian, {
    householdId: hid,
    commandId: randomUUID(),
    action: "create",
    title: "Cook rice",
    category: "dinner",
    description: "Fictional instructions",
    steps: [],
    room: "",
    assignedActorIds: [childId],
    completionPolicy: "any_one_completes",
    reviewMode: "guardian",
    schedule: { kind: "time", date: addCivilDays(today, 1), at: "18:00" },
    ...patch,
  });
const request = (created, patch = {}) => ({
  householdId: hid,
  occurrenceId: created.occurrenceId,
  commandId: randomUUID(),
  baseVersion: 1,
  schedule: { kind: "deadline", date: addCivilDays(today, 2), at: "19:30" },
  ...patch,
});
const ref = (created) =>
  db.doc(`households/${hid}/occurrences/${created.occurrenceId}`);

test("Postponement keeps the slot, definition, assignment and completion history independent", async () => {
  const saved = await create(),
    before = await ref(saved).get();
  const template = db.doc(
      `households/${hid}/choreTemplates/${saved.templateId}`,
    ),
    definition = (await template.get()).data();
  const intent = request(saved),
    result = await postponeOccurrence(db, guardian, intent, now);
  const after = await ref(saved).get();
  assert.equal(result.occurrenceId, saved.occurrenceId);
  assert.equal(result.version, 2);
  for (const key of [
    "templateId",
    "templateVersion",
    "recurrenceVersion",
    "slotKey",
    "assignedActorIds",
    "completionPolicy",
    "reviewMode",
    "status",
    "completionRevision",
  ])
    assert.deepEqual(after.get(key), before.get(key), key);
  assert.deepEqual((await template.get()).data(), definition);
  assert.equal(
    after.get("scheduleOverride.originalLocalDate"),
    before.get("localDate"),
  );
  assert.equal(after.get("scheduleOverride.actorId"), guardian.uid);
  assert.equal(
    after.get("dueAtUtc").toDate().toISOString(),
    `${addCivilDays(today, 2)}T11:30:00.000Z`,
  );
  assert.equal(after.get("assignmentRevision"), 1);
  const events = await db
    .collection(`households/${hid}/activity`)
    .where("action", "==", "occurrence_postponed")
    .get();
  assert.equal(events.size, 1);
  assert.equal(events.docs[0].get("fromVersion"), 1);
  assert.equal(events.docs[0].get("toVersion"), 2);
});
test("Concurrent identical retries commit one revision, quota increment and outbox event", async () => {
  const saved = await create(),
    intent = request(saved);
  const [a, b] = await Promise.all([
    postponeOccurrence(db, guardian, intent, now),
    postponeOccurrence(db, guardian, intent, now),
  ]);
  assert.deepEqual(a, b);
  assert.equal((await ref(saved).get()).get("version"), 2);
  assert.equal(
    (await db.doc(`rateLimits/${guardian.uid}`).get()).get("postponeWrites"),
    1,
  );
  assert.equal(
    (
      await db
        .collection("notificationOutbox")
        .where("occurrenceId", "==", saved.occurrenceId)
        .get()
    ).size,
    2,
  );
  await assert.rejects(
    postponeOccurrence(
      db,
      guardian,
      { ...intent, schedule: { ...intent.schedule, at: "20:00" } },
      now,
    ),
    { code: "already-exists" },
  );
});
test("Competing changes expose a version conflict instead of silently moving the deadline twice", async () => {
  const saved = await create(),
    first = request(saved),
    second = request(saved, {
      schedule: { kind: "time", date: addCivilDays(today, 3), at: "20:00" },
    });
  const results = await Promise.allSettled([
    postponeOccurrence(db, guardian, first, now),
    postponeOccurrence(db, guardian, second, now),
  ]);
  assert.equal(results.filter((r) => r.status === "fulfilled").length, 1);
  assert.equal(
    results.find((r) => r.status === "rejected").reason.code,
    "aborted",
  );
  assert.equal((await ref(saved).get()).get("version"), 2);
});
test("Only a current verified guardian can postpone, including accepted replays", async () => {
  const saved = await create(),
    intent = request(saved),
    adult = { ...guardian, uid: "ordinary-adult" };
  await db
    .doc(`households/${hid}/members/${adult.uid}`)
    .set({ status: "active", role: "adult", canAssign: true });
  for (const actor of [
    null,
    { ...guardian, emailVerified: false },
    { ...guardian, uid: "outsider" },
    { ...guardian, scopedChild: true },
    adult,
  ])
    await assert.rejects(postponeOccurrence(db, actor, intent, now));
  await postponeOccurrence(db, guardian, intent, now);
  await db
    .doc(`households/${hid}/members/${guardian.uid}`)
    .update({ status: "revoked" });
  await assert.rejects(postponeOccurrence(db, guardian, intent, now), {
    code: "permission-denied",
  });
});
test("Invalid, earlier, past and distant deadlines cannot replace an occurrence", async () => {
  const saved = await create();
  for (const schedule of [
    { kind: "none", date: addCivilDays(today, 2) },
    { kind: "time", date: "2026-02-30", at: "18:00" },
    { kind: "deadline", date: addCivilDays(today, 2), at: "25:00" },
    { kind: "time", date: addCivilDays(today, -1), at: "18:00" },
    { kind: "time", date: addCivilDays(today, 1), at: "17:00" },
    { kind: "time", date: addCivilDays(today, 1), at: "18:00" },
    { kind: "time", date: addCivilDays(today, 31), at: "18:00" },
    {
      kind: "range",
      date: today,
      startLocal: `${today}T00:00`,
      endLocal: `${addCivilDays(today, 2)}T19:30`,
    },
  ])
    await assert.rejects(
      postponeOccurrence(db, guardian, request(saved, { schedule }), now),
      { code: "invalid-argument" },
    );
  assert.equal((await ref(saved).get()).get("version"), 1);
});
test("Terminal, review-waiting and partially completed occurrences retain their recorded work", async () => {
  for (const patch of [
    { status: "completed" },
    { status: "approved" },
    { status: "pending_review" },
    { status: "cancelled" },
    { status: "skipped" },
    { contributions: { [childId]: { completionRevision: 1 } } },
  ]) {
    const saved = await create();
    await ref(saved).update(patch);
    await assert.rejects(
      postponeOccurrence(db, guardian, request(saved), now),
      { code: "failed-precondition" },
    );
    assert.equal((await ref(saved).get()).get("version"), 1);
  }
});
test("Untimed chores require a later day and deleted assignees cannot be silently retained", async () => {
  const saved = await create({
    schedule: { kind: "none", date: addCivilDays(today, 1) },
  });
  await assert.rejects(
    postponeOccurrence(
      db,
      guardian,
      request(saved, {
        schedule: {
          kind: "deadline",
          date: addCivilDays(today, 1),
          at: "20:00",
        },
      }),
      now,
    ),
    { code: "invalid-argument" },
  );
  await db
    .doc(`households/${hid}/profiles/${childId}`)
    .update({ status: "revoked" });
  await assert.rejects(postponeOccurrence(db, guardian, request(saved), now), {
    code: "invalid-argument",
  });
  await db
    .doc(`households/${hid}/profiles/${childId}`)
    .update({ status: "active" });
  await postponeOccurrence(db, guardian, request(saved), now);
  assert.equal((await ref(saved).get()).get("timingKind"), "deadline");
});
test("Postponement invalidates old timing jobs and preserves assignment notification identity", async () => {
  const saved = await create();
  await reconcileOccurrenceNotifications(db, hid, saved.occurrenceId, now);
  const jobs = db.collection(`households/${hid}/notificationJobs`),
    before = await jobs.get();
  const timing = before.docs.filter((d) =>
    ["upcoming", "due", "overdue"].includes(d.get("event")),
  );
  assert.ok(timing.length > 0);
  const assigned = before.docs.find((d) => d.get("event") === "assigned");
  await postponeOccurrence(db, guardian, request(saved), now);
  await reconcileOccurrenceNotifications(db, hid, saved.occurrenceId, now);
  for (const old of timing)
    assert.equal((await old.ref.get()).get("state"), "cancelled");
  const after = await jobs.get();
  assert.ok(
    after.docs.some(
      (d) =>
        d.get("event") === "due" &&
        d.get("state") === "queued" &&
        !timing.some((old) => old.id === d.id),
    ),
  );
  assert.equal(
    after.docs.filter((d) => d.get("event") === "assigned").length,
    1,
  );
  assert.equal(
    after.docs.find((d) => d.get("event") === "assigned").id,
    assigned.id,
  );
  assert.equal((await assigned.ref.get()).get("sourceOccurrenceVersion"), 2);
});
test("A recurring override survives worker refresh and future rule pause without shifting other slots", async () => {
  const created = await create({ schedule: { kind: "none", date: today } });
  const config = {
    householdId: hid,
    templateId: created.templateId,
    commandId: randomUUID(),
    baseTemplateVersion: 1,
    baseRuleVersion: 0,
    paused: false,
    expectedTimezone: "Asia/Manila",
    effectiveFrom: addCivilDays(today, 1),
    rule: {
      frequency: "daily",
      startDate: addCivilDays(today, 1),
      endDate: null,
      count: null,
      weekdays: [],
      monthDay: null,
      timing: { kind: "time", at: "18:00", endAt: null, endDayOffset: 0 },
      rotation: { order: [childId], policy: "preserve_turn" },
      exceptions: [],
    },
  };
  await saveRule(db, guardian, config);
  const rows = await db
    .collection(`households/${hid}/occurrences`)
    .where("localDate", "==", addCivilDays(today, 1))
    .get();
  const target = rows.docs[0],
    intent = request(
      { occurrenceId: target.id },
      {
        schedule: {
          kind: "deadline",
          date: addCivilDays(today, 3),
          at: "19:30",
        },
      },
    );
  await postponeOccurrence(db, guardian, intent, now);
  const overridden = (await target.ref.get()).data();
  await materializeRule(db, hid, created.templateId, now + 61_000);
  assert.deepEqual((await target.ref.get()).data(), overridden);
  await saveRule(db, guardian, {
    ...config,
    commandId: randomUUID(),
    baseTemplateVersion: 2,
    baseRuleVersion: 1,
    paused: true,
  });
  assert.deepEqual((await target.ref.get()).data(), overridden);
  const all = await db.collection(`households/${hid}/occurrences`).get();
  assert.equal(new Set(all.docs.map((d) => d.get("slotKey"))).size, all.size);
  assert.ok(all.docs.some((d) => d.get("status") === "cancelled"));
});
test("DST gap policy applies to the existing occurrence zone; accepted replay survives quota exhaustion", async () => {
  await db
    .doc(`households/${hid}`)
    .update({ timezoneIana: "America/New_York" });
  const saved = await create({
    schedule: { kind: "time", date: "2026-03-07", at: "18:00" },
  });
  const intent = request(saved, {
      schedule: { kind: "deadline", date: "2026-03-08", at: "02:30" },
    }),
    clock = Date.parse("2026-03-07T15:00Z");
  await postponeOccurrence(db, guardian, intent, clock);
  const row = await ref(saved).get();
  assert.equal(row.get("effectiveDueLocal"), "2026-03-08T03:00");
  assert.equal(row.get("timeAdjusted"), true);
  assert.equal(
    row.get("dueAtUtc").toDate().toISOString(),
    "2026-03-08T07:00:00.000Z",
  );
  await db.doc(`rateLimits/${guardian.uid}`).update({ postponeWrites: 500 });
  assert.equal(
    (await postponeOccurrence(db, guardian, intent, clock)).version,
    2,
  );
  await assert.rejects(
    postponeOccurrence(
      db,
      guardian,
      request(saved, {
        baseVersion: 2,
        schedule: { kind: "deadline", date: "2026-03-09", at: "18:00" },
      }),
      clock,
    ),
    { code: "resource-exhausted" },
  );
});
