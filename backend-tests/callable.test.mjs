import { before, after, test } from "node:test";
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import {
  initializeApp as adminApp,
  deleteApp as deleteAdmin,
} from "firebase-admin/app";
import { getAuth as adminAuth } from "firebase-admin/auth";
import { initializeApp, deleteApp } from "firebase/app";
import {
  getAuth,
  connectAuthEmulator,
  createUserWithEmailAndPassword,
  signInWithEmailAndPassword,
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
