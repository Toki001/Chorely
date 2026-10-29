import { before, beforeEach, after, test } from "node:test";
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { initializeApp, deleteApp } from "firebase-admin/app";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { createHousehold } from "../functions/lib/households.js";
import { addChildProfile } from "../functions/lib/child_access.js";
import { writeOneOffChore } from "../functions/lib/chores.js";
import {
  saveRule,
  materializeRule,
  previewRule,
  refreshRule,
} from "../functions/lib/recurrence_service.js";
import {
  householdDate,
  addCivilDays,
} from "../functions/lib/recurrence_engine.js";
let app, db, hid, tid, childId, today;
const guardian = {
  uid: "fictional-guardian",
  emailVerified: true,
  provider: "password",
  scopedChild: false,
};
before(() => {
  assert.ok(process.env.FIRESTORE_EMULATOR_HOST);
  app = initializeApp({ projectId: "demo-chorely" }, "recurrence-tests");
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
  today = householdDate(Date.now(), "Asia/Manila");
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
  tid = (
    await writeOneOffChore(db, guardian, {
      householdId: hid,
      commandId: randomUUID(),
      action: "create",
      title: "Cook rice",
      category: "dinner",
      description: "",
      room: "",
      steps: [],
      assignedActorIds: [childId],
      completionPolicy: "any_one_completes",
      reviewMode: "guardian",
      schedule: { kind: "none", date: today },
    })
  ).templateId;
});
const request = (patch = {}) => ({
  householdId: hid,
  templateId: tid,
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
  ...patch,
});
const occurrences = () => db.collection(`households/${hid}/occurrences`).get();
test("Concurrent publication and duplicate/expired-lease worker passes never duplicate or inflate occurrences", async () => {
  const input = request();
  const [a, b] = await Promise.all([
    saveRule(db, guardian, input),
    saveRule(db, guardian, input),
  ]);
  assert.deepEqual(a, b);
  assert.equal(a.version, 1);
  let records = await occurrences();
  assert.equal(records.size, 31); // Today's one-off remains; thirty future dates materialized.
  assert.equal(
    records.docs.filter((d) => d.get("recurrenceVersion") === 1).length,
    30,
  );
  assert.equal(
    records.docs.find((d) => d.get("recurrenceVersion") === 0).get("status"),
    "scheduled",
  );
  const now = Date.now();
  assert.equal((await materializeRule(db, hid, tid, now)).changed, 0);
  assert.equal((await materializeRule(db, hid, tid, now + 61_000)).changed, 0);
  const eventsBefore = (await db.collection(`households/${hid}/activity`).get())
    .size;
  const next = now + 86_400_000;
  const runs = await Promise.all([
    materializeRule(db, hid, tid, next),
    materializeRule(db, hid, tid, next),
  ]);
  assert.equal(
    runs.reduce((sum, r) => sum + r.changed, 0),
    1,
  );
  assert.equal((await occurrences()).size, 32);
  assert.equal(
    (await db.collection(`households/${hid}/activity`).get()).size,
    eventsBefore + 1,
  );
  await assert.rejects(saveRule(db, guardian, { ...input, paused: true }), {
    code: "already-exists",
  });
});
test("Future version changes preserve completed snapshots, reuse date identities and retain immutable rule history", async () => {
  const first = request();
  await saveRule(db, guardian, first);
  const rows = await occurrences();
  const completed = rows.docs.find((d) => d.get("recurrenceVersion") === 1);
  await completed.ref.update({ status: "completed", version: 2 });
  const snapshot = (await completed.ref.get()).data();
  const second = request({
    baseTemplateVersion: 2,
    baseRuleVersion: 1,
    effectiveFrom: addCivilDays(today, 3),
    rule: { ...first.rule, frequency: "weekdays", weekdays: [1, 3, 5] },
  });
  await saveRule(db, guardian, second);
  assert.deepEqual((await completed.ref.get()).data(), snapshot);
  assert.equal((await occurrences()).size, 31);
  assert.equal(
    (
      await db
        .collection(`households/${hid}/recurrenceRules/${tid}/versions`)
        .get()
    ).size,
    2,
  );
  await assert.rejects(
    saveRule(db, guardian, { ...second, commandId: randomUUID() }),
    { code: "aborted" },
  );
});
test("Pause is future effective; resuming future dates preserves recorded work and audit", async () => {
  const first = request();
  await saveRule(db, guardian, first);
  await saveRule(
    db,
    guardian,
    request({
      baseTemplateVersion: 2,
      baseRuleVersion: 1,
      effectiveFrom: addCivilDays(today, 3),
      paused: true,
    }),
  );
  const rows = await occurrences();
  assert.equal(
    rows.docs.filter(
      (d) =>
        d.get("recurrenceVersion") === 1 && d.get("status") === "scheduled",
    ).length,
    2,
  );
  await saveRule(
    db,
    guardian,
    request({
      baseTemplateVersion: 3,
      baseRuleVersion: 2,
      effectiveFrom: addCivilDays(today, 5),
    }),
  );
  const after = await occurrences();
  assert.equal(after.size, 31);
  assert.equal(
    after.docs.filter(
      (d) =>
        d.get("recurrenceVersion") === 3 && d.get("status") === "scheduled",
    ).length,
    26,
  );
});
test("Removed rotation member is explicitly skipped, never silently replaced; restoration recomputes future state", async () => {
  const first = request();
  await saveRule(db, guardian, first);
  await db
    .doc(`households/${hid}/profiles/${childId}`)
    .update({ status: "revoked" });
  await materializeRule(db, hid, tid);
  const rows = await occurrences();
  assert.equal(
    rows.docs.filter(
      (d) => d.get("recurrenceVersion") === 1 && d.get("status") === "skipped",
    ).length,
    30,
  );
  assert.equal(
    rows.docs.find((d) => d.get("recurrenceVersion") === 1).get("reason"),
    "unavailable_assignee",
  );
  await db
    .doc(`households/${hid}/profiles/${childId}`)
    .update({ status: "active" });
  assert.equal((await materializeRule(db, hid, tid)).changed, 30);
});
test("Tenant/capability boundaries, invalid effective dates, stale timezone and forged scope deny before writes", async () => {
  for (const actor of [
    null,
    { ...guardian, uid: "outside" },
    { ...guardian, scopedChild: true },
  ])
    await assert.rejects(saveRule(db, actor, request()));
  for (const patch of [
    { effectiveFrom: today },
    { effectiveFrom: addCivilDays(today, 31) },
    { effectiveFrom: "2026-02-30" },
    {
      rule: {
        ...request().rule,
        rotation: { order: ["other-home-profile"], policy: "preserve_turn" },
      },
    },
  ])
    await assert.rejects(saveRule(db, guardian, request(patch)), {
      code: "invalid-argument",
    });
  await assert.rejects(
    saveRule(db, guardian, request({ expectedTimezone: "America/New_York" })),
    { code: "aborted" },
  );
  await assert.rejects(
    refreshRule(
      db,
      { ...guardian, uid: "outside" },
      { householdId: hid, templateId: tid },
    ),
    { code: "permission-denied" },
  );
  assert.equal(
    (await db.collection(`households/${hid}/recurrenceRules`).get()).size,
    0,
  );
});
test("A new future timezone version preserves stored prior UTC instants and old accepted retries", async () => {
  const first = request();
  await saveRule(db, guardian, first);
  const rows = await occurrences();
  const effective = addCivilDays(today, 4);
  const earlier = rows.docs
    .filter((d) => d.get("localDate") < effective)
    .map((d) => ({ id: d.id, data: d.data() }));
  await db
    .doc(`households/${hid}`)
    .update({ timezoneIana: "America/New_York" }); // Simulates a separately authorized household setting; no client write allowed.
  assert.equal((await saveRule(db, guardian, first)).version, 1);
  await saveRule(
    db,
    guardian,
    request({
      baseTemplateVersion: 2,
      baseRuleVersion: 1,
      effectiveFrom: effective,
      expectedTimezone: "America/New_York",
    }),
  );
  for (const old of earlier)
    assert.deepEqual(
      (await db.doc(`households/${hid}/occurrences/${old.id}`).get()).data(),
      old.data,
    );
  const future = (await occurrences()).docs.find(
    (d) => d.get("localDate") === effective,
  );
  assert.equal(future.get("timezoneIana"), "America/New_York");
  assert.equal(future.get("recurrenceVersion"), 2);
});
test("Preview contains fourteen deterministic actual policy slots but never writes provisioned occurrences", async () => {
  const input = request();
  const result = await previewRule(db, guardian, {
    householdId: hid,
    templateId: tid,
    fromDate: input.rule.startDate,
    rule: input.rule,
  });
  assert.equal(result.slots.length, 14);
  assert.equal(result.slots[0].plannedActorId, childId);
  assert.equal((await occurrences()).size, 1);
});

