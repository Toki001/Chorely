import { Timestamp, type Firestore } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";
import type { Actor } from "./contracts.js";
import { authorizeParticipant } from "./completion.js";
import { record, identifier } from "./validation.js";
import { householdDate, addCivilDays } from "./recurrence_engine.js";
import { resolveLocalMinute } from "./local_time.js";

export function householdClockAt(nowMillis: number, zone: string) {
  const today = householdDate(nowMillis, zone);
  const nextMidnight = resolveLocalMinute(
    `${addCivilDays(today, 1)}T00:00`,
    zone,
  ).utcMillis;
  return {
    today,
    timezoneIana: zone,
    serverNowMillis: nowMillis,
    nextMidnightMillis: nextMidnight,
  };
}
export async function getHouseholdClock(
  db: Firestore,
  actor: Actor | null,
  input: unknown,
) {
  if (!actor) throw new HttpsError("unauthenticated", "Sign in first.");
  const hid = identifier(record(input).householdId);
  return db.runTransaction(async (tx) => {
    const person = await authorizeParticipant(db, tx, actor, hid);
    return {
      ...householdClockAt(
        Timestamp.now().toMillis(),
        person.household.get("timezoneIana") as string,
      ),
      actorId: person.actorId,
      role: person.role,
      canManage: person.canManage,
    };
  });
}
