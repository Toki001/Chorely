import { before, beforeEach, after, test } from "node:test";
import assert from "node:assert/strict";
import { randomUUID, randomBytes } from "node:crypto";
import { initializeApp, deleteApp } from "firebase-admin/app";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";
import { createHousehold } from "../functions/lib/households.js";
import {
  issueInvite,
  acceptInvite,
  revokeInvite,
  revokeMember,
} from "../functions/lib/membership.js";
import {
  addChildProfile,
  issueChildPairing,
  redeemChildPairing,
  revokeChildAccess,
} from "../functions/lib/child_access.js";
let app, db, hid;
const owner = {
  uid: "guardian",
  email: "guardian@example.test",
  emailVerified: true,
  provider: "password",
  scopedChild: false,
};
const recipient = {
  ...owner,
  uid: "recipient",
  email: "recipient@example.test",
};
const outsider = { ...owner, uid: "outsider", email: "outsider@example.test" };
const nonce = () => randomBytes(32).toString("base64url");
const accept = (code, extra = {}) => ({
  nonce: code,
  commandId: randomUUID(),
  nickname: "Sam",
  ...extra,
});
before(() => {
  assert.ok(process.env.FIRESTORE_EMULATOR_HOST);
  assert.ok(process.env.FIREBASE_AUTH_EMULATOR_HOST);
  app = initializeApp({ projectId: "demo-chorely" }, "membership-tests");
  db = getFirestore(app);
});
after(async () => deleteApp(app));
beforeEach(async () => {
  const response = await fetch(
    `http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/demo-chorely/databases/(default)/documents`,
    { method: "DELETE" },
  );
  assert.equal(response.ok, true);
  hid = (
    await createHousehold(db, owner, {
      commandId: randomUUID(),
      name: "Fictional home",
      nickname: "Alex",
      timezone: "Asia/Manila",
    })
  ).householdId;
});
async function invitation(role = "adult") {
  const code = nonce();
  const request = {
    householdId: hid,
    nonce: code,
    recipientEmail: "RECIPIENT@example.test",
    role,
    commandId: randomUUID(),
  };
  const result = await issueInvite(db, owner, request);
  return { code, request, ...result };
}
async function pairing() {
  const { profileId } = await addChildProfile(db, owner, {
    householdId: hid,
    nickname: "Fictional child",
    commandId: randomUUID(),
  });
  const code = nonce();
  const result = await issueChildPairing(db, owner, {
    householdId: hid,
    profileId,
    nonce: code,
  });
  return { code, profileId, ...result };
}
test("Adult invite is recipient-bound, hashes codes, grants only intended role and retries safely", async () => {
  const i = await invitation();
  assert.deepEqual(await issueInvite(db, owner, i.request), {
    inviteId: i.inviteId,
    expiresAt: i.expiresAt,
  });
  const stored = (await db.doc(`invites/${i.inviteId}`).get()).data();
  assert.equal(JSON.stringify(stored).includes(i.code), false);
  assert.equal(
    JSON.stringify(stored).includes("recipient@example.test"),
    false,
  );
  await assert.rejects(acceptInvite(db, outsider, accept(i.code)), {
    code: "permission-denied",
  });
  const request = accept(i.code, { role: "guardian", uid: "guardian" });
  const results = await Promise.all([
    acceptInvite(db, recipient, request),
    acceptInvite(db, recipient, request),
  ]);
  assert.equal(results[0].householdId, results[1].householdId);
  assert.equal(
    (await db.doc(`households/${hid}/members/recipient`).get()).get("role"),
    "adult",
  );
  assert.equal(
    (await db.doc(`households/${hid}/members/recipient`).get()).get(
      "canAssign",
    ),
    false,
  );
  await assert.rejects(acceptInvite(db, recipient, accept(i.code)), {
    code: "failed-precondition",
  });
});
test("Expired and revoked invites fail; non-guardian cannot issue or revoke", async () => {
  let i = await invitation();
  await db
    .doc(`invites/${i.inviteId}`)
    .update({ expiresAt: Timestamp.fromMillis(0) });
  await assert.rejects(acceptInvite(db, recipient, accept(i.code)), {
    code: "failed-precondition",
  });
  i = await invitation();
  await assert.rejects(
    revokeInvite(db, outsider, { householdId: hid, inviteId: i.inviteId }),
    { code: "permission-denied" },
  );
  await revokeInvite(db, owner, { householdId: hid, inviteId: i.inviteId });
  await assert.rejects(acceptInvite(db, recipient, accept(i.code)), {
    code: "failed-precondition",
  });
  await assert.rejects(issueInvite(db, outsider, i.request), {
    code: "permission-denied",
  });
});
test("Guardian removal preserves last guardian and atomically removes discovery index", async () => {
  await assert.rejects(
    revokeMember(db, owner, { householdId: hid, memberUid: owner.uid }),
    { code: "failed-precondition" },
  );
  const i = await invitation("guardian");
  await acceptInvite(db, recipient, accept(i.code));
  await revokeMember(db, recipient, { householdId: hid, memberUid: owner.uid });
  assert.equal(
    (await db.doc(`users/${owner.uid}/households/${hid}`).get()).exists,
    false,
  );
  assert.equal(
    (await db.doc(`households/${hid}/members/${owner.uid}`).get()).get(
      "status",
    ),
    "revoked",
  );
  await assert.rejects(
    issueInvite(db, owner, {
      ...i.request,
      nonce: nonce(),
      commandId: randomUUID(),
    }),
    { code: "permission-denied" },
  );
  await assert.rejects(
    revokeMember(db, recipient, { householdId: hid, memberUid: recipient.uid }),
    { code: "failed-precondition" },
  );
});
test("Adult member cannot add children, grant guardianship, pair devices or revoke membership", async () => {
  const i = await invitation();
  await acceptInvite(db, recipient, accept(i.code));
  for (const action of [
    () =>
      issueInvite(db, recipient, {
        ...i.request,
        nonce: nonce(),
        commandId: randomUUID(),
        role: "guardian",
      }),
    () =>
      addChildProfile(db, recipient, {
        householdId: hid,
        nickname: "Fictional child",
        commandId: randomUUID(),
      }),
    () =>
      issueChildPairing(db, recipient, {
        householdId: hid,
        profileId: "child",
        nonce: nonce(),
      }),
    () =>
      revokeMember(db, recipient, { householdId: hid, memberUid: owner.uid }),
  ])
    await assert.rejects(action(), { code: "permission-denied" });
});
test("Child profile stores no email or DOB and idempotent creation yields one profile", async () => {
  const request = {
    householdId: hid,
    nickname: "Fictional child",
    email: "ignored@example.test",
    dateOfBirth: "ignored",
    commandId: randomUUID(),
  };
  const a = await addChildProfile(db, owner, request);
  const b = await addChildProfile(db, owner, request);
  assert.equal(a.profileId, b.profileId);
  const profile = (
    await db.doc(`households/${hid}/profiles/${a.profileId}`).get()
  ).data();
  assert.deepEqual(Object.keys(profile).sort(), [
    "avatarKey",
    "nickname",
    "role",
    "status",
    "supervised",
  ]);
  await assert.rejects(
    addChildProfile(
      db,
      { ...owner, scopedChild: true },
      { ...request, commandId: randomUUID() },
    ),
    { code: "permission-denied" },
  );
});
test("Approved child pairing binds distinct device identity; replay from another device denied", async () => {
  const p = await pairing();
  const secret = nonce();
  const request = {
    nonce: p.code,
    deviceSecret: secret,
    role: "guardian",
    profileId: "forged",
  };
  const [a, b] = await Promise.all([
    redeemChildPairing(db, getAuth(app), null, request),
    redeemChildPairing(db, getAuth(app), null, request),
  ]);
  assert.ok(a.customToken);
  assert.ok(b.customToken);
  const devices = await db.collection(`households/${hid}/devices`).get();
  assert.equal(devices.size, 1);
  const member = await db
    .doc(`households/${hid}/members/${devices.docs[0].id}`)
    .get();
  assert.equal(member.get("role"), "child");
  assert.equal(member.get("actorId"), p.profileId);
  assert.equal(member.get("canAssign"), false);
  await assert.rejects(
    redeemChildPairing(db, getAuth(app), null, {
      ...request,
      deviceSecret: nonce(),
    }),
    { code: "permission-denied" },
  );
  await assert.rejects(
    redeemChildPairing(db, getAuth(app), owner.uid, request),
    { code: "failed-precondition" },
  );
  await revokeChildAccess(db, owner, {
    householdId: hid,
    targetId: devices.docs[0].id,
    kind: "device",
  });
  await assert.rejects(redeemChildPairing(db, getAuth(app), null, request), {
    code: "permission-denied",
  });
});
test("Expired/revoked pairing and revoked approving guardian cannot authorize new device", async () => {
  let p = await pairing();
  await db
    .doc(`pairings/${p.pairingId}`)
    .update({ expiresAt: Timestamp.fromMillis(0) });
  await assert.rejects(
    redeemChildPairing(db, getAuth(app), null, {
      nonce: p.code,
      deviceSecret: nonce(),
    }),
    { code: "permission-denied" },
  );
  p = await pairing();
  await revokeChildAccess(db, owner, {
    householdId: hid,
    targetId: p.pairingId,
    kind: "pairing",
  });
  await assert.rejects(
    redeemChildPairing(db, getAuth(app), null, {
      nonce: p.code,
      deviceSecret: nonce(),
    }),
    { code: "permission-denied" },
  );
  p = await pairing();
  await db
    .doc(`households/${hid}/members/${owner.uid}`)
    .update({ status: "revoked" });
  await assert.rejects(
    redeemChildPairing(db, getAuth(app), null, {
      nonce: p.code,
      deviceSecret: nonce(),
    }),
    { code: "permission-denied" },
  );
});
test("Code entropy format and text/path validation reject malformed requests before writes", async () => {
  for (const bad of ["123456", "a".repeat(43), "../secret", "", "😀"]) {
    await assert.rejects(
      issueInvite(db, owner, {
        householdId: hid,
        nonce: bad,
        recipientEmail: recipient.email,
        role: "adult",
        commandId: randomUUID(),
      }),
      { code: "invalid-argument" },
    );
  }
  await assert.rejects(
    addChildProfile(db, owner, {
      householdId: "../other",
      nickname: "Fictional",
      commandId: randomUUID(),
    }),
    { code: "invalid-argument" },
  );
});

test("Disabled approving account invalidates outstanding invite and pairing; daily limits enforced", async () => {
  const i = await invitation();
  const p = await pairing();
  await db.doc(`users/${owner.uid}`).update({ status: "disabled" });
  await assert.rejects(acceptInvite(db, recipient, accept(i.code)), {
    code: "permission-denied",
  });
  await assert.rejects(
    redeemChildPairing(db, getAuth(app), null, {
      nonce: p.code,
      deviceSecret: nonce(),
    }),
    { code: "permission-denied" },
  );
  await db.doc(`users/${owner.uid}`).update({ status: "active" });
  const day = new Date().toISOString().slice(0, 10);
  await db
    .doc(`rateLimits/${owner.uid}`)
    .set({ inviteDay: day, inviteCount: 20, pairDay: day, pairCount: 20 });
  await assert.rejects(
    issueInvite(db, owner, {
      ...i.request,
      nonce: nonce(),
      commandId: randomUUID(),
    }),
    { code: "resource-exhausted" },
  );
  await assert.rejects(
    issueChildPairing(db, owner, {
      householdId: hid,
      profileId: p.profileId,
      nonce: nonce(),
    }),
    { code: "resource-exhausted" },
  );
});
