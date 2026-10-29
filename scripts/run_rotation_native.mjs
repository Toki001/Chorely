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
const worker = spawn(
  process.execPath,
  ["scripts/local_recurrence_worker.mjs"],
  { stdio: "inherit" },
);
try {
  for (const name of ["rotation_test", "rotation_restart_test"]) {
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
    const roots = await homes.docs[0].ref.collection("recurrenceRules").get();
    assert.equal(roots.size, 1);
    const root = roots.docs[0];
    const version = name === "rotation_test" ? 1 : 2;
    assert.equal(root.get("version"), version);
    const definition = await root.ref
      .collection("versions")
      .doc(String(version))
      .get();
    const rows = await homes.docs[0].ref.collection("occurrences").get();
    assert.equal(rows.size, 31);
    const recurring = rows.docs
      .filter((d) => d.get("recurrenceVersion") > 0)
      .sort((a, b) => a.get("localDate").localeCompare(b.get("localDate")));
    assert.equal(recurring.length, 30);
    const order = definition.get("rule.rotation.order");
    assert.equal(order.length, 3);
    if (version === 1) {
      for (let i = 0; i < 14; i++)
        assert.deepEqual(recurring[i].get("assignedActorIds"), [order[i % 3]]);
      assert.equal(
        recurring.filter((d) => d.get("status") === "scheduled").length,
        30,
      );
    } else {
      assert.equal(definition.get("paused"), true);
      assert.equal(
        recurring.filter((d) => d.get("status") === "scheduled").length,
        2,
      );
      assert.equal(
        recurring.filter((d) => d.get("status") === "cancelled").length,
        28,
      );
    }
    console.log(
      `PASS: ${name} persisted version ${version}, three-person order, 30 distinct recurring dates and preserved one-off history.`,
    );
  }
} finally {
  worker.kill("SIGTERM");
  await new Promise((resolve) => worker.once("exit", resolve));
  await deleteApp(app);
}
