import { randomUUID } from "node:crypto";
import {
  type Firestore,
  type Transaction,
  type Timestamp,
} from "firebase-admin/firestore";
import { hash } from "./validation.js";

/** Written in the same transaction as the actual occurrence revision. Cursor
 * ordering cannot lose two accepted changes that share a clock millisecond. */
export function enqueueOccurrenceNotifications(
  db: Firestore,
  tx: Transaction,
  hid: string,
  oid: string,
  version: number,
  now: Timestamp,
) {
  tx.create(
    db.doc(`notificationOutbox/${hash(JSON.stringify([hid, oid, version]))}`),
    {
      householdId: hid,
      occurrenceId: oid,
      sourceVersion: version,
      state: "pending",
      nextAttemptAtMillis: now.toMillis(),
      attempts: 0,
      createdAt: now,
    },
  );
}
export function enqueueHouseholdNotificationRefresh(
  db: Firestore,
  tx: Transaction,
  hid: string,
  now: Timestamp,
) {
  tx.set(db.doc(`notificationHouseholdRefresh/${hid}`), {
    householdId: hid,
    generation: randomUUID(),
    state: "pending",
    afterId: null,
    attempts: 0,
    nextAttemptAtMillis: now.toMillis(),
    requestedAt: now,
  });
}
