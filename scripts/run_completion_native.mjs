import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { initializeApp, deleteApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
assert.equal(process.env.GCLOUD_PROJECT, "demo-chorely");
assert.equal(process.env.FIRESTORE_EMULATOR_HOST, "127.0.0.1:8080");
assert.equal(process.env.FIREBASE_AUTH_EMULATOR_HOST, "127.0.0.1:9099");
const simulator = process.argv[2];
assert.match(simulator ?? "", /^[A-Fa-f0-9-]{36}$/);
const app = initializeApp({ projectId: "demo-chorely" }),
  db = getFirestore(app);
try {
  for (const name of ["completion_test", "completion_restart_test"]) {
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
    const home = homes.docs[0].ref;
    const rows = await home.collection("occurrences").get();
    assert.equal(rows.size, 1);
    const row = rows.docs[0];
    assert.equal(row.get("status"), "approved");
    assert.equal(row.get("version"), 7);
    assert.equal(row.get("approvedBy"), "native-fictional-guardian");
    const profiles = await home
      .collection("profiles")
      .where("role", "==", "child")
      .get();
    assert.equal(profiles.size, 1);
    assert.deepEqual(Object.keys(row.get("contributions")), [
      profiles.docs[0].id,
    ]);
    assert.equal(row.get("completionRevision"), 4);
    const definitions = await home.collection("choreTemplates").get();
    assert.equal(definitions.size, 1);
    assert.equal(definitions.docs[0].get("version"), 1);
    const requests = await home.collection("helpRequests").get();
    assert.equal(requests.size, 1);
    assert.equal(requests.docs[0].get("status"), "resolved");
    const events = await home
      .collection("activity")
      .where("entityId", "==", row.id)
      .get();
    assert.equal(events.size, 7);
    const actions = events.docs.map((d) => d.get("action"));
    assert.equal(actions.filter((a) => a === "occurrence_complete").length, 2);
    assert.equal(actions.filter((a) => a === "occurrence_undo").length, 1);
    assert.equal(actions.filter((a) => a === "occurrence_approve").length, 1);
    assert.equal((await db.collection("securityEvents").get()).size, 1);
    console.log(
      `PASS: ${name} stored approved revision 7, one current contribution, answered help, seven accepted events and one private denied self-review.`,
    );
  }
} finally {
  await deleteApp(app);
}
