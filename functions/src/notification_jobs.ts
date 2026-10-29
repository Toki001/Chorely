import {
  Timestamp,
  type Firestore,
  type Transaction,
  type DocumentSnapshot,
} from "firebase-admin/firestore";
import { identifier, hash } from "./validation.js";
import { parseNotificationPreferences } from "./notification_preferences.js";
import {
  planOccurrenceNotifications,
  type NotificationOccurrence,
  type NotificationRecipient,
} from "./notification_plan.js";

const millis = (value: unknown) =>
  value instanceof Timestamp ? value.toMillis() : null;
async function context(
  db: Firestore,
  tx: Transaction,
  hid: string,
  row: DocumentSnapshot,
) {
  const home = await tx.get(db.doc(`households/${hid}`));
  if (!home.exists || home.get("archivedAt") != null || !row.exists)
    return null;
  const [profiles, members, settings] = await Promise.all([
    tx.get(db.collection(`households/${hid}/profiles`).limit(101)),
    tx.get(
      db
        .collection(`households/${hid}/members`)
        .where("status", "==", "active")
        .limit(201),
    ),
    tx.get(
      db.collection(`households/${hid}/notificationPreferences`).limit(101),
    ),
  ]);
  if (profiles.size > 100 || members.size > 200 || settings.size > 100)
    throw new Error("notification_household_limit");
  const accounts = members.empty
    ? []
    : await tx.getAll(...members.docs.map((m) => db.doc(`users/${m.id}`)));
  const disabled = new Set(
    accounts.filter((a) => a.get("status") === "disabled").map((a) => a.id),
  );
  const recipients = new Map<string, NotificationRecipient>();
  for (const profile of profiles.docs) {
    if (profile.get("role") === "child" && profile.get("status") === "active") {
      recipients.set(profile.id, {
        id: profile.id,
        role: "child",
        canManage: false,
      });
    }
  }
  for (const member of members.docs) {
    const role = member.get("role"),
      account = accounts.find((a) => a.id === member.id);
    const profile = profiles.docs.find((p) => p.id === member.id);
    if (
      !profile ||
      !["guardian", "adult"].includes(role) ||
      disabled.has(member.id) ||
      account?.get("accountType") === "supervised_device" ||
      ![undefined, "active"].includes(profile.get("status"))
    )
      continue;
    recipients.set(member.id, {
      id: member.id,
      role,
      canManage: role === "guardian" || member.get("canAssign") === true,
    });
  }
  const preferences = new Map(
    settings.docs.map((s) => [
      s.id,
      {
        version: Number(s.get("version")),
        preferences: parseNotificationPreferences(s.get("preferences")),
      },
    ]),
  );
  const help =
    (row.get("helpRequests") as Record<
      string,
      { requestId: string; status: "open" | "resolved"; requestedAt: Timestamp }
    >) ?? {};
  const requests = Object.values(help);
  if (requests.length > 6) throw new Error("notification_help_limit");
  const privateHelp = requests.length
    ? await tx.getAll(
        ...requests.map((r) =>
          db.doc(`households/${hid}/helpRequests/${identifier(r.requestId)}`),
        ),
      )
    : [];
  const created = millis(row.get("createdAt"));
  if (created == null) throw new Error("notification_occurrence_missing_time");
  const occurrence: NotificationOccurrence = {
    id: row.id,
    localDate: row.get("localDate"),
    timezoneIana: row.get("timezoneIana"),
    recurring: Number(row.get("recurrenceVersion")) > 0,
    status: row.get("status"),
    assignedActorIds: row.get("assignedActorIds"),
    contributedActorIds: Object.keys(row.get("contributions") ?? {}),
    assignmentRevision: Number(row.get("assignmentRevision") ?? 1),
    completionRevision: Number(row.get("completionRevision") ?? 0),
    reviewMode: row.get("reviewMode"),
    createdAtMillis: created,
    assignmentAtMillis: millis(row.get("assignmentChangedAt")),
    dueAtMillis: millis(row.get("dueAtUtc")),
    windowStartAtMillis: millis(row.get("windowStartAtUtc")),
    completedAtMillis: millis(row.get("completedAt")),
    reviewedAtMillis: millis(row.get("reviewedAt")),
    helpRequests: Object.entries(help).map(([id, r]) => ({
      actorId: id,
      requestId: r.requestId,
      status: r.status,
      requestedAtMillis: r.requestedAt.toMillis(),
      resolvedAtMillis: millis(
        privateHelp.find((d) => d.id === r.requestId)?.get("resolvedAt"),
      ),
    })),
  };
  return {
    occurrence,
    sourceVersion: Number(row.get("version")),
    recipients: [...recipients.values()],
    preferences,
    householdTimezone: home.get("timezoneIana") as string,
  };
}

/** Admin-only producer. It never calls an external notification provider.
 * The same transaction cancels stale jobs and creates one actual inbox entry.
 * Future dispatch must re-run this reconciliation before accepting a job. */
