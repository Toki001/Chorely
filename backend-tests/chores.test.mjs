import { before, beforeEach, after, test } from "node:test";
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { initializeApp, deleteApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { createHousehold } from "../functions/lib/households.js";
import { addChildProfile } from "../functions/lib/child_access.js";
import { writeOneOffChore } from "../functions/lib/chores.js";
import { resolveLocalMinute } from "../functions/lib/local_time.js";
let app, db, hid, childId;
const guardian = {
  uid: "fictional-guardian",
  emailVerified: true,
  provider: "password",
  scopedChild: false,
};
before(() => {
  assert.ok(process.env.FIRESTORE_EMULATOR_HOST);
  app = initializeApp({ projectId: "demo-chorely" }, "chore-tests");
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
const input = () => ({
  action: "create",
  householdId: hid,
  commandId: randomUUID(),
  title: "Cook rice",
  category: "dinner",
  description: "Household instructions",
  steps: ["Ask a guardian for the household instructions."],
  assignedActorIds: [childId],
  completionPolicy: "any_one_completes",
  reviewMode: "guardian",
  schedule: { kind: "time", date: "2026-10-30", at: "18:30" },
});
const path = (r) => `households/${hid}/occurrences/${r.occurrenceId}`;
test("Concurrent retries persist one definition, one concrete assignment and one audit event", async () => {
  const data = input();
  const [a, b] = await Promise.all([
    writeOneOffChore(db, guardian, data),
    writeOneOffChore(db, guardian, data),
  ]);
  assert.deepEqual(a, b);
  assert.equal(
    (await db.collection(`households/${hid}/choreTemplates`).get()).size,
    1,
  );
  const occurrences = await db
    .collection(`households/${hid}/occurrences`)
    .get();
  assert.equal(occurrences.size, 1);
  assert.equal(
    occurrences.docs[0].get("dueAtUtc").toDate().toISOString(),
    "2026-10-30T10:30:00.000Z",
  );
  assert.deepEqual(occurrences.docs[0].get("assignedActorIds"), [childId]);
  assert.equal(
    (
      await db
        .collection(`households/${hid}/activity`)
        .where("action", "==", "chore_create")
        .get()
    ).size,
    1,
  );
  assert.equal(
    (await db.doc(`rateLimits/${guardian.uid}`).get()).get("choreWrites"),
    1,
  );
  await assert.rejects(
    writeOneOffChore(db, guardian, { ...data, title: "Changed retry" }),
    { code: "already-exists" },
  );
});
test("Two concurrent edits produce one accepted revision and a visible version conflict", async () => {
  const data = input();
  const created = await writeOneOffChore(db, guardian, data);
  const edit = {
    ...data,
    ...created,
    action: "edit",
    commandId: randomUUID(),
    baseTemplateVersion: 1,
    baseOccurrenceVersion: 1,
    title: "Cook rice together",
  };
  const results = await Promise.allSettled([
    writeOneOffChore(db, guardian, edit),
    writeOneOffChore(db, guardian, {
      ...edit,
      commandId: randomUUID(),
      title: "Another edit",
    }),
  ]);
  assert.equal(results.filter((r) => r.status === "fulfilled").length, 1);
  assert.equal(
    results.find((r) => r.status === "rejected").reason.code,
    "aborted",
  );
  assert.equal((await db.doc(path(created)).get()).get("version"), 2);
  await assert.rejects(
    writeOneOffChore(db, guardian, {
      ...edit,
      action: "archive",
      commandId: randomUUID(),
    }),
    { code: "aborted" },
  );
  const archived = await writeOneOffChore(db, guardian, {
    ...edit,
    action: "archive",
    commandId: randomUUID(),
    baseTemplateVersion: 2,
    baseOccurrenceVersion: 2,
  });
  assert.equal(archived.version, 3);
  assert.equal((await db.doc(path(created)).get()).get("status"), "cancelled");
  assert.equal(
    (
      await db
        .doc(`households/${hid}/choreTemplates/${created.templateId}`)
        .get()
    ).get("active"),
    false,
  );
});
test("Tenant outsiders, children, revoked members and ordinary adults cannot assign", async () => {
  const ordinary = { ...guardian, uid: "ordinary" };
  await db
    .doc(`households/${hid}/members/ordinary`)
    .set({ status: "active", role: "adult", canAssign: false });
  for (const actor of [
    null,
    { ...guardian, uid: "outsider" },
    { ...guardian, scopedChild: true },
    ordinary,
  ])
    await assert.rejects(writeOneOffChore(db, actor, input()));
  await db
    .doc(`households/${hid}/members/ordinary`)
    .update({ canAssign: true });
  await writeOneOffChore(db, ordinary, input());
  await db.doc(`users/ordinary`).set({ accountType: "supervised_device" });
  await assert.rejects(writeOneOffChore(db, ordinary, input()), {
    code: "permission-denied",
  });
  const data = input();
  await writeOneOffChore(db, guardian, data);
  await db
    .doc(`households/${hid}/members/${guardian.uid}`)
    .update({ status: "revoked" });
  await assert.rejects(writeOneOffChore(db, guardian, data), {
    code: "permission-denied",
  });
});
test("Invalid dates, unavailable assignees, duplicate team members and self-review are rejected", async () => {
  for (const patch of [
    { title: "" },
    { instructionIllustrationKey: "https://untrusted.example/image.png" },
    { category: "unknown" },
    { steps: Array(13).fill("step") },
    { assignedActorIds: ["outside-profile"] },
    { assignedActorIds: [childId, childId] },
    { completionPolicy: "automatic" },
    { schedule: { kind: "time", date: "2026-02-30", at: "18:00" } },
    { schedule: { kind: "time", date: "2026-10-30", at: "25:00" } },
    {
      schedule: {
        kind: "range",
        date: "2026-10-30",
        startLocal: "2026-10-30T22:00",
        endLocal: "2026-10-30T21:00",
      },
    },
  ])
    await assert.rejects(
      writeOneOffChore(db, guardian, { ...input(), ...patch }),
      { code: "invalid-argument" },
    );
  await assert.rejects(
    writeOneOffChore(db, guardian, {
      ...input(),
      assignedActorIds: [guardian.uid],
    }),
    { code: "failed-precondition" },
  );
  await db
    .doc(`households/${hid}/profiles/${childId}`)
    .update({ status: "revoked" });
  await assert.rejects(writeOneOffChore(db, guardian, input()), {
    code: "invalid-argument",
  });
  assert.equal(
    (await db.collection(`households/${hid}/occurrences`).get()).size,
    0,
  );
});
test("Date-only and cross-midnight windows preserve household dates; completed history cannot be edited", async () => {
  const plain = await writeOneOffChore(db, guardian, {
    ...input(),
    schedule: { kind: "none", date: "2026-10-30" },
  });
  assert.equal((await db.doc(path(plain)).get()).get("dueAtUtc"), null);
  const window = await writeOneOffChore(db, guardian, {
    ...input(),
    schedule: {
      kind: "range",
      date: "2026-10-30",
      startLocal: "2026-10-30T22:00",
      endLocal: "2026-10-31T01:00",
    },
  });
  const saved = await db.doc(path(window)).get();
  assert.equal(
    saved.get("windowStartAtUtc").toDate().toISOString(),
    "2026-10-30T14:00:00.000Z",
  );
  assert.equal(
    saved.get("dueAtUtc").toDate().toISOString(),
    "2026-10-30T17:00:00.000Z",
  );
  await saved.ref.update({ status: "completed" });
  await assert.rejects(
    writeOneOffChore(db, guardian, {
      ...input(),
      ...window,
      action: "edit",
      baseTemplateVersion: 1,
      baseOccurrenceVersion: 1,
    }),
    { code: "failed-precondition" },
  );
});
test("Household wall-clock resolver selects first valid gap minute and earlier overlap instant", () => {
  for (const [wall, zone, iso, effective] of [
    [
      "2026-03-08T02:30",
      "America/New_York",
      "2026-03-08T07:00:00.000Z",
      "2026-03-08T03:00",
    ],
    [
      "2026-11-01T01:30",
      "America/New_York",
      "2026-11-01T05:30:00.000Z",
      "2026-11-01T01:30",
    ],
    [
      "2026-10-04T02:15",
      "Australia/Lord_Howe",
      "2026-10-03T15:30:00.000Z",
      "2026-10-04T02:30",
    ],
    [
      "2011-12-30T12:00",
      "Pacific/Apia",
      "2011-12-30T10:00:00.000Z",
      "2011-12-31T00:00",
    ],
  ]) {
    const result = resolveLocalMinute(wall, zone);
    assert.equal(new Date(result.utcMillis).toISOString(), iso);
    assert.equal(result.effectiveLocal, effective);
    assert.equal(result.adjusted, wall !== effective);
  }
  assert.throws(() => resolveLocalMinute("2026-02-29T12:00", "Etc/UTC"));
  assert.throws(() => resolveLocalMinute("2026-10-30T12:00", "Invalid/Zone"));
});

test("Daily quota blocks new chores while accepted retries remain safe", async () => {
  const data = input();
  const accepted = await writeOneOffChore(db, guardian, data);
  await db.doc(`rateLimits/${guardian.uid}`).update({ choreWrites: 500 });
  assert.deepEqual(await writeOneOffChore(db, guardian, data), accepted);
  await assert.rejects(writeOneOffChore(db, guardian, input()), {
    code: "resource-exhausted",
  });
  assert.equal(
    (await db.collection(`households/${hid}/occurrences`).get()).size,
    1,
  );
});
