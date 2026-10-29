import { randomUUID } from "node:crypto";
import { FieldPath, Timestamp, type Firestore } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";
import { hash } from "./validation.js";
import { materializeRule } from "./recurrence_service.js";

// Trusted worker only. No client-selected clock, cursor or cross-tenant scan.
export async function runRecurrenceWorker(
  db: Firestore,
  nowMillis = Date.now(),
  limits = { pageSize: 25, maxPages: 8 },
) {
  if (
    !Number.isInteger(limits.pageSize) ||
    limits.pageSize < 1 ||
    limits.pageSize > 25 ||
    !Number.isInteger(limits.maxPages) ||
    limits.maxPages < 1 ||
    limits.maxPages > 8
  )
    throw new RangeError("Invalid worker bounds");
  const state = db.doc("schedulerState/recurrence"),
    owner = randomUUID();
  const start = await db.runTransaction(async (tx) => {
    const existing = await tx.get(state);
    if (
      ((existing.get("leaseUntil") as Timestamp | undefined)?.toMillis() ?? 0) >
      nowMillis
    )
      return null;
    tx.set(
      state,
      { owner, leaseUntil: Timestamp.fromMillis(nowMillis + 300_000) },
      { merge: true },
    );
    return { cursor: (existing.get("cursor") as string | null) ?? null };
  });
  if (start === null)
    return { skipped: true, processed: 0, changed: 0, failed: 0 };
  let cursor = start.cursor,
    processed = 0,
    changed = 0,
    failed = 0;
  try {
    for (let page = 0; page < limits.maxPages; page++) {
      let query = db
        .collectionGroup("recurrenceRules")
        .where("managed", "==", true)
        .orderBy(FieldPath.documentId())
        .limit(limits.pageSize);
      if (cursor) query = query.startAfter(db.doc(cursor));
      const rows = await query.get();
      for (const row of rows.docs) {
        const parts = row.ref.path.split("/");
        if (parts.length !== 4 || parts[0] !== "households") continue;
        try {
          changed += (
            await materializeRule(db, parts[1]!, parts[3]!, nowMillis)
          ).changed;
        } catch (error) {
          failed++;
          await db.doc(`schedulerFailures/${hash(row.ref.path)}`).set({
            householdId: parts[1],
            templateId: parts[3],
            code: error instanceof HttpsError ? error.code : "internal",
            lastAttemptAt: Timestamp.fromMillis(nowMillis),
          });
        }
        processed++;
      }
      cursor = rows.size < limits.pageSize ? null : rows.docs.at(-1)!.ref.path;
      await db.runTransaction(async (tx) => {
        const current = await tx.get(state);
        if (current.get("owner") !== owner)
          throw new Error("Worker lease changed");
        tx.update(state, {
          cursor,
          lastRunAt: Timestamp.fromMillis(nowMillis),
          leaseUntil: Timestamp.fromMillis(nowMillis + 300_000),
        });
      });
      if (rows.size < limits.pageSize) break;
    }
    return { skipped: false, processed, changed, failed };
  } finally {
    await db.runTransaction(async (tx) => {
      const current = await tx.get(state);
      if (current.get("owner") === owner)
        tx.update(state, {
          owner: null,
          leaseUntil: Timestamp.fromMillis(nowMillis),
        });
    });
  }
}
