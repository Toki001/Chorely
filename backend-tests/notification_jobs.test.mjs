import { before, beforeEach, after, test } from "node:test";
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { initializeApp, deleteApp } from "firebase-admin/app";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { createHousehold } from "../functions/lib/households.js";
import { addChildProfile } from "../functions/lib/child_access.js";
import { writeOneOffChore } from "../functions/lib/chores.js";
import { actOnOccurrence } from "../functions/lib/completion.js";
import { openNotification } from "../functions/lib/notification_open.js";
import {
  householdDate,
  addCivilDays,
} from "../functions/lib/recurrence_engine.js";
import { reconcileOccurrenceNotifications } from "../functions/lib/notification_jobs.js";
import {
  saveNotificationPreferences,
  defaultNotificationPreferences,
} from "../functions/lib/notification_preferences.js";
let app, db, hid, childId, today;
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
before(() => {
  assert.equal(process.env.FIRESTORE_EMULATOR_HOST, "127.0.0.1:8080");
  app = initializeApp({ projectId: "demo-chorely" }, "notification-job-tests");
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
      commandId: randomUUID(),
      name: "Fictional home",
      nickname: "Alex",
      timezone: "Asia/Manila",
    })
  ).householdId;
  childId = (
    await addChildProfile(db, guardian, {
      householdId: hid,
      nickname: "Fictional child",
      commandId: randomUUID(),
    })
  ).profileId;
  await db
    .doc(`users/${device.uid}`)
    .set({ accountType: "supervised_device", status: "active" });
  await db
    .doc(`households/${hid}/members/${device.uid}`)
    .set({ actorId: childId, role: "child", status: "active" });
});
const input = () => ({
  householdId: hid,
  commandId: randomUUID(),
  action: "create",
  title: "Private title",
  category: "household",
  description: "Private instructions",
  room: "",
  steps: [],
  assignedActorIds: [childId],
  completionPolicy: "any_one_completes",
  reviewMode: "none",
  schedule: { kind: "none", date: today },
});
const jobs = () => db.collection(`households/${hid}/notificationJobs`).get();
const inbox = () => db.collection(`households/${hid}/notificationInbox`).get();
test("Concurrent reconciliation publishes one real inbox copy and preserves its read state across retries/restoration", async () => {
  const saved = await writeOneOffChore(db, guardian, input());
  const a = await Promise.all([
    reconcileOccurrenceNotifications(db, hid, saved.occurrenceId),
    reconcileOccurrenceNotifications(db, hid, saved.occurrenceId),
  ]);
  assert.equal(
    a.reduce((n, r) => n + r.published, 0),
    1,
  );
  assert.equal((await jobs()).size, 1);
  const message = (await inbox()).docs[0];
  const read = Timestamp.now();
  await message.ref.update({ readAt: read });
  assert.equal(
    (await reconcileOccurrenceNotifications(db, hid, saved.occurrenceId))
      .published,
    0,
  );
  await db
    .doc(`households/${hid}/profiles/${childId}`)
    .update({ status: "revoked" });
  assert.equal(
    (await reconcileOccurrenceNotifications(db, hid, saved.occurrenceId))
      .cancelled,
    1,
  );
  await db
    .doc(`households/${hid}/profiles/${childId}`)
    .update({ status: "active" });
  assert.equal(
    (await reconcileOccurrenceNotifications(db, hid, saved.occurrenceId))
      .published,
    0,
  );
  assert.equal(
    (await message.ref.get()).get("readAt").toMillis(),
    read.toMillis(),
  );
  assert.equal((await message.ref.get()).get("active"), true);
  assert.equal(JSON.stringify(message.data()).includes("Private"), false);
});
test("Reassignment cancels the old actor's plan/inbox and creates one new owner generation", async () => {
  const first = input(),
    saved = await writeOneOffChore(db, guardian, first);
  await reconcileOccurrenceNotifications(db, hid, saved.occurrenceId);
  await writeOneOffChore(db, guardian, {
    ...first,
    action: "edit",
    commandId: randomUUID(),
    templateId: saved.templateId,
    occurrenceId: saved.occurrenceId,
    baseTemplateVersion: 1,
    baseOccurrenceVersion: 1,
    assignedActorIds: [guardian.uid],
  });
  const result = await reconcileOccurrenceNotifications(
    db,
    hid,
    saved.occurrenceId,
  );
  assert.equal(result.cancelled, 1);
  assert.equal(result.published, 1);
  const all = await inbox();
  assert.equal(
    all.docs.find((d) => d.get("actorId") === childId).get("active"),
    false,
  );
  assert.equal(
    all.docs.find((d) => d.get("actorId") === guardian.uid).get("active"),
    true,
  );
  assert.equal(
    (
      await db.doc(`households/${hid}/occurrences/${saved.occurrenceId}`).get()
    ).get("assignmentRevision"),
    2,
  );
});
test("Completion before due cancels all old reminders without changing stored task history", async () => {
  const saved = await writeOneOffChore(db, guardian, {
    ...input(),
    schedule: { kind: "time", date: addCivilDays(today, 1), at: "18:00" },
  });
  await reconcileOccurrenceNotifications(db, hid, saved.occurrenceId);
  assert.equal((await jobs()).size, 4);
  await actOnOccurrence(db, device, {
    householdId: hid,
    occurrenceId: saved.occurrenceId,
    commandId: randomUUID(),
    action: "complete",
    baseVersion: 1,
  });
  const result = await reconcileOccurrenceNotifications(
    db,
    hid,
    saved.occurrenceId,
  );
  assert.equal(result.cancelled, 4);
  assert.equal(
    (await jobs()).docs.every((d) => d.get("state") === "cancelled"),
    true,
  );
  assert.equal(
    (await inbox()).docs.every((d) => d.get("active") === false),
    true,
  );
  const stored = await db
    .doc(`households/${hid}/occurrences/${saved.occurrenceId}`)
    .get();
  assert.equal(stored.get("status"), "completed");
  assert.equal(stored.get("version"), 2);
});
test("Quiet hours keep the inbox available while an external alert remains pending, never falsely delivered", async () => {
  await saveNotificationPreferences(db, guardian, {
    householdId: hid,
    actorId: childId,
    commandId: randomUUID(),
    baseVersion: 0,
    expectedTimezone: "Asia/Manila",
    preferences: {
      ...defaultNotificationPreferences(),
      channel: "push",
      quietHours: { enabled: true, start: "11:00", end: "13:00" },
    },
  });
  const saved = await writeOneOffChore(db, guardian, input());
  const clock = Date.parse(`${today}T04:00:00Z`);
  await db.doc(`households/${hid}/occurrences/${saved.occurrenceId}`).update({
    createdAt: Timestamp.fromMillis(clock),
    assignmentChangedAt: Timestamp.fromMillis(clock),
  });
  const result = await reconcileOccurrenceNotifications(
    db,
    hid,
    saved.occurrenceId,
    clock + 1000,
  );
  assert.equal(result.published, 1);
  const job = (await jobs()).docs[0];
  assert.equal(job.get("notifyAtMillis"), clock + 3_600_000);
  assert.equal(job.get("alertState"), "pending");
  assert.equal(job.get("providerAcceptedAt"), undefined);
  assert.equal(job.get("deliveredAt"), undefined);
});
test("Archival and deletion make old jobs inactive rather than recreating task data", async () => {
  const saved = await writeOneOffChore(db, guardian, input());
  await reconcileOccurrenceNotifications(db, hid, saved.occurrenceId);
  await db.doc(`households/${hid}`).update({ archivedAt: Timestamp.now() });
  assert.equal(
    (await reconcileOccurrenceNotifications(db, hid, saved.occurrenceId))
      .cancelled,
    1,
  );
  assert.equal((await inbox()).docs[0].get("active"), false);
  await db.doc(`households/${hid}/occurrences/${saved.occurrenceId}`).delete();
  assert.deepEqual(
    await reconcileOccurrenceNotifications(db, hid, saved.occurrenceId),
    { planned: 0, published: 0, cancelled: 0 },
  );
  assert.equal(
    (await db.doc(`households/${hid}/occurrences/${saved.occurrenceId}`).get())
      .exists,
    false,
  );
});
test("Reminder expiry only cancels notification state; it never invents a missed or completed chore", async () => {
  const saved = await writeOneOffChore(db, guardian, input());
  await reconcileOccurrenceNotifications(db, hid, saved.occurrenceId);
  const expiry = (await jobs()).docs[0].get("expiresAtMillis");
  assert.equal(
    (
      await reconcileOccurrenceNotifications(
        db,
        hid,
        saved.occurrenceId,
        expiry,
      )
    ).cancelled,
    1,
  );
  assert.equal((await inbox()).docs[0].get("active"), false);
  const occurrence = await db
    .doc(`households/${hid}/occurrences/${saved.occurrenceId}`)
    .get();
  assert.equal(occurrence.get("status"), "scheduled");
  assert.equal(occurrence.get("version"), 1);
});
test("Opening an owned update acknowledges once and returns only an authorized current route", async () => {
  const saved = await writeOneOffChore(db, guardian, input());
  await reconcileOccurrenceNotifications(db, hid, saved.occurrenceId);
  const message = (await inbox()).docs[0],
    data = {
      householdId: hid,
      notificationId: message.id,
      role: "guardian",
      uid: guardian.uid,
    };
  const opened = await openNotification(db, device, data);
  assert.equal(opened.available, true);
  assert.equal(opened.occurrenceId, saved.occurrenceId);
  assert.equal(opened.actorId, childId);
  const firstRead = (await message.ref.get()).get("readAt").toMillis();
  await openNotification(db, device, data);
  assert.equal((await message.ref.get()).get("readAt").toMillis(), firstRead);
  assert.equal(
    (
      await db.doc(`households/${hid}/occurrences/${saved.occurrenceId}`).get()
    ).get("version"),
    1,
  );
});
test("Peer actors cannot open or acknowledge another actor's private update", async () => {
  const saved = await writeOneOffChore(db, guardian, input());
  await reconcileOccurrenceNotifications(db, hid, saved.occurrenceId);
  const message = (await inbox()).docs[0];
  assert.deepEqual(
    await openNotification(db, guardian, {
      householdId: hid,
      notificationId: message.id,
    }),
    { available: false },
  );
  assert.equal((await message.ref.get()).get("readAt"), null);
});
test("A child tap after reassignment or deletion falls back even before the worker cancels its old message", async () => {
  const first = input(),
    saved = await writeOneOffChore(db, guardian, first);
  await reconcileOccurrenceNotifications(db, hid, saved.occurrenceId);
  const message = (await inbox()).docs[0];
  await writeOneOffChore(db, guardian, {
    ...first,
    action: "edit",
    commandId: randomUUID(),
    templateId: saved.templateId,
    occurrenceId: saved.occurrenceId,
    baseTemplateVersion: 1,
    baseOccurrenceVersion: 1,
    assignedActorIds: [guardian.uid],
  });
  assert.equal((await message.ref.get()).get("active"), true);
  assert.deepEqual(
    await openNotification(db, device, {
      householdId: hid,
      notificationId: message.id,
    }),
    { available: false },
  );
  await db.doc(`households/${hid}/occurrences/${saved.occurrenceId}`).delete();
  assert.deepEqual(
    await openNotification(db, device, {
      householdId: hid,
      notificationId: message.id,
    }),
    { available: false },
  );
});
test("Stale device membership, unauthenticated taps and foreign homes cannot resolve a notification", async () => {
  const saved = await writeOneOffChore(db, guardian, input());
  await reconcileOccurrenceNotifications(db, hid, saved.occurrenceId);
  const data = { householdId: hid, notificationId: (await inbox()).docs[0].id };
  await assert.rejects(openNotification(db, null, data), {
    code: "unauthenticated",
  });
  await assert.rejects(
    openNotification(db, device, { ...data, householdId: "foreign-home" }),
    { code: "permission-denied" },
  );
  await db
    .doc(`households/${hid}/members/${device.uid}`)
    .update({ status: "revoked" });
  await assert.rejects(openNotification(db, device, data), {
    code: "permission-denied",
  });
});

