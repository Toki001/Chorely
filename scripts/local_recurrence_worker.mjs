// Local scheduler adapter. Refuses live projects and non-loopback endpoints.
import assert from "node:assert/strict";
import { setTimeout } from "node:timers/promises";
import { initializeApp, deleteApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { runRecurrenceWorker } from "../functions/lib/recurrence_worker.js";
assert.equal(process.env.GCLOUD_PROJECT, "demo-chorely");
assert.equal(process.env.FIRESTORE_EMULATOR_HOST, "127.0.0.1:8080");
const app = initializeApp({ projectId: "demo-chorely" });
const stop = new AbortController();
for (const signal of ["SIGINT", "SIGTERM"])
  process.once(signal, () => stop.abort());
try {
  do {
    const result = await runRecurrenceWorker(getFirestore(app));
    console.log("Local recurrence worker:", result);
    if (process.argv.includes("--once")) break;
    await setTimeout(60_000, undefined, { signal: stop.signal });
  } while (!stop.signal.aborted);
} catch (error) {
  if (error.name !== "AbortError") throw error;
} finally {
  await deleteApp(app);
}
