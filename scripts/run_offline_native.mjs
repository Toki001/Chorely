import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { randomUUID } from "node:crypto";
import { initializeApp, deleteApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { revokeMember } from "../functions/lib/membership.js";
import { writeOneOffChore } from "../functions/lib/chores.js";
assert.equal(process.env.GCLOUD_PROJECT, "demo-chorely");
assert.equal(process.env.FIRESTORE_EMULATOR_HOST, "127.0.0.1:8080");
const simulator = process.argv[2];
assert.match(simulator ?? "", /^[A-Fa-f0-9-]{36}$/);
const app = initializeApp({ projectId: "demo-chorely" }),
  db = getFirestore(app);
async function run(name, defines = []) {
  const child = spawn(
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
  assert.equal(
    await new Promise((resolve) => child.on("exit", resolve)),
    0,
    `${name} must pass`,
  );
}
try {
  const home = (await db.collection("households").get()).docs[0].ref;
  const getRow = async (title) =>
    (await home.collection("occurrences").where("title", "==", title).get())
      .docs[0];
  if (!process.argv.includes("--resume-cache")) {
    await run("offline_queue_test");
    assert.equal((await getRow("Feed pets")).get("version"), 1);
    assert.equal((await getRow("Feed pets")).get("status"), "scheduled");
    for (let i = 0; i < 2; i++) {
      await run("offline_recovery_test");
      const row = await getRow("Feed pets");
      assert.equal(row.get("version"), 2);
      assert.equal(row.get("status"), "completed");
      assert.deepEqual(Object.keys(row.get("contributions")), [
        "native-fictional-guardian",
      ]);
      assert.equal(
        (
          await home
            .collection("activity")
            .where("entityId", "==", row.id)
            .get()
        ).size,
        2,
      );
    }
    await run("offline_queue_test", [
      "--dart-define=CHORELY_OFFLINE_TITLE=Sweep floor",
    ]);
    const row = await getRow("Sweep floor");
    await writeOneOffChore(
      db,
      {
        uid: "native-fictional-guardian",
        emailVerified: true,
        provider: "password",
        scopedChild: false,
      },
      {
        householdId: home.id,
        commandId: randomUUID(),
        action: "edit",
        templateId: row.get("templateId"),
        occurrenceId: row.id,
        baseTemplateVersion: 1,
        baseOccurrenceVersion: 1,
        title: "Sweep floor",
        category: "household",
        description: "Updated on another fictional device",
        steps: [],
        room: "",
        assignedActorIds: ["native-fictional-guardian"],
        completionPolicy: "any_one_completes",
        reviewMode: "none",
        schedule: row.get("requestedSchedule"),
      },
    );
    await run("offline_recovery_test", [
      "--dart-define=CHORELY_OFFLINE_CONFLICT=true",
    ]);
    const unchanged = await row.ref.get();
    assert.equal(unchanged.get("version"), 2);
    assert.equal(unchanged.get("status"), "scheduled");
    assert.deepEqual(unchanged.get("contributions") ?? {}, {});
  }
  const row = await getRow("Sweep floor");
  await run("offline_cached_read_test", [
    "--dart-define=CHORELY_TEST_OFFLINE_DATA=true",
  ]);
  assert.equal((await row.ref.get()).get("version"), 2);
  await run("offline_recovery_test", [
    "--dart-define=CHORELY_OFFLINE_TITLE=Sweep floor",
  ]);
  const recovered = await row.ref.get();
  assert.equal(recovered.get("version"), 3);
  assert.equal(recovered.get("status"), "completed");
  assert.deepEqual(Object.keys(recovered.get("contributions")), [
    "native-fictional-guardian",
  ]);
  // A second fictional guardian permits a real, validated revoke command.
  await home
    .collection("members")
    .doc("fixture-second-guardian")
    .set({ role: "guardian", status: "active" });
  await home
    .collection("profiles")
    .doc("fixture-second-guardian")
    .set({ role: "guardian", nickname: "Fictional second guardian" });
  await revokeMember(
    db,
    {
      uid: "fixture-second-guardian",
      emailVerified: true,
      provider: "password",
      scopedChild: false,
    },
    {
      householdId: home.id,
      memberUid: "native-fictional-guardian",
      commandId: randomUUID(),
    },
  );
  await run("offline_revocation_test", [
    `--dart-define=CHORELY_REVOKED_HOME=${home.id}`,
  ]);
  console.log(
    "PASS: Native durable commands, repeated restart without duplicate contributions, explicit conflict review, fully disconnected Firestore/Functions cached reads, one accepted recovery, and actual membership-removal cache/command purge passed.",
  );
} finally {
  await deleteApp(app);
}
