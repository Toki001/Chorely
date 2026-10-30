import { enqueueOccurrenceNotifications } from "./notification_outbox.js";
import { assignmentNotificationState } from "./notification_assignment.js";
import type { Firestore, Transaction } from "firebase-admin/firestore";
import { Timestamp } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";
import type { Actor } from "./contracts.js";
import { requireAdult } from "./households.js";
import { identifier, commandId, record, text, hash } from "./validation.js";
import { resolveLocalMinute, validateLocalDate } from "./local_time.js";

const categories = [
  "dinner",
  "kitchen",
  "pets",
  "rooms",
  "household",
  "supplies",
];
function multiline(value: unknown, max: number): string {
  if (
    typeof value !== "string" ||
    value.length > max ||
    /[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/.test(value)
  )
    throw new HttpsError("invalid-argument", "Invalid instructions.");
  return value.replace(/\r\n?/g, "\n").trim();
}
function content(data: Record<string, unknown>) {
  const title = text(data.title, "title", 100);
  const category = text(data.category, "category", 20);
  if (!categories.includes(category))
    throw new HttpsError("invalid-argument", "Invalid category.");
  const description = multiline(data.description ?? "", 2000);
  const instructionIllustrationKey = data.instructionIllustrationKey ?? null;
  if (
    instructionIllustrationKey !== null &&
    instructionIllustrationKey !== "assign"
  )
    throw new HttpsError("invalid-argument", "Invalid bundled illustration.");
  const room =
    data.room == null || data.room === "" ? "" : text(data.room, "room", 80);
  if (!Array.isArray(data.steps) || data.steps.length > 12)
    throw new HttpsError("invalid-argument", "Use at most 12 steps.");
  const steps = data.steps.map((s) => text(s, "step", 200));
  if (
    !Array.isArray(data.assignedActorIds) ||
    data.assignedActorIds.length < 1 ||
    data.assignedActorIds.length > 6
  )
    throw new HttpsError(
      "invalid-argument",
      "Choose one to six household members.",
    );
  const assignedActorIds = [
    ...new Set(data.assignedActorIds.map(identifier)),
  ].sort();
  if (assignedActorIds.length !== data.assignedActorIds.length)
    throw new HttpsError("invalid-argument", "Duplicate assignee.");
  const completionPolicy = data.completionPolicy;
  if (
    completionPolicy !== "any_one_completes" &&
    completionPolicy !== "all_members_complete"
  )
    throw new HttpsError(
      "invalid-argument",
      "Choose a team completion policy.",
    );
  const reviewMode = data.reviewMode;
  if (reviewMode !== "none" && reviewMode !== "guardian")
    throw new HttpsError("invalid-argument", "Invalid review policy.");
  const schedule = record(data.schedule);
  const kind = schedule.kind;
  if (!["none", "time", "deadline", "range"].includes(String(kind)))
    throw new HttpsError("invalid-argument", "Invalid timing policy.");
  const date = text(schedule.date, "date", 10);
  try {
    validateLocalDate(date);
  } catch {
    throw new HttpsError("invalid-argument", "Choose a valid calendar date.");
  }
  const at =
    kind === "time" || kind === "deadline"
      ? text(schedule.at, "time", 5)
      : null;
  const start =
    kind === "range" ? text(schedule.startLocal, "window start", 16) : null;
  const end =
    kind === "range" ? text(schedule.endLocal, "window end", 16) : null;
  return {
    title,
    category,
    iconKey: category,
    description,
    instructionIllustrationKey,
    room,
    steps,
    assignedActorIds,
    completionPolicy,
    reviewMode,
    schedule: {
      kind: String(kind),
      date,
      at,
      startLocal: start,
      endLocal: end,
    },
  };
}
type Content = ReturnType<typeof content>;
function timing(value: Content, zone: string) {
  const schedule = value.schedule;
  let start: ReturnType<typeof resolveLocalMinute> | null = null;
  let due: ReturnType<typeof resolveLocalMinute> | null = null;
  try {
    if (schedule.kind === "range") {
      if (!schedule.startLocal!.startsWith(`${schedule.date}T`))
        throw new RangeError("Start date mismatch");
      start = resolveLocalMinute(schedule.startLocal!, zone);
      due = resolveLocalMinute(schedule.endLocal!, zone);
      if (
        due.utcMillis <= start.utcMillis ||
        due.utcMillis - start.utcMillis > 7 * 86_400_000
      )
        throw new RangeError("Invalid window");
    } else if (schedule.kind !== "none") {
      due = resolveLocalMinute(`${schedule.date}T${schedule.at}`, zone);
    }
  } catch {
    throw new HttpsError(
      "invalid-argument",
      "Choose a valid time or window of at most seven days.",
    );
  }
  return {
    localDate: schedule.date,
    timezoneIana: zone,
    timingKind: schedule.kind,
    requestedSchedule: schedule,
    dueAtUtc: due ? Timestamp.fromMillis(due.utcMillis) : null,
    windowStartAtUtc: start ? Timestamp.fromMillis(start.utcMillis) : null,
    effectiveDueLocal: due?.effectiveLocal ?? null,
    effectiveStartLocal: start?.effectiveLocal ?? null,
    timeAdjusted: (due?.adjusted ?? false) || (start?.adjusted ?? false),
  };
}
async function authorized(
  db: Firestore,
  tx: Transaction,
  actor: Actor,
  hid: string,
) {
  const home = await tx.get(db.doc(`households/${hid}`));
  const member = await tx.get(db.doc(`households/${hid}/members/${actor.uid}`));
  const account = await tx.get(db.doc(`users/${actor.uid}`));
  if (
    !home.exists ||
    home.get("archivedAt") != null ||
    member.get("status") !== "active" ||
    !["guardian", "adult"].includes(member.get("role")) ||
    (member.get("role") !== "guardian" && member.get("canAssign") !== true) ||
    account.get("status") === "disabled" ||
    account.get("accountType") === "supervised_device"
  )
    throw new HttpsError(
      "permission-denied",
      "Chore management permission required.",
    );
  return home;
}
async function eligible(
  db: Firestore,
  tx: Transaction,
  hid: string,
  value: Content,
) {
  let hasChild = false;
  for (const id of value.assignedActorIds) {
    const profile = await tx.get(db.doc(`households/${hid}/profiles/${id}`));
    if (!profile.exists || profile.get("status") === "revoked")
      throw new HttpsError(
        "invalid-argument",
        "An assignee is unavailable. Reload the roster.",
      );
    if (profile.get("role") === "child") {
      hasChild = true;
      if (profile.get("status") !== "active")
        throw new HttpsError("invalid-argument", "Child profile unavailable.");
    } else {
      const member = await tx.get(db.doc(`households/${hid}/members/${id}`));
      if (
        member.get("status") !== "active" ||
        !["guardian", "adult"].includes(member.get("role"))
      )
        throw new HttpsError(
          "invalid-argument",
          "Assignee no longer belongs to this household.",
        );
    }
  }
  if (value.reviewMode === "guardian") {
    const members = await tx.get(
      db
        .collection(`households/${hid}/members`)
        .where("status", "==", "active"),
    );
    if (
      !members.docs.some(
        (m) =>
          m.get("role") === "guardian" &&
          !value.assignedActorIds.includes(m.id),
      )
    )
      throw new HttpsError(
        "failed-precondition",
        "Review requires a guardian who is not an assignee.",
      );
  }
  return hasChild;
}
function revision(value: unknown): number {
  if (!Number.isSafeInteger(value) || Number(value) < 1)
    throw new HttpsError("invalid-argument", "Invalid base version.");
  return Number(value);
}
export async function writeOneOffChore(
  db: Firestore,
  actor: Actor | null,
  input: unknown,
) {
  requireAdult(actor);
  const data = record(input);
  const hid = identifier(data.householdId);
  const cid = commandId(data.commandId);
  const action = data.action;
  if (!["create", "edit", "archive"].includes(String(action)))
    throw new HttpsError("invalid-argument", "Invalid chore action.");
  const id =
    action === "create"
      ? hash(JSON.stringify([actor.uid, cid, "template"]))
      : identifier(data.templateId);
  const occurrenceId =
    action === "create"
      ? hash(JSON.stringify([hid, id, "once"]))
      : identifier(data.occurrenceId);
  const value = action === "archive" ? null : content(data);
  const baseTemplateVersion =
    action === "create" ? 0 : revision(data.baseTemplateVersion);
  const baseOccurrenceVersion =
    action === "create" ? 0 : revision(data.baseOccurrenceVersion);
  const receipt = db.doc(
    `commands/${hash(JSON.stringify([actor.uid, cid, "oneOff"]))}`,
  );
  const payloadHash = hash(
    JSON.stringify({
      hid,
      action,
      id,
      occurrenceId,
      value,
      baseTemplateVersion,
      baseOccurrenceVersion,
    }),
  );
  return db.runTransaction(async (tx) => {
    const home = await authorized(db, tx, actor, hid);
    const prior = await tx.get(receipt);
    if (prior.exists) {
      if (prior.get("payloadHash") !== payloadHash)
        throw new HttpsError("already-exists", "Request ID already used.");
      return prior.get("result") as {
        templateId: string;
        occurrenceId: string;
        version: number;
      };
    }
    const template = db.doc(`households/${hid}/choreTemplates/${id}`);
    const occurrence = db.doc(`households/${hid}/occurrences/${occurrenceId}`);
    const oldTemplate = await tx.get(template);
    const oldOccurrence = await tx.get(occurrence);
    const rateRef = db.doc(`rateLimits/${actor.uid}`);
    const rate = await tx.get(rateRef);
    const now = Timestamp.now();
    const day = new Date(now.toMillis()).toISOString().slice(0, 10);
    const writes =
      rate.get("choreDay") === day ? Number(rate.get("choreWrites") ?? 0) : 0;
    if (writes >= 500)
      throw new HttpsError(
        "resource-exhausted",
        "Daily chore management limit reached.",
      );
    if (action !== "create") {
      if (
        !oldTemplate.exists ||
        !oldOccurrence.exists ||
        oldOccurrence.get("templateId") !== id ||
        oldTemplate.get("scheduleKind") !== "once"
      )
        throw new HttpsError("not-found", "One-off chore unavailable.");
      if (
        oldTemplate.get("version") !== baseTemplateVersion ||
        oldOccurrence.get("version") !== baseOccurrenceVersion
      )
        throw new HttpsError(
          "aborted",
          "This chore changed. Reload it before editing.",
          {
            templateVersion: oldTemplate.get("version"),
            occurrenceVersion: oldOccurrence.get("version"),
          },
        );
      if (
        oldTemplate.get("active") !== true ||
        oldOccurrence.get("status") !== "scheduled"
      )
        throw new HttpsError(
          "failed-precondition",
          "This occurrence can no longer be edited or cancelled here.",
        );
    }
    if (
      action === "edit" &&
      Object.keys(oldOccurrence.get("contributions") ?? {}).length > 0
    )
      throw new HttpsError(
        "failed-precondition",
        "This occurrence already has recorded work. Keep its instructions and assignment intact.",
      );
    const hasChild = value ? await eligible(db, tx, hid, value) : false;
    const version = baseOccurrenceVersion + 1;
    if (action === "archive") {
      tx.update(template, {
        active: false,
        version: baseTemplateVersion + 1,
        updatedAt: now,
      });
      tx.update(occurrence, { status: "cancelled", version, cancelledAt: now });
    } else {
      const storedTiming = timing(value!, home.get("timezoneIana") as string);
      const definition = {
        ...value!,
        scheduleKind: "once",
        childVisible: hasChild,
        active: true,
        version: baseTemplateVersion + 1,
        updatedAt: now,
      };
      const concrete = {
        ...value!,
        ...storedTiming,
        templateId: id,
        templateVersion: baseTemplateVersion + 1,
        recurrenceVersion: 0,
        slotKey: `once:${id}`,
        status: "scheduled",
        version,
        updatedAt: now,
      };
      Object.assign(
        concrete,
        assignmentNotificationState(oldOccurrence.data(), concrete, now),
      );
      if (action === "create") {
        tx.create(template, {
          ...definition,
          createdAt: now,
          createdBy: actor.uid,
        });
        tx.create(occurrence, { ...concrete, createdAt: now });
      } else {
        tx.update(template, definition);
        tx.update(occurrence, concrete);
      }
    }
    const result = { templateId: id, occurrenceId, version };
    enqueueOccurrenceNotifications(db, tx, hid, occurrenceId, version, now);
    tx.create(receipt, {
      uid: actor.uid,
      payloadHash,
      result,
      acceptedAt: now,
    });
    tx.set(
      rateRef,
      { choreDay: day, choreWrites: writes + 1 },
      { merge: true },
    );
    tx.create(db.doc(`households/${hid}/activity/${receipt.id}`), {
      action: `chore_${action}`,
      actorId: actor.uid,
      entityId: occurrenceId,
      templateId: id,
      fromVersion: baseOccurrenceVersion,
      toVersion: version,
      fromAssignedActorIds: oldOccurrence.get("assignedActorIds") ?? [],
      toAssignedActorIds:
        value?.assignedActorIds ?? oldOccurrence.get("assignedActorIds") ?? [],
      fromStatus: oldOccurrence.get("status") ?? null,
      toStatus: action === "archive" ? "cancelled" : "scheduled",
      serverAt: now,
    });
    return result;
  });
}

// Reuse the same trusted content and permission boundary for recurring definitions.
export { content as parseChoreContent, authorized as authorizeChoreManager };
export { timing as resolveChoreTiming, eligible as validateChoreAssignees };