test("Bounded automatic worker respects a held global lease and advances a durable cursor across rules", async () => {
  const { runRecurrenceWorker } =
    await import("../functions/lib/recurrence_worker.js");
  const first = request();
  await saveRule(db, guardian, first);
  const another = (
    await writeOneOffChore(db, guardian, {
      householdId: hid,
      commandId: randomUUID(),
      action: "create",
      title: "Tidy a room",
      category: "rooms",
      room: "",
      description: "",
      steps: [],
      assignedActorIds: [childId],
      completionPolicy: "any_one_completes",
      reviewMode: "guardian",
      schedule: { kind: "none", date: today },
    })
  ).templateId;
  await saveRule(db, guardian, request({ templateId: another }));
  const now = Date.now() + 86_400_000;
  await db.doc("schedulerState/recurrence").set({
    owner: "fictional-active-worker",
    leaseUntil: Timestamp.fromMillis(now + 300_000),
    cursor: null,
  });
  const held = await runRecurrenceWorker(db, now, { pageSize: 1, maxPages: 1 });
  assert.equal(held.skipped, true);
  assert.equal(held.processed, 0);
  await db
    .doc("schedulerState/recurrence")
    .update({ leaseUntil: Timestamp.fromMillis(now - 1) });
  const firstRun = await runRecurrenceWorker(db, now, {
    pageSize: 1,
    maxPages: 1,
  });
  assert.equal(firstRun.processed, 1);
  assert.equal(firstRun.changed, 1);
  assert.notEqual(
    (await db.doc("schedulerState/recurrence").get()).get("cursor"),
    null,
  );
  const next = await runRecurrenceWorker(db, now, { pageSize: 1, maxPages: 1 });
  assert.equal(next.processed, 1);
  assert.equal(next.changed, 1);
  const wrap = await runRecurrenceWorker(db, now, { pageSize: 1, maxPages: 1 });
  assert.equal(wrap.processed, 0);
  assert.equal(
    (await db.doc("schedulerState/recurrence").get()).get("cursor"),
    null,
  );
});

