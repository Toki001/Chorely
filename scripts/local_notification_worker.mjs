// Local in-app notification worker only. It never sends FCM/APNs messages.
import assert from "node:assert/strict";
import { setTimeout } from "node:timers/promises";
import { initializeApp, deleteApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { runNotificationWorker } from "../functions/lib/notification_worker.js";
assert.equal(process.env.GCLOUD_PROJECT, "demo-chorely");
assert.equal(process.env.FIRESTORE_EMULATOR_HOST, "127.0.0.1:8080");
const app = initializeApp({ projectId: "demo-chorely" });
const stop = new AbortController();
for (const signal of ["SIGINT", "SIGTERM"])
  process.once(signal, () => stop.abort());
try {
  do {
    console.log(
      "Local notification inbox worker:",
      await runNotificationWorker(getFirestore(app)),
    );
    if (process.argv.includes("--once")) break;
    await setTimeout(2_000, undefined, { signal: stop.signal });
  } while (!stop.signal.aborted);
} catch (error) {
  if (error.name !== "AbortError") throw error;
} finally {
  await deleteApp(app);
}
