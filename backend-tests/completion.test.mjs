import { before, beforeEach, after, test } from "node:test";
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { initializeApp, deleteApp } from "firebase-admin/app";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { createHousehold } from "../functions/lib/households.js";
import { addChildProfile } from "../functions/lib/child_access.js";
import { writeOneOffChore } from "../functions/lib/chores.js";
import { actOnOccurrence } from "../functions/lib/completion.js";
import {
  saveRule,
  materializeRule,
} from "../functions/lib/recurrence_service.js";
import {
  householdDate,
  addCivilDays,
} from "../functions/lib/recurrence_engine.js";
let app, db, hid, profileId, today;
const guardian = {
  uid: "fictional-guardian",
  emailVerified: true,
  provider: "password",
  scopedChild: false,
};
const device = {
  uid: "fictional-device",
  emailVerified: false,
  provider: "custom",
  scopedChild: true,
};
const second = { ...device, uid: "fictional-device-two" };
before(() => {
  assert.ok(process.env.FIRESTORE_EMULATOR_HOST);
  app = initializeApp({ projectId: "demo-chorely" }, "completion-tests");
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
  profileId = (
    await addChildProfile(db, guardian, {
      householdId: hid,
      nickname: "Fictional child",
      commandId: randomUUID(),
    })
  ).profileId;
  for (const actor of [device, second]) {
    await db
      .doc(`users/${actor.uid}`)
      .set({ accountType: "supervised_device", status: "active" });
    await db
      .doc(`households/${hid}/members/${actor.uid}`)
      .set({ actorId: profileId, role: "child", status: "active" });
  }
});
async function chore(patch = {}) {
  return writeOneOffChore(db, guardian, {
    householdId: hid,
    commandId: randomUUID(),
    action: "create",
    title: "Cook rice",
    category: "dinner",
    room: "",
    description: "",
    steps: [],
    assignedActorIds: [profileId],
    completionPolicy: "any_one_completes",
    reviewMode: "none",
    schedule: { kind: "none", date: today },
    ...patch,
  });
}
const cmd = (created, action = "complete", baseVersion = 1, patch = {}) => ({
  householdId: hid,
  occurrenceId: created.occurrenceId,
  commandId: randomUUID(),
  baseVersion,
  action,
  ...patch,
});
const ref = (created) =>
  db.doc(`households/${hid}/occurrences/${created.occurrenceId}`);