test("Corrupt rule history records a private failure while other schedules keep materializing", async () => {
  const { runRecurrenceWorker } =
    await import("../functions/lib/recurrence_worker.js");
  await saveRule(db, guardian, request());
  await db.doc(`households/${hid}/recurrenceRules/${tid}/versions/1`).delete();
  const other = (
    await writeOneOffChore(db, guardian, {
      householdId: hid,
      commandId: randomUUID(),
      action: "create",
      title: "Refill supplies",
      category: "supplies",
      room: "",
      description: "",
      steps: [],
      assignedActorIds: [childId],
      completionPolicy: "any_one_completes",
      reviewMode: "guardian",
      schedule: { kind: "none", date: today },
    })
  ).templateId;
  await saveRule(db, guardian, request({ templateId: other }));
  const result = await runRecurrenceWorker(db, Date.now() + 86_400_000);
  assert.equal(result.processed, 2);
  assert.equal(result.failed, 1);
  assert.equal(result.changed, 1);
  const failures = await db.collection("schedulerFailures").get();
  assert.equal(failures.size, 1);
  assert.equal(failures.docs[0].get("code"), "failed-precondition");
});

test("Automatic unavailability reconciliation preserves today's stored owner and audits future reassignment", async () => {
  const input = request();
  await saveRule(db, guardian, input);
  const tomorrow = addCivilDays(today, 1);
  const original = (await occurrences()).docs.find(
    (d) => d.get("localDate") === tomorrow && d.get("recurrenceVersion") === 1,
  );
  const snapshot = original.data();
  await db
    .doc(`households/${hid}/profiles/${childId}`)
    .update({ status: "revoked" });
  await materializeRule(db, hid, tid, Date.now() + 86_400_000);
  assert.deepEqual((await original.ref.get()).data(), snapshot);
  const events = await db
    .collection(`households/${hid}/activity`)
    .where("action", "==", "recurrence_revised")
    .get();
  assert.ok(events.size > 0);
  assert.deepEqual(events.docs[0].get("fromAssignedActorIds"), [childId]);
  assert.deepEqual(events.docs[0].get("toAssignedActorIds"), []);
  assert.equal(events.docs[0].get("reason"), "unavailable_assignee");
});

