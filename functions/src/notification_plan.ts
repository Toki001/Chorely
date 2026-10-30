import { hash } from "./validation.js";
import { resolveLocalMinute } from "./local_time.js";
import { addCivilDays } from "./recurrence_engine.js";
import { afterQuietHours } from "./notification_time.js";
import {
  defaultNotificationPreferences,
  type NotificationPreferences,
} from "./notification_preferences.js";

export type NotificationEvent =
  | "assigned"
  | "upcoming"
  | "due"
  | "overdue"
  | "review"
  | "approved"
  | "redo"
  | "help"
  | "help_resolved";
export type NotificationRecipient = {
  id: string;
  role: "guardian" | "adult" | "child";
  canManage: boolean;
};
export type NotificationOccurrence = {
  id: string;
  localDate: string;
  timezoneIana: string;
  recurring: boolean;
  status: string;
  assignedActorIds: string[];
  contributedActorIds: string[];
  assignmentRevision: number;
  completionRevision: number;
  reviewMode: string;
  createdAtMillis: number;
  assignmentAtMillis: number | null;
  dueAtMillis: number | null;
  windowStartAtMillis: number | null;
  completedAtMillis: number | null;
  reviewedAtMillis: number | null;
  helpRequests: {
    actorId: string;
    requestId: string;
    status: "open" | "resolved";
    requestedAtMillis: number;
    resolvedAtMillis: number | null;
  }[];
};
export type PlannedNotification = {
  id: string;
  householdId: string;
  occurrenceId: string;
  actorId: string;
  event: NotificationEvent;
  sourceRevision: string;
  preferenceVersion: number;
  channel: NotificationPreferences["channel"];
  availableAtMillis: number;
  notifyAtMillis: number;
  expiresAtMillis: number;
  title: string;
  body: string;
};
const copy: Record<NotificationEvent, [string, string]> = {
  assigned: ["Your home team", "A chore is ready for you."],
  upcoming: ["A little heads-up", "A household chore is coming up."],
  due: ["Your household", "A chore is due."],
  overdue: [
    "Need a hand?",
    "A chore is past due. Open Chorely when you’re ready.",
  ],
  review: ["Time for a look", "A household chore is waiting for review."],
  approved: ["Thanks for your help", "A chore has been approved."],
  redo: ["Another look", "A chore needs another look."],
  help: ["A little teamwork", "Someone asked for help with a chore."],
  help_resolved: [
    "A little teamwork",
    "Your help request was marked answered.",
  ],
};

/** Input is a trusted current server snapshot and current authorized roster.
 * No note, nickname, address or chore title is accepted by this lock-screen plan.
 * Persistence/dispatch must recheck that the same candidate is still desired. */
