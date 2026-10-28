import { before, after, test } from "node:test";
import assert from "node:assert/strict";
import { randomUUID, randomBytes } from "node:crypto";
import {
  initializeApp as adminApp,
  deleteApp as deleteAdmin,
} from "firebase-admin/app";
import { getFirestore as adminFirestore } from "firebase-admin/firestore";
import { getAuth as adminAuth } from "firebase-admin/auth";
import { initializeApp, deleteApp } from "firebase/app";
import {
  getAuth,
  connectAuthEmulator,
  createUserWithEmailAndPassword,
  signInWithEmailAndPassword,
  signInWithCustomToken,
  linkWithCredential,
  EmailAuthProvider,
  signOut,
} from "firebase/auth";
import {
  getFirestore,
  connectFirestoreEmulator,
  doc,
  getDoc,
  getDocs,
  collection,
  setDoc,
  terminate,
  getDocFromServer,
} from "firebase/firestore";
import {
  getFunctions,
  connectFunctionsEmulator,
  httpsCallable,
} from "firebase/functions";

let admin;
const clients = [];
const password = "fictional-only-password-42";
const options = {
  projectId: "demo-chorely",
  apiKey: "A00000000000000000000000000000000000000",
  appId: "demo-client",
};
before(() => {
  assert.equal(process.env.GCLOUD_PROJECT, "demo-chorely");
  assert.ok(process.env.FIREBASE_AUTH_EMULATOR_HOST);
  assert.ok(process.env.FIRESTORE_EMULATOR_HOST);
  admin = adminApp({ projectId: "demo-chorely" }, "callable-admin");
});
after(async () => {
  for (const c of clients) {
    await terminate(c.db);
    await deleteApp(c.app);
  }
  await deleteAdmin(admin);
});
function client() {
  const app = initializeApp(options, randomUUID());
  const auth = getAuth(app);
  connectAuthEmulator(auth, "http://127.0.0.1:9099", { disableWarnings: true });
  const db = getFirestore(app);
  connectFirestoreEmulator(db, "127.0.0.1", 8080);
  const functions = getFunctions(app);
  connectFunctionsEmulator(functions, "127.0.0.1", 5001);
  const c = {
    app,
    auth,
    db,
    call: (name, data) => httpsCallable(functions, name)(data),
    create: httpsCallable(functions, "createHousehold"),
  };
  clients.push(c);
  return c;
}
async function account(verified = true, scopedChild = false) {
  const c = client();
  const email = `fictional-${randomUUID()}@example.test`;
  const { user } = await createUserWithEmailAndPassword(
    c.auth,
    email,
    password,
  );
  await adminAuth(admin).updateUser(user.uid, { emailVerified: verified });
  if (scopedChild)
    await adminAuth(admin).setCustomUserClaims(user.uid, { scopedChild: true });
  await user.getIdToken(true);
  return { ...c, email };
}
const request = () => ({
  commandId: randomUUID(),
  name: "Fictional shared home",
  nickname: "Alex",
  timezone: "Asia/Manila",
});

test("Callable ignores forged auth claims and denies unauthenticated/unverified/child callers", async () => {
  const anonymous = client();
  const unverified = await account(false);
  const child = await account(true, true);
  await assert.rejects(
    anonymous.create({ ...request(), uid: "owner", emailVerified: true }),
    { code: "functions/unauthenticated" },
  );
  for (const c of [unverified, child]) {
    await assert.rejects(
      c.create({
        ...request(),
        role: "guardian",
        emailVerified: true,
        scopedChild: false,
      }),
      { code: "functions/permission-denied" },
    );
  }
});

