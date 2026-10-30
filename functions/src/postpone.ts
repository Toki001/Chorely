import { Timestamp, type Firestore } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";
import type { Actor } from "./contracts.js";
import { requireAdult } from "./households.js";
import { commandId, hash, identifier, record } from "./validation.js";
import {
  authorizeChoreManager,
  parseChoreContent,
  resolveChoreTiming,
  validateChoreAssignees,
} from "./chores.js";
import { householdDate, addCivilDays } from "./recurrence_engine.js";
import { assignmentNotificationState } from "./notification_assignment.js";
import { enqueueOccurrenceNotifications } from "./notification_outbox.js";

/** An explicit occurrence override. The reusable definition and slot identity
 * stay intact; trusted recurrence reconciliation must preserve this decision. */
export async function postponeOccurrence(
  db: Firestore,
  actor: Actor | null,
  input: unknown,
  nowMillis = Date.now(),
) {
  requireAdult(actor);
  const data = record(input),
    hid = identifier(data.householdId),
    oid = identifier(data.occurrenceId);
  const cid = commandId(data.commandId),
    schedule = record(data.schedule);
  const baseVersion = data.baseVersion;
  if (!Number.isSafeInteger(baseVersion) || Number(baseVersion) < 1)
    throw new HttpsError("invalid-argument", "Invalid occurrence version.");
  // Timed postponement is explicit. An untimed occurrence can receive a later
  // day's deadline; a window can move as a window or to an explicit deadline.
  if (!["time", "deadline", "range"].includes(String(schedule.kind)))
    throw new HttpsError("invalid-argument", "Choose a later time or window.");
  const fingerprint = hash(JSON.stringify({ hid, oid, baseVersion, schedule }));
  const receipt = db.doc(
    `commands/${hash(JSON.stringify([actor.uid, cid, "postpone"]))}`,
  );
  return db.runTransaction(async (tx) => {
    await authorizeChoreManager(db, tx, actor, hid);
    const membership = await tx.get(
      db.doc(`households/${hid}/members/${actor.uid}`),
    );
    if (membership.get("role") !== "guardian")
      throw new HttpsError(
        "permission-denied",
        "Only a guardian can postpone an occurrence.",
      );
    const prior = await tx.get(receipt);
    if (prior.exists) {
      if (prior.get("payloadHash") !== fingerprint)
        throw new HttpsError("already-exists", "Request ID already used.");
      return prior.get("result") as { occurrenceId: string; version: number };
    }
    const ref = db.doc(`households/${hid}/occurrences/${oid}`),
      snapshot = await tx.get(ref);
    if (!snapshot.exists)
      throw new HttpsError("not-found", "Occurrence unavailable.");
    if (snapshot.get("version") !== baseVersion)
      throw new HttpsError(
        "aborted",
        "This chore changed. Reload before postponing.",
      );
    if (
      !["scheduled", "needs_redo"].includes(snapshot.get("status")) ||
      Object.keys(snapshot.get("contributions") ?? {}).length > 0
    )
      throw new HttpsError(
        "failed-precondition",
        "Recorded work and terminal occurrences cannot be postponed.",
      );
    const value = parseChoreContent({ ...snapshot.data(), schedule });
    await validateChoreAssignees(db, tx, hid, value);
    const zone = snapshot.get("timezoneIana") as string;
    const next = resolveChoreTiming(value, zone);
    const due = next.dueAtUtc!,
      oldDue = snapshot.get("dueAtUtc") as Timestamp | null;
    const today = householdDate(nowMillis, zone),
      through = addCivilDays(today, 30);
    if (
      next.localDate < today ||
      next.localDate > through ||
      String(next.effectiveDueLocal).slice(0, 10) > through ||
      due.toMillis() <= nowMillis ||
      (oldDue && due.toMillis() <= oldDue.toMillis()) ||
      (!oldDue && next.localDate <= snapshot.get("localDate")) ||
      (next.windowStartAtUtc && next.windowStartAtUtc.toMillis() <= nowMillis)
    )
      throw new HttpsError(
        "invalid-argument",
        "Choose a later deadline in the next thirty household days. Untimed chores move to a later day.",
      );
    const rateRef = db.doc(`rateLimits/${actor.uid}`),
      rate = await tx.get(rateRef);
    const day = new Date(nowMillis).toISOString().slice(0, 10);
    const writes =
      rate.get("postponeDay") === day
        ? Number(rate.get("postponeWrites") ?? 0)
        : 0;
    if (writes >= 500)
      throw new HttpsError(
        "resource-exhausted",
        "Daily postponement limit reached.",
      );
    const now = Timestamp.fromMillis(nowMillis),
      version = Number(baseVersion) + 1;
    const patch = {
      ...next,
      ...assignmentNotificationState(snapshot.data(), next, now),
      version,
      updatedAt: now,
      scheduleOverride: {
        kind: "postpone",
        commandId: cid,
        originalLocalDate:
          snapshot.get("scheduleOverride.originalLocalDate") ??
          snapshot.get("localDate"),
        actorId: actor.uid,
        acceptedAt: now,
      },
    };
    tx.update(ref, patch);
    enqueueOccurrenceNotifications(db, tx, hid, oid, version, now);
    const result = { occurrenceId: oid, version };
    tx.create(receipt, {
      uid: actor.uid,
      payloadHash: fingerprint,
      result,
      acceptedAt: now,
    });
    tx.set(
      rateRef,
      { postponeDay: day, postponeWrites: writes + 1 },
      { merge: true },
    );
    tx.create(db.doc(`households/${hid}/activity/${receipt.id}`), {
      action: "occurrence_postponed",
      actorId: actor.uid,
      entityId: oid,
      templateId: snapshot.get("templateId"),
      fromVersion: baseVersion,
      toVersion: version,
      fromStatus: snapshot.get("status"),
      toStatus: snapshot.get("status"),
      fromAssignedActorIds: snapshot.get("assignedActorIds"),
      toAssignedActorIds: snapshot.get("assignedActorIds"),
      fromSchedule: snapshot.get("requestedSchedule"),
      toSchedule: next.requestedSchedule,
      fromDueAtUtc: oldDue ?? null,
      toDueAtUtc: due,
      serverAt: now,
    });
    return result;
  });
}