test("A stored household date that already began never shifts when a new zone labels it as tomorrow", async () => {
  const input = request();
  input.rule.timing = {
    kind: "time",
    at: "00:00",
    endAt: null,
    endDayOffset: 0,
  };
  await saveRule(db, guardian, input);
  const date = addCivilDays(today, 1);
  const original = (await occurrences()).docs.find(
    (d) => d.get("localDate") === date && d.get("recurrenceVersion") === 1,
  );
  const snapshot = original.data();
  await db
    .doc(`households/${hid}`)
    .update({ timezoneIana: "America/New_York" });
  await db
    .doc(`households/${hid}/profiles/${childId}`)
    .update({ status: "revoked" });
  const now = Date.parse(`${today}T16:30:00Z`); // Next date began in Manila; New York still labels it tomorrow.
  assert.equal(householdDate(now, "Asia/Manila"), date);
  assert.equal(householdDate(now, "America/New_York"), today);
  await materializeRule(db, hid, tid, now);
  assert.deepEqual((await original.ref.get()).data(), snapshot);
});

test("A future edit replaces later pending settings so its preview matches stored turns; superseded versions remain", async () => {
  const first = request();
  await saveRule(db, guardian, first);
  await saveRule(
    db,
    guardian,
    request({
      baseTemplateVersion: 2,
      baseRuleVersion: 1,
      effectiveFrom: addCivilDays(today, 10),
      paused: true,
    }),
  );
  const edit = request({
    baseTemplateVersion: 3,
    baseRuleVersion: 2,
    effectiveFrom: addCivilDays(today, 3),
  });
  const preview = await previewRule(db, guardian, {
    householdId: hid,
    templateId: tid,
    fromDate: edit.effectiveFrom,
    rule: edit.rule,
  });
  await saveRule(db, guardian, edit);
  const stored = await occurrences();
  for (const turn of preview.slots) {
    const row = stored.docs.find(
      (d) => d.get("localDate") === turn.date && d.get("recurrenceVersion") > 0,
    );
    assert.equal(row.get("status"), turn.status);
    assert.deepEqual(row.get("assignedActorIds"), turn.assignedActorIds);
    assert.equal(row.get("recurrenceVersion"), 3);
  }
  const root = await db.doc(`households/${hid}/recurrenceRules/${tid}`).get();
  assert.deepEqual(
    root.get("timeline").map((e) => e.version),
    [1, 3],
  );
  assert.equal((await root.ref.collection("versions").get()).size, 3);
  const audit = await db
    .collection(`households/${hid}/activity`)
    .where("action", "==", "recurrence_rule_saved")
    .where("ruleVersion", "==", 3)
    .get();
  assert.deepEqual(audit.docs[0].get("supersededVersions"), [2]);
});
