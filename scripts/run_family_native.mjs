import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { initializeApp, deleteApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
assert.equal(process.env.GCLOUD_PROJECT, "demo-chorely");
assert.equal(process.env.FIRESTORE_EMULATOR_HOST, "127.0.0.1:8080");
const simulator = process.argv[2];
assert.match(simulator ?? "", /^[A-Fa-f0-9-]{36}$/);
const child = spawn(
  "flutter",
  ["test", "integration_test/family_test.dart", "-d", simulator],
  { stdio: "inherit" },
);
const code = await new Promise((resolve) => child.on("exit", resolve));
const app = initializeApp({ projectId: "demo-chorely" });
const db = getFirestore(app);
const homes = await db.collection("households").get();
assert.equal(homes.size, 1);
const devices = await homes.docs[0].ref.collection("devices").get();
console.log(
  "Native server device statuses:",
  devices.docs.map((d) => d.get("status")),
);
const events = await homes.docs[0].ref.collection("activity").get();
console.log(
  "Native server event actions:",
  events.docs.map((d) => d.get("action")),
);
if (code === 0) {
  assert.equal(devices.size, 1);
  assert.equal(devices.docs[0].get("status"), "revoked");
  console.log("PASS: native UI removal persisted on the local server.");
}
await deleteApp(app);
process.exitCode = Number(code ?? 1);
