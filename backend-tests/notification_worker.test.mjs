import { before, beforeEach, after, test } from "node:test";
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { initializeApp, deleteApp } from "firebase-admin/app";
import { getFirestore, Timestamp, FieldValue } from "firebase-admin/firestore";
import { createHousehold } from "../functions/lib/households.js";
import { addChildProfile } from "../functions/lib/child_access.js";
import { writeOneOffChore } from "../functions/lib/chores.js";
import { actOnOccurrence } from "../functions/lib/completion.js";
import { householdDate } from "../functions/lib/recurrence_engine.js";
import {
  saveNotificationPreferences,
  defaultNotificationPreferences,
} from "../functions/lib/notification_preferences.js";
import { reconcileOccurrenceNotifications } from "../functions/lib/notification_jobs.js";
import { runNotificationWorker } from "../functions/lib/notification_worker.js";
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
  app = initializeApp(
    { projectId: "demo-chorely" },
    "notification-worker-tests",
  );
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
  title: "Fictional chore",
  category: "household",
  description: "",
  room: "",
  steps: [],
  assignedActorIds: [childId],
  completionPolicy: "any_one_completes",
  reviewMode: "none",
  schedule: { kind: "none", date: today },
});
const inbox = () => db.collection(`households/${hid}/notificationInbox`).get();
test("Accepted retries enqueue one durable source revision and the worker publishes one inbox copy", async () => {
  const data = input();
  await writeOneOffChore(db, guardian, data);
  await writeOneOffChore(db, guardian, data);
  assert.equal((await db.collection("notificationOutbox").get()).size, 1);
  assert.equal((await runNotificationWorker(db)).sources, 1);
  assert.equal((await inbox()).size, 1);
  assert.equal((await runNotificationWorker(db)).sources, 0);
  assert.equal((await inbox()).size, 1);
});
test("Two revisions sharing a clock millisecond remain queued; obsolete intermediate alerts coalesce", async () => {
  const saved = await writeOneOffChore(db, guardian, input());
  await actOnOccurrence(db, device, {
    householdId: hid,
    occurrenceId: saved.occurrenceId,
    commandId: randomUUID(),
    baseVersion: 1,
    action: "complete",
  });
  const sources = await db.collection("notificationOutbox").get(),
    same = Date.now();
  assert.equal(sources.size, 2);
  for (const source of sources.docs)
    await source.ref.update({
      nextAttemptAtMillis: same,
      createdAt: Timestamp.fromMillis(same),
    });
  assert.equal((await runNotificationWorker(db, same)).sources, 2);
  assert.equal((await inbox()).size, 0);
  assert.equal(
    (
      await db
        .collection("notificationOutbox")
        .where("state", "==", "done")
        .get()
    ).size,
    2,
  );
});
test("Replay after an inbox commit but before source acknowledgement preserves one copy and read state", async () => {
  const saved = await writeOneOffChore(db, guardian, input());
  await reconcileOccurrenceNotifications(db, hid, saved.occurrenceId);
  const message = (await inbox()).docs[0],
    read = Timestamp.now();
  await message.ref.update({ readAt: read });
  assert.equal((await runNotificationWorker(db)).sources, 1);
  assert.equal((await inbox()).size, 1);
  assert.equal(
    (await message.ref.get()).get("readAt").toMillis(),
    read.toMillis(),
  );
});
test("Held worker lease leaves work pending; a later pass recovers it", async () => {
  await writeOneOffChore(db, guardian, input());
  await db
    .doc("schedulerLeases/notifications")
    .set({ owner: "held-test-lease", untilMillis: Date.now() + 30_000 });
  assert.equal((await runNotificationWorker(db)).leased, true);
  assert.equal((await inbox()).size, 0);
  await db.doc("schedulerLeases/notifications").update({ untilMillis: 0 });
  assert.equal((await runNotificationWorker(db)).sources, 1);
});
test("A saved preference atomically requests a sweep that cancels existing jobs", async () => {
  const saved = await writeOneOffChore(db, guardian, input());
  await runNotificationWorker(db);
  await saveNotificationPreferences(db, guardian, {
    householdId: hid,
    actorId: childId,
    commandId: randomUUID(),
    baseVersion: 0,
    expectedTimezone: "Asia/Manila",
    preferences: { ...defaultNotificationPreferences(), enabled: false },
  });
  assert.equal(
    (await db.doc(`notificationHouseholdRefresh/${hid}`).get()).get("state"),
    "pending",
  );
  assert.equal((await runNotificationWorker(db)).refreshed, 1);
  assert.equal((await inbox()).docs[0].get("active"), false);
  assert.equal(
    (
      await db.doc(`households/${hid}/occurrences/${saved.occurrenceId}`).get()
    ).get("version"),
    1,
  );
});
test("A corrupt source backs off durably without starving healthy work and stops after five failures", async () => {
  const bad = await writeOneOffChore(db, guardian, input());
  await db
    .doc(`households/${hid}/occurrences/${bad.occurrenceId}`)
    .update({ createdAt: FieldValue.delete() });
  await writeOneOffChore(db, guardian, input());
  const first = await runNotificationWorker(db);
  assert.equal(first.failed, 1);
  assert.equal(first.sources, 1);
  assert.equal((await inbox()).size, 1);
  let queued = (
    await db
      .collection("notificationOutbox")
      .where("state", "==", "pending")
      .get()
  ).docs[0];
  for (let n = 2; n <= 5; n++) {
    await runNotificationWorker(db, queued.get("nextAttemptAtMillis"));
    queued = await queued.ref.get();
  }
  assert.equal(queued.get("state"), "needs_attention");
  assert.equal(queued.get("attempts"), 5);
  assert.equal(queued.get("errorCode"), "notification_occurrence_missing_time");
});
test("Bounded pages drain twenty-five sources at a time without duplicate inbox entries", async () => {
  for (let i = 0; i < 26; i++) await writeOneOffChore(db, guardian, input());
  assert.equal((await runNotificationWorker(db)).sources, 25);
  assert.equal((await inbox()).size, 25);
  assert.equal((await runNotificationWorker(db)).sources, 1);
  assert.equal((await inbox()).size, 26);
});

