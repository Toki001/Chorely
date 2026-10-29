import { randomUUID } from "node:crypto";
import {
  FieldPath,
  Timestamp,
  type Firestore,
  type DocumentSnapshot,
} from "firebase-admin/firestore";
import { reconcileOccurrenceNotifications } from "./notification_jobs.js";
import { identifier, hash } from "./validation.js";

export async function runNotificationWorker(
  db: Firestore,
  nowMillis = Date.now(),
) {
  const lease = db.doc("schedulerLeases/notifications"),
    owner = randomUUID();
  const acquired = await db.runTransaction(async (tx) => {
    const held = await tx.get(lease);
    if (Number(held.get("untilMillis") ?? 0) > nowMillis) return false;
    tx.set(lease, { owner, untilMillis: nowMillis + 300_000 });
    return true;
  });
  const stats = {
    leased: !acquired,
    sources: 0,
    due: 0,
    refreshed: 0,
    failed: 0,
  };
  if (!acquired) return stats;
  const seen = new Set<string>();
  const reconcile = async (hid: string, oid: string, force = false) => {
    const key = `${identifier(hid)}/${identifier(oid)}`;
    if (force || !seen.has(key)) {
      await reconcileOccurrenceNotifications(db, hid, oid, nowMillis);
      seen.add(key);
    }
  };
  const code = (error: unknown) =>
    error instanceof Error && /^notification_[a-z_]+$/.test(error.message)
      ? error.message
      : "notification_reconcile_failed";
  const fail = async (doc: DocumentSnapshot, error: unknown) => {
    const attempts = Number(doc.get("attempts") ?? 0) + 1;
    await doc.ref.update({
      state: attempts >= 5 ? "needs_attention" : "pending",
      attempts,
      nextAttemptAtMillis:
        nowMillis + Math.min(3_600_000, 60_000 * 2 ** (attempts - 1)),
      errorCode: code(error),
      failedAt: Timestamp.fromMillis(nowMillis),
    });
    stats.failed++;
  };
  try {
    // Each acknowledged source revision is durable and independently replayable.
    const sources = await db
      .collection("notificationOutbox")
      .where("state", "==", "pending")
      .where("nextAttemptAtMillis", "<=", nowMillis)
      .orderBy("nextAttemptAtMillis")
      .limit(25)
      .get();
    for (const source of sources.docs) {
      try {
        await reconcile(source.get("householdId"), source.get("occurrenceId"));
        await source.ref.update({
          state: "done",
          processedAt: Timestamp.fromMillis(nowMillis),
          errorCode: null,
        });
        stats.sources++;
      } catch (error) {
        await fail(source, error);
      }
    }
    const due = await db
      .collectionGroup("notificationJobs")
      .where("state", "==", "queued")
      .where("nextWakeAtMillis", "<=", nowMillis)
      .orderBy("nextWakeAtMillis")
      .limit(25)
      .get();
    for (const job of due.docs) {
      try {
        const parts = job.ref.path.split("/");
        if (parts.length !== 4 || parts[0] !== "households")
          throw new Error("notification_invalid_path");
        await reconcile(parts[1]!, job.get("occurrenceId"));
        stats.due++;
      } catch (error) {
        await job.ref.update({
          nextWakeAtMillis: nowMillis + 3_600_000,
          errorCode: code(error),
        });
        stats.failed++;
      }
    }
    // A preference change atomically requests a bounded sweep of current jobs.
    const refreshes = await db
      .collection("notificationHouseholdRefresh")
      .where("state", "==", "pending")
      .where("nextAttemptAtMillis", "<=", nowMillis)
      .orderBy("nextAttemptAtMillis")
      .limit(1)
      .get();
    for (const request of refreshes.docs) {
      const hid = identifier(request.id),
        generation = request.get("generation");
      // Scan real occurrences, including those that had no jobs while opted
      // out. A queued-jobs-only sweep could never restore disabled reminders.
      let query = db
        .collection(`households/${hid}/occurrences`)
        .orderBy(FieldPath.documentId());
      if (typeof request.get("afterId") === "string")
        query = query.startAfter(request.get("afterId"));
      const jobs = await query.limit(25).get();
      const refreshed = new Set<string>();
      for (const job of jobs.docs) {
        const oid = job.id;
        if (refreshed.has(oid)) continue;
        try {
          // Re-read preferences even if this occurrence was handled earlier in
          // this tick: a save may have enqueued the sweep in the meantime.
          await reconcile(hid, oid, true);
          stats.refreshed++;
        } catch (error) {
          const retry = db.doc(
            `notificationOutbox/${hash(JSON.stringify([hid, oid, "refresh", generation]))}`,
          );
          await db.runTransaction(async (tx) => {
            const prior = await tx.get(retry);
            if (!prior.exists)
              tx.create(retry, {
                householdId: hid,
                occurrenceId: oid,
                sourceVersion: null,
                state: "pending",
                attempts: 0,
                nextAttemptAtMillis: nowMillis + 60_000,
                createdAt: Timestamp.fromMillis(nowMillis),
                errorCode: code(error),
              });
          });
          stats.failed++;
        }
        refreshed.add(oid);
      }
      await db.runTransaction(async (tx) => {
        const current = await tx.get(request.ref);
        if (current.get("generation") !== generation) return;
        tx.update(request.ref, {
          state: jobs.size < 25 ? "done" : "pending",
          afterId: jobs.docs.at(-1)?.id ?? null,
          processedAt: Timestamp.fromMillis(nowMillis),
        });
      });
    }
    return stats;
  } finally {
    await db.runTransaction(async (tx) => {
      const current = await tx.get(lease);
      if (current.get("owner") === owner) tx.update(lease, { untilMillis: 0 });
    });
  }
}
