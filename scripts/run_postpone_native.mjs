import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { initializeApp, deleteApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import {
  householdDate,
  addCivilDays,
} from "../functions/lib/recurrence_engine.js";
assert.equal(process.env.GCLOUD_PROJECT, "demo-chorely");
assert.equal(process.env.FIRESTORE_EMULATOR_HOST, "127.0.0.1:8080");
assert.equal(process.env.FIREBASE_AUTH_EMULATOR_HOST, "127.0.0.1:9099");
const simulator = process.argv[2];
assert.match(simulator ?? "", /^[A-Fa-f0-9-]{36}$/);
const app = initializeApp({ projectId: "demo-chorely" }),
  db = getFirestore(app);
try {
  const home = (await db.collection("households").get()).docs[0].ref;
  const row = (
    await home.collection("occurrences").where("title", "==", "Cook rice").get()
  ).docs[0];
  const definition = home
      .collection("choreTemplates")
      .doc(row.get("templateId")),
    before = (await definition.get()).data();
  const date = addCivilDays(householdDate(Date.now(), "Asia/Manila"), 1),
    slotKey = row.get("slotKey");
  for (const name of ["postpone_test", "postpone_restart_test"]) {
    const child = spawn(
      "flutter",
      [
        "test",
        `integration_test/${name}.dart`,
        "-d",
        simulator,
        "--no-uninstall",
        `--dart-define=CHORELY_POSTPONE_DATE=${date}`,
      ],
      { stdio: "inherit" },
    );
    assert.equal(
      await new Promise((resolve) => child.on("exit", resolve)),
      0,
      `${name} must pass`,
    );
    const current = await row.ref.get();
    assert.equal(current.get("version"), 2);
    assert.equal(current.get("status"), "scheduled");
    assert.equal(current.get("requestedSchedule.date"), date);
    assert.equal(current.get("requestedSchedule.at"), "19:30");
    assert.equal(current.get("slotKey"), slotKey);
    assert.equal(current.get("templateVersion"), 1);
    assert.deepEqual((await definition.get()).data(), before);
    assert.equal(
      (
        await home
          .collection("activity")
          .where("action", "==", "occurrence_postponed")
          .get()
      ).size,
      1,
    );
    assert.deepEqual(current.get("contributions") ?? {}, {});
    console.log(
      `PASS: ${name} kept one accepted deadline override, unchanged template/slot, one audit event and zero completion contributions.`,
    );
  }
} finally {
  await deleteApp(app);
}
