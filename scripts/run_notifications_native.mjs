import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { initializeApp, deleteApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
assert.equal(process.env.GCLOUD_PROJECT, "demo-chorely");
assert.equal(process.env.FIRESTORE_EMULATOR_HOST, "127.0.0.1:8080");
const simulator = process.argv[2];
assert.match(simulator ?? "", /^[A-Fa-f0-9-]{36}$/);
const app = initializeApp({ projectId: "demo-chorely" }),
  db = getFirestore(app);
const worker = spawn(
  process.execPath,
  ["scripts/local_household_workers.mjs"],
  { stdio: "inherit" },
);
async function run(name, defines = []) {
  const test = spawn(
    "flutter",
    [
      "test",
      `integration_test/${name}.dart`,
      "-d",
      simulator,
      "--no-uninstall",
      ...defines,
    ],
    { stdio: "inherit" },
  );
  const code = await new Promise((resolve) => test.on("exit", resolve));
  assert.equal(code, 0, `${name} must pass`);
}
try {
  await run("notifications_test");
  const home = (await db.collection("households").get()).docs[0].ref;
  const rows = await home.collection("occurrences").get();
  const reviewed = rows.docs.find((d) => d.get("title") === "Cook rice");
  assert.ok(reviewed, "actual stored chore snapshot");
  assert.equal(reviewed.get("status"), "approved");
  assert.equal(reviewed.get("version"), 3);
  const messages = await home.collection("notificationInbox").get();
  const read = messages.docs.filter((d) => d.get("readAt") != null);
  assert.equal(read.length, 2);
  const own = messages.docs.find(
    (d) =>
      d.get("actorId") === "native-fictional-guardian" &&
      d.get("event") === "assigned",
  );
  assert.ok(own);
  const payload = JSON.stringify({
    v: 1,
    householdId: home.id,
    notificationId: own.id,
    actorId: "native-fictional-guardian",
  });
  await run("notification_cold_start_test", [
    `--dart-define=CHORELY_TEST_NOTIFICATION=${payload}`,
  ]);
  const stamp = (await own.ref.get()).get("readAt");
  assert.ok(stamp);
  await home.collection("occurrences").doc(own.get("occurrenceId")).delete();
  await run("notification_cold_start_test", [
    `--dart-define=CHORELY_TEST_NOTIFICATION=${payload}`,
    "--dart-define=CHORELY_TEST_UNAVAILABLE=true",
  ]);
  assert.equal(
    (await own.ref.get()).get("readAt").toMillis(),
    stamp.toMillis(),
  );
  console.log(
    "PASS: Native private inbox, child completion, separate guardian review, cold authenticated route, deleted target fallback and monotonic read persisted. Cold route injected opaque IDs; no APNs/FCM provider delivery tested.",
  );
} finally {
  worker.kill("SIGTERM");
  await new Promise((resolve) => worker.on("exit", resolve));
  await deleteApp(app);
}
