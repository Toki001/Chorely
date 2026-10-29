import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { initializeApp, deleteApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
assert.equal(process.env.GCLOUD_PROJECT, "demo-chorely");
assert.equal(process.env.FIRESTORE_EMULATOR_HOST, "127.0.0.1:8080");
assert.equal(process.env.FIREBASE_AUTH_EMULATOR_HOST, "127.0.0.1:9099");
const [tablet, phone] = process.argv.slice(2);
for (const id of [tablet, phone]) assert.match(id ?? "", /^[A-Fa-f0-9-]{36}$/);
async function run(command, args) {
  const child = spawn(command, args, { stdio: "inherit" });
  const code = await new Promise((resolve) => child.on("exit", resolve));
  assert.equal(code, 0, `${command} native verification failed`);
}
await run(process.execPath, ["scripts/run_completion_native.mjs", tablet]);
await run("flutter", [
  "test",
  "integration_test/completion_restart_test.dart",
  "-d",
  phone,
  "--dart-define=CHORELY_EVIDENCE_TAG=phone-final",
]);
const app = initializeApp({ projectId: "demo-chorely" });
try {
  const db = getFirestore(app);
  const homes = await db.collection("households").get();
  assert.equal(homes.size, 1);
  const rows = await homes.docs[0].ref.collection("occurrences").get();
  assert.equal(rows.size, 1);
  assert.equal(rows.docs[0].get("status"), "approved");
  assert.equal(rows.docs[0].get("version"), 7);
  const events = await homes.docs[0].ref
    .collection("activity")
    .where("entityId", "==", rows.docs[0].id)
    .get();
  assert.equal(events.size, 7);
  console.log(
    "PASS: tablet parent/child journey and fresh phone calendar preserve approved revision 7 and all seven accepted events.",
  );
} finally {
  await deleteApp(app);
}