test("Local tap before inbox publication validates private current job and acknowledges exactly once", async () => {
  const { getLocalNotificationPlan } =
    await import("../functions/lib/notification_local_plan.js");
  const prefs = {
    ...defaultNotificationPreferences(),
    channel: "local",
    quietHours: { enabled: false, start: "20:00", end: "08:00" },
  };
  await saveNotificationPreferences(db, guardian, {
    householdId: hid,
    actorId: childId,
    commandId: randomUUID(),
    baseVersion: 0,
    expectedTimezone: "Asia/Manila",
    preferences: prefs,
  });
  const saved = await writeOneOffChore(db, guardian, input());
  await reconcileOccurrenceNotifications(db, hid, saved.occurrenceId);
  const plan = await getLocalNotificationPlan(db, device, {
    householdId: hid,
    actorId: guardian.uid,
  });
  assert.equal(plan.actorId, childId);
  assert.equal(plan.policyEnabled, true);
  assert.equal(plan.reminders.length, 1);
  const id = plan.reminders[0].id;
  await db.doc(`households/${hid}/notificationInbox/${id}`).delete();
  const value = await openNotification(db, device, {
    householdId: hid,
    notificationId: id,
  });
  assert.equal(value.available, true);
  assert.equal(value.occurrenceId, saved.occurrenceId);
  const read = (await inbox()).docs[0].get("readAt").toMillis();
  await openNotification(db, device, { householdId: hid, notificationId: id });
  assert.equal((await inbox()).docs[0].get("readAt").toMillis(), read);
  // Current occurrence mutation invalidates a cached OS plan before the worker.
  await db.doc(`households/${hid}/notificationInbox/${id}`).delete();
  await db
    .doc(`households/${hid}/occurrences/${saved.occurrenceId}`)
    .update({ version: 2 });
  assert.deepEqual(
    await openNotification(db, device, {
      householdId: hid,
      notificationId: id,
    }),
    { available: false },
  );
  assert.equal((await inbox()).size, 0);
});