test("Real callable creates once and fresh signed-in client reads persisted household", async () => {
  const first = await account();
  const data = request();
  const [a, b] = await Promise.all([first.create(data), first.create(data)]);
  assert.equal(a.data.householdId, b.data.householdId);
  const id = a.data.householdId;
  const second = client();
  await signInWithEmailAndPassword(second.auth, first.email, password);
  assert.equal(
    (await getDoc(doc(second.db, `households/${id}`))).get("name"),
    data.name,
  );
  const index = await getDocs(
    collection(second.db, `users/${second.auth.currentUser.uid}/households`),
  );
  assert.equal(index.size, 1);
  assert.equal(index.docs[0].id, id);
  assert.equal(
    (await getDocs(collection(second.db, `households/${id}/profiles`))).size,
    1,
  );
  await assert.rejects(second.create({ ...data, name: "Changed replay" }), {
    code: "functions/already-exists",
  });
});

test("Two real adult tenants cannot read or write each other's household", async () => {
  const a = await account();
  const b = await account();
  const idA = (await a.create(request())).data.householdId;
  const idB = (await b.create(request())).data.householdId;
  for (const [c, other] of [
    [a, idB],
    [b, idA],
  ]) {
    await assert.rejects(getDoc(doc(c.db, `households/${other}`)), {
      code: "permission-denied",
    });
    await assert.rejects(
      getDocs(collection(c.db, `households/${other}/profiles`)),
      { code: "permission-denied" },
    );
    await assert.rejects(
      setDoc(doc(c.db, `households/${other}`), { name: "Forged" }),
      { code: "permission-denied" },
    );
  }
  await assert.rejects(
    setDoc(doc(a.db, `households/${idA}`), { name: "Direct mutation" }),
    { code: "permission-denied" },
  );
});

test("Real recipient-bound invite cannot promote adult; revoked token loses tenant access", async () => {
  const guardian = await account();
  const adult = await account();
  const other = await account();
  const hid = (await guardian.create(request())).data.householdId;
  const nonce = randomBytes(32).toString("base64url");
  await guardian.call("issueInvite", {
    householdId: hid,
    nonce,
    recipientEmail: adult.email,
    role: "adult",
    commandId: randomUUID(),
  });
  const accept = {
    nonce,
    nickname: "Sam",
    commandId: randomUUID(),
    role: "guardian",
  };
  await assert.rejects(other.call("acceptInvite", accept), {
    code: "functions/permission-denied",
  });
  await adult.call("acceptInvite", accept);
  assert.equal(
    (
      await getDoc(
        doc(
          adult.db,
          `households/${hid}/members/${adult.auth.currentUser.uid}`,
        ),
      )
    ).get("role"),
    "adult",
  );
  await assert.rejects(
    adult.call("issueInvite", {
      householdId: hid,
      nonce: randomBytes(32).toString("base64url"),
      recipientEmail: other.email,
      role: "guardian",
      commandId: randomUUID(),
    }),
    { code: "functions/permission-denied" },
  );
  await assert.rejects(
    adult.call("acceptInvite", { ...accept, commandId: randomUUID() }),
    { code: "functions/failed-precondition" },
  );
  const token = await adult.auth.currentUser.getIdToken();
  await guardian.call("revokeMember", {
    householdId: hid,
    memberUid: adult.auth.currentUser.uid,
  });
  assert.equal(await adult.auth.currentUser.getIdToken(), token);
  await assert.rejects(getDocFromServer(doc(adult.db, `households/${hid}`)), {
    code: "permission-denied",
  });
  assert.equal(
    (
      await getDocs(
        collection(adult.db, `users/${adult.auth.currentUser.uid}/households`),
      )
    ).size,
    0,
  );
});