test("Re-enabling a policy restores existing messages without resetting read state and creates previously disabled jobs", async () => {
  const pref = (version, enabled) =>
    saveNotificationPreferences(db, guardian, {
      householdId: hid,
      actorId: childId,
      commandId: randomUUID(),
      baseVersion: version,
      expectedTimezone: "Asia/Manila",
      preferences: { ...defaultNotificationPreferences(), enabled },
    });
  await writeOneOffChore(db, guardian, input());
  await runNotificationWorker(db);
  const message = (await inbox()).docs[0],
    read = Timestamp.now();
  await message.ref.update({ readAt: read });
  await pref(0, false);
  await runNotificationWorker(db);
  assert.equal((await message.ref.get()).get("active"), false);
  await writeOneOffChore(db, guardian, input());
  await runNotificationWorker(db);
  assert.equal((await inbox()).size, 1);
  await pref(1, true);
  await runNotificationWorker(db);
  const messages = await inbox();
  assert.equal(messages.size, 2);
  assert.ok(messages.docs.every((d) => d.get("active") === true));
  assert.equal(
    (await message.ref.get()).get("readAt").toMillis(),
    read.toMillis(),
  );
});

test("Preference sweeps page twenty-five actual occurrences and retain a durable cursor", async () => {
  await saveNotificationPreferences(db, guardian, {
    householdId: hid,
    actorId: childId,
    commandId: randomUUID(),
    baseVersion: 0,
    expectedTimezone: "Asia/Manila",
    preferences: { ...defaultNotificationPreferences(), enabled: false },
  });
  for (let i = 0; i < 26; i++) await writeOneOffChore(db, guardian, input());
  await runNotificationWorker(db);
  await runNotificationWorker(db);
  assert.equal((await inbox()).size, 0);
  await saveNotificationPreferences(db, guardian, {
    householdId: hid,
    actorId: childId,
    commandId: randomUUID(),
    baseVersion: 1,
    expectedTimezone: "Asia/Manila",
    preferences: defaultNotificationPreferences(),
  });
  assert.equal((await runNotificationWorker(db)).refreshed, 25);
  assert.equal((await inbox()).size, 25);
  assert.equal(
    (await db.doc(`notificationHouseholdRefresh/${hid}`).get()).get("state"),
    "pending",
  );
  assert.equal((await runNotificationWorker(db)).refreshed, 1);
  assert.equal((await inbox()).size, 26);
  assert.equal(
    (await db.doc(`notificationHouseholdRefresh/${hid}`).get()).get("state"),
    "done",
  );
});
