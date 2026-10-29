import { Timestamp } from "firebase-admin/firestore";

/** A sparse cancellation patch retains ownership. Only actual owner changes
 * advance its generation; instruction/help/completion edits never do. */
export function assignmentNotificationState(
  before: Record<string, unknown> | undefined,
  next: Record<string, unknown>,
  now: Timestamp,
) {
  const priorIds = (before?.assignedActorIds ?? []) as string[];
  const nextIds = (next.assignedActorIds ?? priorIds) as string[];
  const ownersChanged =
    JSON.stringify([...priorIds].sort()) !==
    JSON.stringify([...nextIds].sort());
  const value = (v: unknown) =>
    v instanceof Timestamp ? v.toMillis() : (v ?? null);
  const timingChanged = [
    "localDate",
    "timezoneIana",
    "dueAtUtc",
    "windowStartAtUtc",
  ].some(
    (key) =>
      value(before?.[key]) !==
      value(Object.hasOwn(next, key) ? next[key] : before?.[key]),
  );
  const previousRevision = Number(before?.assignmentRevision ?? 1);
  if (!Number.isSafeInteger(previousRevision) || previousRevision < 1)
    throw new Error("notification_assignment_revision_invalid");
  return {
    assignmentRevision: before ? previousRevision + (ownersChanged ? 1 : 0) : 1,
    assignmentChangedAt:
      !before || ownersChanged || timingChanged
        ? now
        : before.assignmentChangedAt instanceof Timestamp
          ? before.assignmentChangedAt
          : before.createdAt instanceof Timestamp
            ? before.createdAt
            : now,
  };
}
