import assert from "node:assert/strict";
import { initializeApp, deleteApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
assert.equal(process.env.GCLOUD_PROJECT, "demo-chorely");
assert.equal(process.env.FIRESTORE_EMULATOR_HOST, "127.0.0.1:8080");
const app = initializeApp({ projectId: "demo-chorely" });
const db = getFirestore(app);
const homes = await db.collection("households").get();
assert.equal(homes.size, 1);
assert.equal(homes.docs[0].get("name"), "Native fictional home");
assert.equal(
  (await db.collection("users/native-fictional-guardian/households").get())
    .size,
  1,
);
console.log(
  "PASS: native fixture home and guardian index persist on local server.",
);
await deleteApp(app);
