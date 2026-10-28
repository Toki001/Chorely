import { before, beforeEach, after, test } from "node:test";
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { initializeApp, deleteApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { createHousehold } from "../functions/lib/households.js";

let app, db;
before(() => {
  assert.ok(process.env.FIRESTORE_EMULATOR_HOST, "Emulator required");
  app = initializeApp({ projectId: "demo-chorely" }, "household-tests");
  db = getFirestore(app);
});
after(async () => {
  await deleteApp(app);
});
beforeEach(async () => {
  const response = await fetch(
    `http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/demo-chorely/databases/(default)/documents`,
    { method: "DELETE" },
  );
  assert.equal(response.ok, true);
});
const adult = {
  uid: "fictional-adult",
  emailVerified: true,
  provider: "password",
  scopedChild: false,
};
const request = () => ({
  name: "Our home",
  nickname: "Alex",
  timezone: "Asia/Manila",
  commandId: randomUUID(),
});
test("Adult creation persists household, role, index and one audit event", async () => {
  const { householdId } = await createHousehold(db, adult, request());
  const home = await db.doc(`households/${householdId}`).get();
  assert.equal(home.get("name"), "Our home");
  assert.equal(home.get("timezoneIana"), "Asia/Manila");
  assert.equal(
    (await home.ref.collection("members").doc(adult.uid).get()).get("role"),
    "guardian",
  );
  assert.equal(
    (await db.doc(`users/${adult.uid}/households/${householdId}`).get()).exists,
    true,
  );
  assert.equal((await home.ref.collection("activity").get()).size, 1);
});
test("Concurrent retry creates exactly one tenant and changed payload replay fails", async () => {
  const data = request();
  const results = await Promise.all([
    createHousehold(db, adult, data),
    createHousehold(db, adult, data),
  ]);
  assert.equal(results[0].householdId, results[1].householdId);
  assert.equal((await db.collection("households").get()).size, 1);
  assert.equal(
    (await db.doc(`users/${adult.uid}`).get()).get("householdsCreated"),
    1,
  );
  await assert.rejects(
    createHousehold(db, adult, { ...data, name: "Other name" }),
    { code: "already-exists" },
  );
});
test("Anonymous, unverified, custom child identities and forged body role denied", async () => {
  for (const actor of [
    null,
    { ...adult, emailVerified: false },
    { ...adult, provider: "anonymous" },
    { ...adult, provider: "custom" },
    { ...adult, scopedChild: true },
  ]) {
    await assert.rejects(
      createHousehold(db, actor, {
        ...request(),
        isAdmin: true,
        role: "guardian",
      }),
    );
  }
  assert.equal((await db.collection("households").get()).size, 0);
});
test("Invalid timezone, oversized text and malformed command ID denied before writes", async () => {
  for (const patch of [
    { timezone: "MadeUp/Zone" },
    { name: "x".repeat(81) },
    { nickname: "" },
    { commandId: "guessable" },
    { name: "bad\nname" },
  ]) {
    await assert.rejects(
      createHousehold(db, adult, { ...request(), ...patch }),
      { code: "invalid-argument" },
    );
  }
  assert.equal((await db.collection("households").get()).size, 0);
});
test("Revoked membership cannot retrieve accepted creation receipt", async () => {
  const data = request();
  const { householdId } = await createHousehold(db, adult, data);
  await db
    .doc(`households/${householdId}/members/${adult.uid}`)
    .update({ status: "revoked" });
  await assert.rejects(createHousehold(db, adult, data), {
    code: "permission-denied",
  });
});
test("Household creation quota cannot be bypassed with new command IDs", async () => {
  for (let i = 0; i < 5; i++) await createHousehold(db, adult, request());
  await assert.rejects(createHousehold(db, adult, request()), {
    code: "resource-exhausted",
  });
  assert.equal((await db.collection("households").get()).size, 5);
});