test("Two devices for one child complete exactly once; accepted retry and changed payload are bound", async () => {
  const created = await chore(),
    a = cmd(created),
    b = cmd(created);
  const results = await Promise.allSettled([
    actOnOccurrence(db, device, a),
    actOnOccurrence(db, second, b),
  ]);
  assert.equal(results.filter((r) => r.status === "fulfilled").length, 1);
  assert.equal(
    results.find((r) => r.status === "rejected").reason.code,
    "aborted",
  );
  const winner = results[0].status === "fulfilled" ? [device, a] : [second, b];
  assert.equal((await actOnOccurrence(db, ...winner)).version, 2);
  await assert.rejects(
    actOnOccurrence(db, winner[0], { ...winner[1], note: "Changed payload" }),
    { code: "already-exists" },
  );
  const stored = await ref(created).get();
  assert.equal(stored.get("status"), "completed");
  assert.deepEqual(Object.keys(stored.get("contributions")), [profileId]);
  assert.equal(
    (
      await db
        .collection(`households/${hid}/activity`)
        .where("action", "==", "occurrence_complete")
        .get()
    ).size,
    1,
  );
});
test("Child submission waits for a separate guardian; self-review is denied and privately logged", async () => {
  const created = await chore({ reviewMode: "guardian" });
  assert.equal(
    (await actOnOccurrence(db, device, cmd(created))).status,
    "pending_review",
  );
  const attempt = cmd(created, "approve", 2);
  await assert.rejects(actOnOccurrence(db, device, attempt), {
    code: "permission-denied",
  });
  await assert.rejects(actOnOccurrence(db, device, attempt), {
    code: "permission-denied",
  });
  assert.equal((await db.collection("securityEvents").get()).size, 1);
  assert.equal((await ref(created).get()).get("status"), "pending_review");
  assert.equal(
    (await actOnOccurrence(db, guardian, cmd(created, "approve", 2))).status,
    "approved",
  );
  await assert.rejects(actOnOccurrence(db, device, cmd(created, "undo", 3)), {
    code: "failed-precondition",
  });
});
test("All-member contributions are actual individual records; undo ends after a dependent completion", async () => {
  const created = await chore({
    assignedActorIds: [guardian.uid, profileId],
    completionPolicy: "all_members_complete",
  });
  assert.equal(
    (await actOnOccurrence(db, guardian, cmd(created))).status,
    "scheduled",
  );
  assert.equal(
    (await actOnOccurrence(db, device, cmd(created, "complete", 2))).status,
    "completed",
  );
  await assert.rejects(actOnOccurrence(db, guardian, cmd(created, "undo", 3)), {
    code: "failed-precondition",
  });
  assert.equal(
    (await actOnOccurrence(db, device, cmd(created, "undo", 3))).status,
    "scheduled",
  );
  assert.deepEqual(
    Object.keys((await ref(created).get()).get("contributions")),
    [guardian.uid],
  );
  await assert.rejects(actOnOccurrence(db, guardian, cmd(created, "undo", 4)), {
    code: "failed-precondition",
  });
});
test("A completing guardian cannot approve their own work even with a guardian role", async () => {
  const reviewer = { ...guardian, uid: "fictional-other-guardian" };
  await db
    .doc(`households/${hid}/members/${reviewer.uid}`)
    .set({ role: "guardian", status: "active" });
  await db.doc(`households/${hid}/profiles/${reviewer.uid}`).set({
    nickname: "Fictional reviewer",
    role: "guardian",
    status: "active",
  });
  const created = await chore({
    assignedActorIds: [guardian.uid],
    reviewMode: "guardian",
  });
  await actOnOccurrence(db, guardian, cmd(created));
  await assert.rejects(
    actOnOccurrence(db, guardian, cmd(created, "approve", 2)),
    { code: "permission-denied" },
  );
  assert.equal(
    (await actOnOccurrence(db, reviewer, cmd(created, "approve", 2))).status,
    "approved",
  );
});
test("Redo needs a reason, clears current contributions and keeps previous audit; undo restores redo state", async () => {
  const created = await chore({ reviewMode: "guardian" });
  await actOnOccurrence(db, device, cmd(created));
  await assert.rejects(actOnOccurrence(db, guardian, cmd(created, "redo", 2)), {
    code: "invalid-argument",
  });
  assert.equal(
    (
      await actOnOccurrence(
        db,
        guardian,
        cmd(created, "redo", 2, { note: "Please revisit step two." }),
      )
    ).status,
    "needs_redo",
  );
  assert.deepEqual((await ref(created).get()).get("contributions"), {});
  await actOnOccurrence(db, device, cmd(created, "complete", 3));
  assert.equal(
    (await actOnOccurrence(db, device, cmd(created, "undo", 4))).status,
    "needs_redo",
  );
  assert.equal(
    (await ref(created).get()).get("reviewNote"),
    "Please revisit step two.",
  );
  assert.equal(
    (
      await db
        .collection(`households/${hid}/activity`)
        .where("action", "==", "occurrence_complete")
        .get()
    ).size,
    2,
  );
  const redoAudit = await db
    .collection(`households/${hid}/activity`)
    .where("action", "==", "occurrence_redo")
    .get();
  assert.equal(redoAudit.docs[0].get("reviewNote"), "Please revisit step two.");
});
test("Undo uses stored server acceptance time and ignores a forged client clock", async () => {
  const created = await chore();
  await actOnOccurrence(db, device, cmd(created));
  const data = (await ref(created).get()).get("contributions");
  data[profileId].acceptedAt = Timestamp.fromMillis(Date.now() - 300_100);
  await ref(created).update({ contributions: data });
  await assert.rejects(
    actOnOccurrence(db, device, cmd(created, "undo", 2, { serverNow: 0 })),
    { code: "failed-precondition" },
  );
  assert.equal((await ref(created).get()).get("status"), "completed");
});
test("Help stores a private note, never completes, and a manager can acknowledge it without progress", async () => {
  const created = await chore();
  const request = cmd(created, "help", 1, { note: "Please show step two." });
  await actOnOccurrence(db, device, request);
  await actOnOccurrence(db, device, request);
  let stored = await ref(created).get();
  assert.equal(stored.get("status"), "scheduled");
  assert.equal(stored.get("completionRevision"), undefined);
  const help = stored.get("helpRequests")[profileId];
  assert.equal(help.note, undefined);
  assert.equal(
    (
      await db.doc(`households/${hid}/helpRequests/${help.requestId}`).get()
    ).get("note"),
    "Please show step two.",
  );
  await assert.rejects(actOnOccurrence(db, device, cmd(created, "help", 2)), {
    code: "aborted",
  });
  await actOnOccurrence(
    db,
    guardian,
    cmd(created, "resolve_help", 2, { targetActorId: profileId }),
  );
  stored = await ref(created).get();
  assert.equal(stored.get("status"), "scheduled");
  assert.equal(stored.get("helpRequests")[profileId].status, "resolved");
  await actOnOccurrence(db, device, cmd(created, "help", 3));
  assert.equal(
    (await db.collection(`households/${hid}/helpRequests`).get()).size,
    2,
  );
});
test("An independent help request does not remove the last contributor's valid undo", async () => {
  const created = await chore({
    assignedActorIds: [guardian.uid, profileId],
    completionPolicy: "all_members_complete",
  });
  await actOnOccurrence(db, guardian, cmd(created));
  await actOnOccurrence(db, device, cmd(created, "help", 2));
  assert.equal(
    (await actOnOccurrence(db, guardian, cmd(created, "undo", 3))).status,
    "scheduled",
  );
  assert.deepEqual((await ref(created).get()).get("contributions"), {});
});
test("Revocation, unrelated assignment, child profile removal and forged body role deny actions and receipts", async () => {
  const created = await chore();
  const accepted = cmd(created);
  await actOnOccurrence(db, device, accepted);
  await assert.rejects(actOnOccurrence(db, null, cmd(created)), {
    code: "unauthenticated",
  });
  await assert.rejects(
    actOnOccurrence(db, { ...guardian, uid: "unrelated" }, cmd(created)),
    { code: "permission-denied" },
  );
  await db
    .doc(`households/${hid}/members/${device.uid}`)
    .update({ status: "revoked" });
  await assert.rejects(actOnOccurrence(db, device, accepted), {
    code: "permission-denied",
  });
  await db
    .doc(`households/${hid}/profiles/${profileId}`)
    .update({ status: "revoked" });
  await assert.rejects(
    actOnOccurrence(
      db,
      second,
      cmd(created, "undo", 2, { role: "guardian", actorId: guardian.uid }),
    ),
    { code: "permission-denied" },
  );
});
test("Partial recorded work cannot be silently edited; stale actions and cancelled occurrences fail", async () => {
  const created = await chore({
    assignedActorIds: [guardian.uid, profileId],
    completionPolicy: "all_members_complete",
  });
  await actOnOccurrence(db, guardian, cmd(created));
  await assert.rejects(actOnOccurrence(db, device, cmd(created)), {
    code: "aborted",
  });
  await assert.rejects(
    writeOneOffChore(db, guardian, {
      householdId: hid,
      commandId: randomUUID(),
      action: "edit",
      ...created,
      baseTemplateVersion: 1,
      baseOccurrenceVersion: 2,
      title: "Changed",
      category: "dinner",
      room: "",
      steps: [],
      assignedActorIds: [guardian.uid],
      completionPolicy: "any_one_completes",
      reviewMode: "none",
      schedule: { kind: "none", date: today },
    }),
    { code: "failed-precondition" },
  );
  await writeOneOffChore(db, guardian, {
    householdId: hid,
    commandId: randomUUID(),
    action: "archive",
    ...created,
    baseTemplateVersion: 1,
    baseOccurrenceVersion: 2,
  });
  await assert.rejects(
    actOnOccurrence(db, device, cmd(created, "complete", 3)),
    { code: "failed-precondition" },
  );
});
test("Completing today's occurrence leaves the reusable definition and all future turns unchanged", async () => {
  const created = await chore();
  await saveRule(db, guardian, {
    householdId: hid,
    templateId: created.templateId,
    commandId: randomUUID(),
    baseTemplateVersion: 1,
    baseRuleVersion: 0,
    expectedTimezone: "Asia/Manila",
    effectiveFrom: addCivilDays(today, 1),
    paused: false,
    rule: {
      frequency: "daily",
      startDate: addCivilDays(today, 1),
      endDate: null,
      count: null,
      weekdays: [],
      monthDay: null,
      timing: { kind: "none", at: null, endAt: null, endDayOffset: 0 },
      rotation: { order: [profileId], policy: "preserve_turn" },
      exceptions: [],
    },
  });
  const template = db.doc(
    `households/${hid}/choreTemplates/${created.templateId}`,
  );
  const definition = (await template.get()).data();
  const future = (
    await db
      .collection(`households/${hid}/occurrences`)
      .where("recurrenceVersion", "==", 1)
      .get()
  ).docs.map((d) => ({ id: d.id, data: d.data() }));
  await actOnOccurrence(db, device, cmd(created));
  await materializeRule(db, hid, created.templateId);
  assert.deepEqual((await template.get()).data(), definition);
  for (const row of future)
    assert.deepEqual(
      (await db.doc(`households/${hid}/occurrences/${row.id}`).get()).data(),
      row.data,
    );
});

