import { Timestamp, type Firestore } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";
import type { Actor } from "./contracts.js";
import { authorizeParticipant } from "./completion.js";
import { record, identifier, hash } from "./validation.js";
import {
  defaultNotificationPreferences,
  parseNotificationPreferences,
} from "./notification_preferences.js";

/** A tap grants no authority. Current ownership, membership and assignment are
 * rechecked before returning a route. Read acknowledgement is monotonic: retries
 * preserve the first accepted server read timestamp, with no progress mutation. */
export async function openNotification(
  db: Firestore,
  actor: Actor | null,
  input: unknown,
) {
  if (!actor) throw new HttpsError("unauthenticated", "Sign in first.");
  const data = record(input),
    hid = identifier(data.householdId),
    id = identifier(data.notificationId);
  return db.runTransaction(async (tx) => {
    const person = await authorizeParticipant(db, tx, actor, hid);
    const ref = db.doc(`households/${hid}/notificationInbox/${id}`),
      message = await tx.get(ref);
    const now = Timestamp.now();
    // A device-owned OS alarm can precede the next inbox worker tick. A private
    // current job may authorize that tap, but never an arbitrary payload ID.
    const job = message.exists
      ? null
      : await tx.get(db.doc(`households/${hid}/notificationJobs/${id}`));
    const source = message.exists ? message : job;
    if (!source?.exists || source.get("actorId") !== person.actorId)
      return { available: false };
    const oid = identifier(source.get("occurrenceId"));
    const row = await tx.get(db.doc(`households/${hid}/occurrences/${oid}`));
    const setting = job
      ? await tx.get(
          db.doc(`households/${hid}/notificationPreferences/${person.actorId}`),
        )
      : null;
    const prefs = setting?.exists
      ? parseNotificationPreferences(setting.get("preferences"))
      : defaultNotificationPreferences();
    const validJob =
      job?.exists &&
      job.get("state") === "queued" &&
      job.get("channel") === "local" &&
      job.get("availableAtMillis") <= now.toMillis() &&
      job.get("expiresAtMillis") > now.toMillis() &&
      job.get("sourceOccurrenceVersion") === row.get("version") &&
      prefs.enabled &&
      prefs.channel === "local" &&
      job.get("preferenceVersion") === Number(setting?.get("version") ?? 0);
    if (!message.exists && !validJob) return { available: false };
    const available =
      (message.exists ? message.get("active") === true : validJob) &&
      row.exists &&
      (person.role !== "child" ||
        (row.get("assignedActorIds") as string[]).includes(person.actorId));
    if (!message.exists || message.get("readAt") == null) {
      const limitRef = db.doc(
        `rateLimits/${hash(JSON.stringify([hid, person.actorId, "notification_reads"]))}`,
      );
      const limit = await tx.get(limitRef),
        day = now.toDate().toISOString().slice(0, 10);
      const reads =
        limit.get("day") === day ? Number(limit.get("count") ?? 0) : 0;
      if (reads >= 1000)
        throw new HttpsError(
          "resource-exhausted",
          "Update limit reached. Open your chores from the calendar.",
        );
      if (message.exists) tx.update(ref, { readAt: now });
      else if (available && job) {
        tx.set(ref, {
          actorId: person.actorId,
          occurrenceId: oid,
          event: job.get("event"),
          title: job.get("title"),
          body: job.get("body"),
          availableAt: Timestamp.fromMillis(job.get("availableAtMillis")),
          publishedAt: now,
          readAt: now,
          active: true,
        });
        tx.update(job.ref, { publishedAt: now });
      }
      tx.set(limitRef, { day, count: reads + 1 });
    }
    return available
      ? {
          available: true,
          householdId: hid,
          occurrenceId: oid,
          actorId: person.actorId,
          version: row.get("version") as number,
        }
      : { available: false };
  });
}
