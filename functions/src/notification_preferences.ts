import { enqueueHouseholdNotificationRefresh } from "./notification_outbox.js";
import {
  Timestamp,
  type Firestore,
  type Transaction,
} from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";
import type { Actor } from "./contracts.js";
import { authorizeParticipant } from "./completion.js";
import { record, identifier, commandId, hash } from "./validation.js";
import type { QuietHours } from "./notification_time.js";

export type NotificationPreferences = {
  enabled: boolean;
  channel: "in_app" | "push" | "local";
  assignment: boolean;
  due: boolean;
  overdue: boolean;
  review: boolean;
  help: boolean;
  reminderMinutes: 0 | 5 | 15 | 30 | 60;
  quietHours: QuietHours;
};
export const defaultNotificationPreferences = (): NotificationPreferences => ({
  enabled: true,
  channel: "in_app",
  assignment: true,
  due: true,
  overdue: true,
  review: true,
  help: true,
  reminderMinutes: 15,
  quietHours: { enabled: true, start: "20:00", end: "08:00" },
});
export function parseNotificationPreferences(
  value: unknown,
): NotificationPreferences {
  const input = record(value),
    quiet = record(input.quietHours);
  if (
    typeof input.channel !== "string" ||
    !["in_app", "push", "local"].includes(input.channel) ||
    ![0, 5, 15, 30, 60].includes(Number(input.reminderMinutes)) ||
    typeof input.reminderMinutes !== "number" ||
    ["enabled", "assignment", "due", "overdue", "review", "help"].some(
      (key) => typeof input[key] !== "boolean",
    ) ||
    typeof quiet.enabled !== "boolean" ||
    typeof quiet.start !== "string" ||
    typeof quiet.end !== "string" ||
    !/^([01]\d|2[0-3]):[0-5]\d$/.test(quiet.start) ||
    !/^([01]\d|2[0-3]):[0-5]\d$/.test(quiet.end) ||
    quiet.start === quiet.end
  ) {
    throw new HttpsError(
      "invalid-argument",
      "Choose valid notification and quiet-hour settings.",
    );
  }
  return {
    enabled: input.enabled as boolean,
    channel: input.channel as NotificationPreferences["channel"],
    assignment: input.assignment as boolean,
    due: input.due as boolean,
    overdue: input.overdue as boolean,
    review: input.review as boolean,
    help: input.help as boolean,
    reminderMinutes:
      input.reminderMinutes as NotificationPreferences["reminderMinutes"],
    quietHours: { enabled: quiet.enabled, start: quiet.start, end: quiet.end },
  };
}
async function scope(
  db: Firestore,
  tx: Transaction,
  actor: Actor,
  hid: string,
  target: string | undefined,
  writing: boolean,
) {
  const person = await authorizeParticipant(db, tx, actor, hid);
  const id = target ?? person.actorId;
  const profile = await tx.get(db.doc(`households/${hid}/profiles/${id}`));
  const managedChild =
    person.role === "guardian" &&
    profile.get("role") === "child" &&
    profile.get("status") === "active";
  // M05 adult profiles predate the optional status field. Membership/account
  // authorization above remains authoritative; child profiles require explicit
  // active status, as in the supervised pairing/completion contract.
  const profileActive =
    profile.get("role") === "child"
      ? profile.get("status") === "active"
      : ["guardian", "adult"].includes(profile.get("role")) &&
        (profile.get("status") == null || profile.get("status") === "active");
  if (
    !profile.exists ||
    !profileActive ||
    (id !== person.actorId && !managedChild) ||
    (writing && person.role === "child")
  ) {
    throw new HttpsError(
      "permission-denied",
      "A guardian manages supervised notification settings. Adult settings are private to their owner.",
    );
  }
  return { ...person, target: id };
}
export async function getNotificationPreferences(
  db: Firestore,
  actor: Actor | null,
  input: unknown,
) {
  if (!actor) throw new HttpsError("unauthenticated", "Sign in first.");
  const data = record(input),
    hid = identifier(data.householdId),
    target = data.actorId == null ? undefined : identifier(data.actorId);
  return db.runTransaction(async (tx) => {
    const person = await scope(db, tx, actor, hid, target, false);
    const prefs = await tx.get(
      db.doc(`households/${hid}/notificationPreferences/${person.target}`),
    );
    return {
      actorId: person.target,
      version: Number(prefs.get("version") ?? 0),
      timezoneIana: person.household.get("timezoneIana"),
      canEdit: person.role !== "child",
      preferences: prefs.exists
        ? parseNotificationPreferences(prefs.get("preferences"))
        : defaultNotificationPreferences(),
    };
  });
}
export async function saveNotificationPreferences(
  db: Firestore,
  actor: Actor | null,
  input: unknown,
) {
  if (!actor) throw new HttpsError("unauthenticated", "Sign in first.");
  const data = record(input),
    hid = identifier(data.householdId),
    cid = commandId(data.commandId);
  const target = data.actorId == null ? undefined : identifier(data.actorId);
  const preferences = parseNotificationPreferences(data.preferences);
  if (
    typeof data.expectedTimezone !== "string" ||
    data.expectedTimezone.length > 100
  ) {
    throw new HttpsError(
      "invalid-argument",
      "Load the household timezone first.",
    );
  }
  const baseVersion = data.baseVersion;
  if (
    typeof baseVersion !== "number" ||
    !Number.isSafeInteger(baseVersion) ||
    baseVersion < 0
  )
    throw new HttpsError(
      "invalid-argument",
      "Load the current settings first.",
    );
  const receipt = db.doc(
    `commands/${hash(JSON.stringify([actor.uid, cid, "notification_preferences"]))}`,
  );
  return db.runTransaction(async (tx) => {
    const person = await scope(db, tx, actor, hid, target, true);
    const timezone = person.household.get("timezoneIana") as string;
    const payloadHash = hash(
      JSON.stringify([
        hid,
        person.target,
        baseVersion,
        data.expectedTimezone,
        preferences,
      ]),
    );
    const prior = await tx.get(receipt);
    if (prior.exists) {
      if (prior.get("payloadHash") !== payloadHash)
        throw new HttpsError(
          "already-exists",
          "Use a new request for changed settings.",
        );
      return prior.get("result") as { actorId: string; version: number };
    }
    const ref = db.doc(
      `households/${hid}/notificationPreferences/${person.target}`,
    );
    const before = await tx.get(ref);
    if (
      Number(before.get("version") ?? 0) !== baseVersion ||
      data.expectedTimezone !== timezone
    ) {
      throw new HttpsError(
        "aborted",
        "Settings or household timezone changed. Reload before saving.",
      );
    }
    const now = Timestamp.now(),
      day = now.toDate().toISOString().slice(0, 10);
    const limitRef = db.doc(`rateLimits/${actor.uid}`),
      limit = await tx.get(limitRef);
    const writes =
      limit.get("notificationPreferenceDay") === day
        ? Number(limit.get("notificationPreferenceWrites") ?? 0)
        : 0;
    if (writes >= 100)
      throw new HttpsError(
        "resource-exhausted",
        "Notification setting limit reached. Try another day.",
      );
    const version = baseVersion + 1,
      result = { actorId: person.target, version };
    tx.set(ref, {
      actorId: person.target,
      preferences,
      version,
      updatedAt: now,
    });
    tx.set(
      limitRef,
      {
        notificationPreferenceDay: day,
        notificationPreferenceWrites: writes + 1,
      },
      { merge: true },
    );
    tx.create(receipt, { payloadHash, result, acceptedAt: now });
    enqueueHouseholdNotificationRefresh(db, tx, hid, now);
    // No sleep times, child nickname, device UID or token enters household activity.
    tx.create(
      db.doc(
        `households/${hid}/activity/${hash(JSON.stringify([actor.uid, cid, "notification_preferences"]))}`,
      ),
      {
        action: "notification_preferences_saved",
        actorId: person.actorId,
        targetActorId: person.target,
        entityId: person.target,
        fromVersion: baseVersion,
        toVersion: version,
        serverAt: now,
      },
    );
    return result;
  });
}
