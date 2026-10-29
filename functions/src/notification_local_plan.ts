import { Timestamp, type Firestore } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";
import type { Actor } from "./contracts.js";
import { authorizeParticipant } from "./completion.js";
import { record, identifier, hash } from "./validation.js";
import {
  defaultNotificationPreferences,
  parseNotificationPreferences,
} from "./notification_preferences.js";
import { reconcileOccurrenceNotifications } from "./notification_jobs.js";

/** At most 60 device-owned reminders in the next 24 hours, preserving four iOS
 * slots. This authorizes a plan, not OS permission or successful delivery. */
export async function getLocalNotificationPlan(
  db: Firestore,
  actor: Actor | null,
  input: unknown,
) {
  if (!actor) throw new HttpsError("unauthenticated", "Sign in first.");
  const hid = identifier(record(input).householdId);
  const first = await db.runTransaction(async (tx) => {
    const person = await authorizeParticipant(db, tx, actor, hid);
    const ref = db.doc(
      `rateLimits/${hash(JSON.stringify([hid, person.actorId, "local_plans"]))}`,
    );
    const limit = await tx.get(ref),
      day = new Date().toISOString().slice(0, 10);
    const count =
      limit.get("day") === day ? Number(limit.get("count") ?? 0) : 0;
    if (count >= 4000)
      throw new HttpsError(
        "resource-exhausted",
        "Reminder refresh limit reached. Your in-app updates are available.",
      );
    tx.set(ref, { day, count: count + 1 });
    return person;
  });
  const query = (id: string, now: number) =>
    db
      .collection(`households/${hid}/notificationJobs`)
      .where("actorId", "==", id)
      .where("channel", "==", "local")
      .where("state", "==", "queued")
      .where("notifyAtMillis", ">=", now - 300_000)
      .where("notifyAtMillis", "<=", now + 86_400_000)
      .orderBy("notifyAtMillis")
      .limit(61);
  const candidates = await query(first.actorId, Date.now()).get();
  const ids = [
    ...new Set(candidates.docs.map((d) => identifier(d.get("occurrenceId")))),
  ];
  for (const id of ids) await reconcileOccurrenceNotifications(db, hid, id);
  return db.runTransaction(async (tx) => {
    const person = await authorizeParticipant(db, tx, actor, hid);
    const setting = await tx.get(
      db.doc(`households/${hid}/notificationPreferences/${person.actorId}`),
    );
    const prefs = setting.exists
      ? parseNotificationPreferences(setting.get("preferences"))
      : defaultNotificationPreferences();
    const version = Number(setting.get("version") ?? 0),
      now = Timestamp.now().toMillis();
    const policyEnabled = prefs.enabled && prefs.channel === "local";
    if (!policyEnabled)
      return {
        policyEnabled: false,
        actorId: person.actorId,
        serverNowMillis: now,
        hasMore: false,
        reminders: [],
      };
    const jobs = await tx.get(query(person.actorId, now));
    const occurrenceIds = [
      ...new Set(jobs.docs.map((d) => identifier(d.get("occurrenceId")))),
    ];
    const rows = occurrenceIds.length
      ? await tx.getAll(
          ...occurrenceIds.map((id) =>
            db.doc(`households/${hid}/occurrences/${id}`),
          ),
        )
      : [];
    const valid = jobs.docs.filter((job) => {
      const row = rows.find((d) => d.id === job.get("occurrenceId"));
      return (
        job.get("preferenceVersion") === version &&
        job.get("expiresAtMillis") > now &&
        row?.exists &&
        row.get("version") === job.get("sourceOccurrenceVersion") &&
        (person.role !== "child" ||
          (row.get("assignedActorIds") as string[]).includes(person.actorId))
      );
    });
    return {
      policyEnabled: true,
      actorId: person.actorId,
      serverNowMillis: now,
      hasMore: jobs.size === 61,
      reminders: valid.slice(0, 60).map((job) => ({
        id: job.id,
        title: job.get("title"),
        body: job.get("body"),
        notifyAtMillis: job.get("notifyAtMillis"),
        expiresAtMillis: job.get("expiresAtMillis"),
        payload: JSON.stringify({
          v: 1,
          householdId: hid,
          notificationId: job.id,
          actorId: person.actorId,
        }),
      })),
    };
  });
}
