import { before, beforeEach, after, test } from "node:test";
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { initializeApp, deleteApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { createHousehold } from "../functions/lib/households.js";
import { addChildProfile } from "../functions/lib/child_access.js";
import {
  defaultNotificationPreferences,
  parseNotificationPreferences,
  getNotificationPreferences,
  saveNotificationPreferences,
} from "../functions/lib/notification_preferences.js";
let app, db, hid, childId;
const guardian = {
  uid: "fictional-guardian",
  emailVerified: true,
  provider: "password",
  scopedChild: false,
};
const adult = { ...guardian, uid: "fictional-adult" };
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
    "notification-preference-tests",
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
  await db
    .doc(`users/${adult.uid}`)
    .set({ accountType: "adult", status: "active" });
  await db
    .doc(`households/${hid}/members/${adult.uid}`)
    .set({ role: "adult", status: "active", canAssign: true });
  await db
    .doc(`households/${hid}/profiles/${adult.uid}`)
    .set({ nickname: "Fictional adult", role: "adult", status: "active" });
});
const request = (actorId = guardian.uid, patch = {}) => ({
  householdId: hid,
  commandId: randomUUID(),
  actorId,
  baseVersion: 0,
  expectedTimezone: "Asia/Manila",
  preferences: defaultNotificationPreferences(),
  ...patch,
});
test("Preferences default to in-app and child settings are readable but guardian-managed", async () => {
  const child = await getNotificationPreferences(db, device, {
    householdId: hid,
    uid: guardian.uid,
    role: "guardian",
  });
  assert.equal(child.actorId, childId);
  assert.equal(child.canEdit, false);
  assert.equal(child.preferences.channel, "in_app");
  await assert.rejects(
    saveNotificationPreferences(db, device, request(childId)),
    { code: "permission-denied" },
  );
  const saved = await saveNotificationPreferences(
    db,
    guardian,
    request(childId),
  );
  assert.equal(saved.version, 1);
  assert.equal(
    (await getNotificationPreferences(db, device, { householdId: hid }))
      .version,
    1,
  );
  await assert.rejects(
    saveNotificationPreferences(db, adult, request(childId)),
    { code: "permission-denied" },
  );
});
test("Adult preferences are private even from another guardian; foreign scopes fail", async () => {
  await saveNotificationPreferences(db, adult, request(adult.uid));
  await assert.rejects(
    getNotificationPreferences(db, guardian, {
      householdId: hid,
      actorId: adult.uid,
    }),
    { code: "permission-denied" },
  );
  await assert.rejects(
    saveNotificationPreferences(db, guardian, request(adult.uid)),
    { code: "permission-denied" },
  );
  await assert.rejects(
    getNotificationPreferences(db, device, {
      householdId: hid,
      actorId: guardian.uid,
    }),
    { code: "permission-denied" },
  );
  await assert.rejects(
    getNotificationPreferences(db, guardian, { householdId: "foreign-home" }),
    { code: "permission-denied" },
  );
  await assert.rejects(
    getNotificationPreferences(db, null, { householdId: hid }),
    { code: "unauthenticated" },
  );
});
test("Concurrent retries save once with a payload-bound receipt and minimal audit", async () => {
  const data = request(childId);
  const [a, b] = await Promise.all([
    saveNotificationPreferences(db, guardian, data),
    saveNotificationPreferences(db, guardian, data),
  ]);
  assert.deepEqual(a, b);
  assert.equal(
    (await db.doc(`rateLimits/${guardian.uid}`).get()).get(
      "notificationPreferenceWrites",
    ),
    1,
  );
  const events = await db
    .collection(`households/${hid}/activity`)
    .where("action", "==", "notification_preferences_saved")
    .get();
  assert.equal(events.size, 1);
  assert.equal(events.docs[0].get("preferences"), undefined);
  assert.equal(events.docs[0].get("quietHours"), undefined);
  await assert.rejects(
    saveNotificationPreferences(db, guardian, {
      ...data,
      preferences: { ...data.preferences, enabled: false },
    }),
    { code: "already-exists" },
  );
});
test("Competing edits, stale zones and revoked accepted retries cannot overwrite settings", async () => {
  const data = request();
  const edits = await Promise.allSettled([
    saveNotificationPreferences(db, guardian, data),
    saveNotificationPreferences(db, guardian, request()),
  ]);
  assert.equal(edits.filter((e) => e.status === "fulfilled").length, 1);
  assert.equal(
    edits.find((e) => e.status === "rejected").reason.code,
    "aborted",
  );
  await assert.rejects(
    saveNotificationPreferences(
      db,
      guardian,
      request(childId, { expectedTimezone: "Etc/UTC" }),
    ),
    { code: "aborted" },
  );
  await db
    .doc(`households/${hid}/members/${guardian.uid}`)
    .update({ status: "revoked" });
  await assert.rejects(saveNotificationPreferences(db, guardian, data), {
    code: "permission-denied",
  });
});
test("Malformed settings and exhausted daily quota fail before mutation", async () => {
  for (const patch of [
    { channel: "email" },
    { reminderMinutes: "15" },
    { reminderMinutes: 16 },
    { due: "yes" },
    { quietHours: { enabled: true, start: "20:00", end: "20:00" } },
  ]) {
    assert.throws(
      () =>
        parseNotificationPreferences({
          ...defaultNotificationPreferences(),
          ...patch,
        }),
      { code: "invalid-argument" },
    );
  }
  const day = new Date().toISOString().slice(0, 10);
  await db
    .doc(`rateLimits/${guardian.uid}`)
    .set({ notificationPreferenceDay: day, notificationPreferenceWrites: 100 });
  await assert.rejects(saveNotificationPreferences(db, guardian, request()), {
    code: "resource-exhausted",
  });
  assert.equal(
    (
      await db
        .doc(`households/${hid}/notificationPreferences/${guardian.uid}`)
        .get()
    ).exists,
    false,
  );
});
