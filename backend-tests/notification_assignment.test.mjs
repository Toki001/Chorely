import { test } from "node:test";
import assert from "node:assert/strict";
import { Timestamp } from "firebase-admin/firestore";
import { assignmentNotificationState } from "../functions/lib/notification_assignment.js";
const first = Timestamp.fromMillis(1_000),
  later = Timestamp.fromMillis(2_000);
const row = {
  assignedActorIds: ["child", "adult"],
  assignmentRevision: 1,
  assignmentChangedAt: first,
  createdAt: first,
  localDate: "2026-10-29",
  timezoneIana: "Asia/Manila",
  dueAtUtc: first,
  windowStartAtUtc: null,
};
test("Instruction edits, reordered team IDs and sparse cancellations preserve notification generation/time", () => {
  for (const patch of [
    { title: "New instructions" },
    { status: "cancelled" },
    { assignedActorIds: ["adult", "child"] },
  ]) {
    const state = assignmentNotificationState(row, patch, later);
    assert.equal(state.assignmentRevision, 1);
    assert.equal(state.assignmentChangedAt.toMillis(), 1_000);
  }
});
test("New owners advance generation; due changes update event time without inflating ownership history", () => {
  const owner = assignmentNotificationState(
    row,
    { assignedActorIds: ["child"] },
    later,
  );
  assert.equal(owner.assignmentRevision, 2);
  assert.equal(owner.assignmentChangedAt.toMillis(), 2_000);
  for (const patch of [
    { dueAtUtc: null },
    { localDate: "2026-10-30" },
    { timezoneIana: "Etc/UTC" },
  ]) {
    const changed = assignmentNotificationState(row, patch, later);
    assert.equal(changed.assignmentRevision, 1);
    assert.equal(changed.assignmentChangedAt.toMillis(), 2_000);
  }
});
test("Existing rows use stored creation time and new slots start at generation one", () => {
  const { assignmentRevision, assignmentChangedAt, ...legacy } = row;
  assert.equal(
    assignmentNotificationState(
      legacy,
      { title: "Instructions" },
      later,
    ).assignmentChangedAt.toMillis(),
    first.toMillis(),
  );
  assert.equal(
    assignmentNotificationState(undefined, row, later).assignmentRevision,
    1,
  );
  assert.equal(
    assignmentNotificationState(
      undefined,
      row,
      later,
    ).assignmentChangedAt.toMillis(),
    later.toMillis(),
  );
});