test("A future one-off with partial work cannot acquire a second active identity through recurrence conversion", async () => {
  const date = addCivilDays(today, 2);
  const created = await chore({
    assignedActorIds: [guardian.uid, profileId],
    completionPolicy: "all_members_complete",
    schedule: { kind: "none", date },
  });
  await actOnOccurrence(db, guardian, cmd(created));
  const input = {
    householdId: hid,
    templateId: created.templateId,
    commandId: randomUUID(),
    baseTemplateVersion: 1,
    baseRuleVersion: 0,
    expectedTimezone: "Asia/Manila",
    effectiveFrom: addCivilDays(today, 1),
    paused: false,
    rule: {
      frequency: "daily",
      startDate: addCivilDays(today, 1),
      endDate: null,
      count: null,
      weekdays: [],
      monthDay: null,
      timing: { kind: "none", at: null, endAt: null, endDayOffset: 0 },
      rotation: { order: [profileId], policy: "preserve_turn" },
      exceptions: [],
    },
  };
  await assert.rejects(saveRule(db, guardian, input), {
    code: "failed-precondition",
  });
  assert.equal(
    (await db.collection(`households/${hid}/recurrenceRules`).get()).size,
    0,
  );
  const snapshot = (await ref(created).get()).data();
  await saveRule(db, guardian, {
    ...input,
    effectiveFrom: addCivilDays(today, 3),
  });
  assert.deepEqual((await ref(created).get()).data(), snapshot);
});
