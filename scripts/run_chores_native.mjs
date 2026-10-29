import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { initializeApp, deleteApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
assert.equal(process.env.GCLOUD_PROJECT, "demo-chorely");
assert.equal(process.env.FIRESTORE_EMULATOR_HOST, "127.0.0.1:8080");
assert.equal(process.env.FIREBASE_AUTH_EMULATOR_HOST, "127.0.0.1:9099");
const simulator = process.argv[2];
assert.match(simulator ?? "", /^[A-Fa-f0-9-]{36}$/);
const app = initializeApp({ projectId: "demo-chorely" });
const db = getFirestore(app);
for (const name of ["chores_test", "chores_restart_test"]) {
  const child = spawn(
    "flutter",
    ["test", `integration_test/${name}.dart`, "-d", simulator],
    { stdio: "inherit" },
  );
  const code = await new Promise((resolve) => child.on("exit", resolve));
  if (code !== 0) {
    process.exitCode = Number(code ?? 1);
    break;
  }
  const homes = await db.collection("households").get();
  assert.equal(homes.size, 1);
  const occurrences = await homes.docs[0].ref.collection("occurrences").get();
  const templates = await homes.docs[0].ref.collection("choreTemplates").get();
  assert.equal(occurrences.size, 1);
  assert.equal(templates.size, 1);
  const saved = occurrences.docs[0];
  assert.equal(saved.get("title"), "Cook rice");
  assert.deepEqual(saved.get("steps"), [
    "Updated household instructions from Alex.",
  ]);
  assert.equal(saved.get("reviewMode"), "guardian");
  assert.equal(saved.get("instructionIllustrationKey"), "assign");
  assert.equal(saved.get("version"), name === "chores_test" ? 2 : 3);
  assert.equal(
    saved.get("status"),
    name === "chores_test" ? "scheduled" : "cancelled",
  );
  assert.equal(templates.docs[0].get("active"), name === "chores_test");
  const events = await homes.docs[0].ref
    .collection("activity")
    .where("entityId", "==", saved.id)
    .get();
  assert.equal(events.size, name === "chores_test" ? 2 : 3);
  console.log(
    `PASS: ${name} stored ${saved.get("status")} revision ${saved.get("version")}, one template, one occurrence and preserved audit events.`,
  );
}
await deleteApp(app);