test("Local plans are disabled by default and cancel after completion or policy changes", async () => {
  const { getLocalNotificationPlan } =
    await import("../functions/lib/notification_local_plan.js");
  const saved = await writeOneOffChore(db, guardian, input());
  await reconcileOccurrenceNotifications(db, hid, saved.occurrenceId);
  assert.equal(
    (await getLocalNotificationPlan(db, device, { householdId: hid }))
      .policyEnabled,
    false,
  );
  const prefs = {
    ...defaultNotificationPreferences(),
    channel: "local",
    quietHours: { enabled: false, start: "20:00", end: "08:00" },
  };
  await saveNotificationPreferences(db, guardian, {
    householdId: hid,
    actorId: childId,
    commandId: randomUUID(),
    baseVersion: 0,
    expectedTimezone: "Asia/Manila",
    preferences: prefs,
  });
  await reconcileOccurrenceNotifications(db, hid, saved.occurrenceId);
  const plan = await getLocalNotificationPlan(db, device, { householdId: hid });
  assert.equal(plan.reminders.length, 1);
  assert.ok(!JSON.stringify(plan).includes("Private"));
  const signal = await db
    .doc(`households/${hid}/reminderPlanSignals/${childId}`)
    .get();
  assert.ok(signal.get("version") >= 2);
  await actOnOccurrence(db, device, {
    householdId: hid,
    occurrenceId: saved.occurrenceId,
    commandId: randomUUID(),
    action: "complete",
    baseVersion: 1,
  });
  assert.equal(
    (await getLocalNotificationPlan(db, device, { householdId: hid })).reminders
      .length,
    0,
  );
  await db
    .doc(`households/${hid}/members/${device.uid}`)
    .update({ status: "revoked" });
  await assert.rejects(
    getLocalNotificationPlan(db, device, { householdId: hid }),
    { code: "permission-denied" },
  );
});