export function planOccurrenceNotifications(input: {
  householdId: string;
  householdTimezone: string;
  occurrence: NotificationOccurrence;
  recipients: NotificationRecipient[];
  preferences: ReadonlyMap<
    string,
    { version: number; preferences: NotificationPreferences }
  >;
  nowMillis: number;
}): PlannedNotification[] {
  const { occurrence: row, nowMillis } = input;
  if (["cancelled", "skipped"].includes(row.status)) return [];
  const jobs: PlannedNotification[] = [];
  const people = new Map(input.recipients.map((p) => [p.id, p]));
  const endOfSlot = resolveLocalMinute(
    `${addCivilDays(row.localDate, 1)}T00:00`,
    row.timezoneIana,
  ).utcMillis;
  const scheduleRevision = hash(
    JSON.stringify([
      row.assignmentRevision,
      row.localDate,
      row.timezoneIana,
      row.dueAtMillis,
      row.windowStartAtMillis,
      [...row.assignedActorIds].sort(),
    ]),
  );
  const emit = (
    id: string,
    event: NotificationEvent,
    revision: string,
    available: number,
    expires: number,
  ) => {
    if (!people.has(id)) return;
    const setting = input.preferences.get(id) ?? {
      version: 0,
      preferences: defaultNotificationPreferences(),
    };
    const p = setting.preferences;
    const enabled = switchPreference(event, p);
    if (
      !p.enabled ||
      !enabled ||
      !Number.isFinite(available) ||
      !Number.isFinite(expires)
    )
      return;
    const notify =
      p.channel === "in_app"
        ? available
        : afterQuietHours(available, input.householdTimezone, p.quietHours);
    if (expires <= nowMillis || notify >= expires || available >= expires)
      return;
    const [title, body] = copy[event];
    jobs.push({
      id: hash(
        JSON.stringify([input.householdId, row.id, id, event, revision]),
      ),
      householdId: input.householdId,
      occurrenceId: row.id,
      actorId: id,
      event,
      sourceRevision: revision,
      preferenceVersion: setting.version,
      channel: p.channel,
      availableAtMillis: available,
      notifyAtMillis: notify,
      expiresAtMillis: expires,
      title,
      body,
    });
  };
  if (["scheduled", "needs_redo"].includes(row.status)) {
    for (const actorId of row.assignedActorIds) {
      if (row.contributedActorIds.includes(actorId)) continue;
      const prefs =
        input.preferences.get(actorId)?.preferences ??
        defaultNotificationPreferences();
      const recurringStart = resolveLocalMinute(
        `${row.localDate}T08:00`,
        row.timezoneIana,
      ).utcMillis;
      const assignmentTime = row.assignmentAtMillis ?? row.createdAtMillis;
      const assignedAt = row.recurring
        ? Math.max(
            assignmentTime,
            Math.min(
              recurringStart,
              row.dueAtMillis == null
                ? recurringStart
                : row.dueAtMillis - prefs.reminderMinutes * 60_000,
            ),
          )
        : assignmentTime;
      emit(
        actorId,
        "assigned",
        // A later deadline changes timing reminders, not who received a turn.
        // Keep a published/read assignment from alerting again after postpone.
        hash(
          JSON.stringify([
            row.assignmentRevision,
            [...row.assignedActorIds].sort(),
          ]),
        ),
        assignedAt,
        row.dueAtMillis ?? endOfSlot,
      );
      if (row.dueAtMillis != null) {
        const due = row.dueAtMillis;
        if (prefs.reminderMinutes > 0)
          emit(
            actorId,
            "upcoming",
            scheduleRevision,
            Math.max(assignmentTime, due - prefs.reminderMinutes * 60_000),
            due,
          );
        emit(actorId, "due", scheduleRevision, due, due + 3_600_000);
        // One gentle follow-up; no escalating or repeated overdue nag loop.
        emit(
          actorId,
          "overdue",
          scheduleRevision,
          due + 3_600_000,
          due + 86_400_000,
        );
      }
    }
  }
  if (
    row.status === "pending_review" &&
    row.reviewMode === "guardian" &&
    row.completedAtMillis != null
  ) {
    for (const person of people.values()) {
      if (
        person.role === "guardian" &&
        !row.assignedActorIds.includes(person.id) &&
        !row.contributedActorIds.includes(person.id)
      ) {
        emit(
          person.id,
          "review",
          String(row.completionRevision),
          row.completedAtMillis,
          row.completedAtMillis + 7 * 86_400_000,
        );
      }
    }
  }
  if (
    ["approved", "needs_redo"].includes(row.status) &&
    row.reviewedAtMillis != null
  ) {
    for (const id of row.assignedActorIds)
      emit(
        id,
        row.status === "approved" ? "approved" : "redo",
        String(row.completionRevision),
        row.reviewedAtMillis,
        row.reviewedAtMillis + 7 * 86_400_000,
      );
  }
  for (const help of row.helpRequests) {
    if (!people.has(help.actorId)) continue;
    if (help.status === "open") {
      for (const person of people.values()) {
        if (person.id !== help.actorId && person.canManage)
          emit(
            person.id,
            "help",
            help.requestId,
            help.requestedAtMillis,
            help.requestedAtMillis + 7 * 86_400_000,
          );
      }
    } else if (help.resolvedAtMillis != null) {
      emit(
        help.actorId,
        "help_resolved",
        help.requestId,
        help.resolvedAtMillis,
        help.resolvedAtMillis + 7 * 86_400_000,
      );
    }
  }
  return jobs.sort(
    (a, b) => a.notifyAtMillis - b.notifyAtMillis || a.id.localeCompare(b.id),
  );
}
function switchPreference(
  event: NotificationEvent,
  p: NotificationPreferences,
) {
  switch (event) {
    case "assigned":
      return p.assignment;
    case "upcoming":
      return p.reminderMinutes > 0;
    case "due":
      return p.due;
    case "overdue":
      return p.overdue;
    case "review":
    case "approved":
    case "redo":
      return p.review;
    case "help":
    case "help_resolved":
      return p.help;
  }
}