export async function reconcileOccurrenceNotifications(
  db: Firestore,
  householdId: string,
  occurrenceId: string,
  nowMillis = Date.now(),
) {
  const hid = identifier(householdId),
    oid = identifier(occurrenceId);
  return db.runTransaction(async (tx) => {
    const row = await tx.get(db.doc(`households/${hid}/occurrences/${oid}`));
    const ctx = await context(db, tx, hid, row);
    const desired = ctx
      ? planOccurrenceNotifications({ householdId: hid, ...ctx, nowMillis })
      : [];
    const existing = await tx.get(
      db
        .collection(`households/${hid}/notificationJobs`)
        .where("occurrenceId", "==", oid)
        .limit(501),
    );
    if (existing.size > 500 || desired.length > 100)
      throw new Error("notification_job_limit");
    const previous = new Map(existing.docs.map((d) => [d.id, d]));
    const inboxIds = [
      ...new Set([...desired.map((j) => j.id), ...previous.keys()]),
    ];
    const inbox = inboxIds.length
      ? await tx.getAll(
          ...inboxIds.map((id) =>
            db.doc(`households/${hid}/notificationInbox/${id}`),
          ),
        )
      : [];
    const actorIds = [
      ...new Set([
        ...desired.map((j) => j.actorId),
        ...existing.docs.map((d) => d.get("actorId") as string),
      ]),
    ];
    const signals = actorIds.length
      ? await tx.getAll(
          ...actorIds.map((id) =>
            db.doc(`households/${hid}/reminderPlanSignals/${identifier(id)}`),
          ),
        )
      : [];
    let planned = 0,
      published = 0,
      cancelled = 0;
    const active = new Set(desired.map((j) => j.id)),
      now = Timestamp.fromMillis(nowMillis);
    for (const job of desired) {
      const prior = previous.get(job.id),
        message = inbox.find((i) => i.id === job.id);
      const signature = hash(JSON.stringify(job));
      const ready = job.availableAtMillis <= nowMillis;
      const wasPublished =
        prior?.get("publishedAt") != null || message?.exists === true;
      const alertState =
        job.channel === "in_app"
          ? "none"
          : ["accepted", "uncertain"].includes(prior?.get("alertState"))
            ? (prior!.get("alertState") as string)
            : "pending";
      // Never reset read state or issue another copy after an accepted retry.
      if (ready && !wasPublished) {
        tx.set(db.doc(`households/${hid}/notificationInbox/${job.id}`), {
          actorId: job.actorId,
          occurrenceId: oid,
          event: job.event,
          title: job.title,
          body: job.body,
          availableAt: Timestamp.fromMillis(job.availableAtMillis),
          publishedAt: now,
          readAt: null,
          active: true,
        });
        published++;
      } else if (ready && message?.exists && message.get("active") !== true) {
        tx.update(message.ref, { active: true });
      }
      const wake = Math.min(
        job.expiresAtMillis,
        ...(ready ? [] : [job.availableAtMillis]),
        ...(alertState === "pending"
          ? [Math.max(job.notifyAtMillis, nowMillis + 60_000)]
          : []),
      );
      if (
        prior?.get("planHash") !== signature ||
        prior?.get("sourceOccurrenceVersion") !== ctx!.sourceVersion ||
        prior.get("state") === "cancelled" ||
        (!wasPublished && ready)
      ) {
        tx.set(
          db.doc(`households/${hid}/notificationJobs/${job.id}`),
          {
            ...job,
            sourceOccurrenceVersion: ctx!.sourceVersion,
            planHash: signature,
            state: "queued",
            nextWakeAtMillis: wake,
            publishedAt: wasPublished
              ? (prior?.get("publishedAt") ?? message!.get("publishedAt"))
              : ready
                ? now
                : null,
            alertState,
            cancelReason: null,
            updatedAt: now,
          },
          { merge: true },
        );
        planned++;
      } else if (prior.get("nextWakeAtMillis") !== wake) {
        tx.update(prior.ref, { nextWakeAtMillis: wake });
      }
    }
    for (const old of existing.docs) {
      if (active.has(old.id) || old.get("state") === "cancelled") continue;
      tx.update(old.ref, {
        state: "cancelled",
        alertState: ["accepted", "uncertain"].includes(old.get("alertState"))
          ? old.get("alertState")
          : "cancelled",
        cancelReason: "current_state_changed",
        updatedAt: now,
      });
      const message = inbox.find((i) => i.id === old.id);
      if (message?.exists) tx.update(message.ref, { active: false });
      cancelled++;
    }
    if (planned || published || cancelled) {
      for (const signal of signals)
        tx.set(signal.ref, {
          actorId: signal.id,
          version: Number(signal.get("version") ?? 0) + 1,
          updatedAt: now,
        });
    }
    return { planned, published, cancelled };
  });
}
