// Loopback-only adapters. This runner never registers or sends remote messages.
import assert from "node:assert/strict";
import { setTimeout } from "node:timers/promises";
import { initializeApp, deleteApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { runRecurrenceWorker } from "../functions/lib/recurrence_worker.js";
import { runNotificationWorker } from "../functions/lib/notification_worker.js";
assert.equal(process.env.GCLOUD_PROJECT, "demo-chorely");
assert.equal(process.env.FIRESTORE_EMULATOR_HOST, "127.0.0.1:8080");
const app = initializeApp({ projectId: "demo-chorely" }),
  stop = new AbortController();
for (const signal of ["SIGINT", "SIGTERM"])
  process.once(signal, () => stop.abort());
let recurrenceAt = 0;
try {
  do {
    if (Date.now() >= recurrenceAt) {
      const result = await runRecurrenceWorker(getFirestore(app));
      if (result.generated || result.failed || result.processed)
        console.log("Local recurrence worker:", result);
      recurrenceAt = Date.now() + 60_000;
    }
    const result = await runNotificationWorker(getFirestore(app));
    if (
      result.sources ||
      result.due ||
      result.refreshed ||
      result.failed ||
      process.argv.includes("--once")
    )
      console.log("Local notification worker:", result);
    if (process.argv.includes("--once")) break;
    await setTimeout(2_000, undefined, { signal: stop.signal });
  } while (!stop.signal.aborted);
} catch (error) {
  if (error.name !== "AbortError") throw error;
} finally {
  await deleteApp(app);
}