test("Real supervised custom identity sees assigned profile work and stale token is denied after device revoke", async () => {
  const guardian = await account();
  const hid = (await guardian.create(request())).data.householdId;
  const profileId = (
    await guardian.call("addChildProfile", {
      householdId: hid,
      nickname: "Fictional child",
      commandId: randomUUID(),
    })
  ).data.profileId;
  const nonce = randomBytes(32).toString("base64url");
  await guardian.call("issueChildPairing", {
    householdId: hid,
    profileId,
    nonce,
  });
  const child = client();
  const token = (
    await child.call("redeemChildPairing", {
      nonce,
      deviceSecret: randomBytes(32).toString("base64url"),
    })
  ).data.customToken;
  await signInWithCustomToken(child.auth, token);
  const uid = child.auth.currentUser.uid;
  assert.notEqual(uid, profileId);
  assert.equal(child.auth.currentUser.email, null);
  const claims = (await child.auth.currentUser.getIdTokenResult()).claims;
  assert.equal(claims.scopedChild, true);
  assert.equal(claims.actorId, profileId);
  await adminFirestore(admin)
    .doc(`households/${hid}/occurrences/assigned`)
    .set({ assignedActorIds: [profileId], status: "scheduled" });
  await adminFirestore(admin)
    .doc(`households/${hid}/occurrences/private`)
    .set({
      assignedActorIds: [guardian.auth.currentUser.uid],
      status: "scheduled",
    });
  assert.equal(
    (
      await getDocFromServer(
        doc(child.db, `households/${hid}/occurrences/assigned`),
      )
    ).get("status"),
    "scheduled",
  );
  await assert.rejects(
    getDocFromServer(doc(child.db, `households/${hid}/occurrences/private`)),
    { code: "permission-denied" },
  );
  await assert.rejects(
    getDocs(collection(child.db, `households/${hid}/invitations`)),
    { code: "permission-denied" },
  );
  await assert.rejects(
    child.create({ ...request(), emailVerified: true, role: "guardian" }),
    { code: "functions/permission-denied" },
  );
  const staleToken = await child.auth.currentUser.getIdToken();
  await guardian.call("revokeChildAccess", {
    householdId: hid,
    targetId: uid,
    kind: "device",
  });
  assert.equal(await child.auth.currentUser.getIdToken(), staleToken);
  await assert.rejects(
    getDocFromServer(doc(child.db, `households/${hid}/occurrences/assigned`)),
    { code: "permission-denied" },
  );
});

test("Linking email/password to supervised identity never permits adult conversion", async () => {
  const guardian = await account();
  const hid = (await guardian.create(request())).data.householdId;
  const profileId = (
    await guardian.call("addChildProfile", {
      householdId: hid,
      nickname: "Fictional child",
      commandId: randomUUID(),
    })
  ).data.profileId;
  const nonce = randomBytes(32).toString("base64url");
  await guardian.call("issueChildPairing", {
    householdId: hid,
    profileId,
    nonce,
  });
  const child = client();
  const token = (
    await child.call("redeemChildPairing", {
      nonce,
      deviceSecret: randomBytes(32).toString("base64url"),
    })
  ).data.customToken;
  await signInWithCustomToken(child.auth, token);
  const uid = child.auth.currentUser.uid;
  const email = `fictional-linked-${randomUUID()}@example.test`;
  await linkWithCredential(
    child.auth.currentUser,
    EmailAuthProvider.credential(email, password),
  );
  await adminAuth(admin).updateUser(uid, { emailVerified: true });
  await signOut(child.auth);
  await signInWithEmailAndPassword(child.auth, email, password);
  assert.equal(
    (await child.auth.currentUser.getIdTokenResult()).claims.scopedChild,
    true,
  );
  await assert.rejects(child.create(request()), {
    code: "functions/permission-denied",
  });
  // Even a missing/stale scope claim cannot override the server-owned account type.
  await adminAuth(admin).setCustomUserClaims(uid, {});
  await child.auth.currentUser.getIdToken(true);
  assert.notEqual(
    (await child.auth.currentUser.getIdTokenResult()).claims.scopedChild,
    true,
  );
  await assert.rejects(child.create(request()), {
    code: "functions/permission-denied",
  });
  const inviteNonce = randomBytes(32).toString("base64url");
  await guardian.call("issueInvite", {
    householdId: hid,
    recipientEmail: email,
    role: "guardian",
    nonce: inviteNonce,
    commandId: randomUUID(),
  });
  await assert.rejects(
    child.call("acceptInvite", {
      nonce: inviteNonce,
      nickname: "Fictional",
      commandId: randomUUID(),
    }),
    { code: "functions/permission-denied" },
  );
});
