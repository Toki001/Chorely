import { createHash } from "node:crypto";
import type { Firestore } from "firebase-admin/firestore";
import { Timestamp } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";
import type { Actor } from "./contracts.js";

export function requireAdult(actor: Actor | null): asserts actor is Actor {
  if (!actor) throw new HttpsError("unauthenticated", "Sign in first.");
  if (
    !actor.emailVerified ||
    actor.scopedChild ||
    !["password", "google.com", "apple.com"].includes(actor.provider)
  ) {
    throw new HttpsError(
      "permission-denied",
      "A verified adult account is required.",
    );
  }
}

function boundedText(value: unknown, field: string, max: number): string {
  if (
    typeof value !== "string" ||
    !value.trim() ||
    value.trim().length > max ||
    /[\u0000-\u001f\u007f]/.test(value)
  ) {
    throw new HttpsError("invalid-argument", `Invalid ${field}.`);
  }
  return value.trim();
}

export async function createHousehold(
  db: Firestore,
  actor: Actor | null,
  input: unknown,
) {
  requireAdult(actor);
  if (!input || typeof input !== "object")
    throw new HttpsError("invalid-argument", "Invalid request.");
  const data = input as Record<string, unknown>;
  const name = boundedText(data.name, "household name", 80);
  const nickname = boundedText(data.nickname, "nickname", 40);
  const timezone = boundedText(data.timezone, "timezone", 100);
  try {
    new Intl.DateTimeFormat("en", { timeZone: timezone }).format();
  } catch {
    throw new HttpsError("invalid-argument", "Choose a valid IANA timezone.");
  }
  const commandId = boundedText(data.commandId, "command ID", 36);
  if (
    !/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
      commandId,
    )
  )
    throw new HttpsError("invalid-argument", "Invalid command ID.");
  const digest = (s: string) => createHash("sha256").update(s).digest("hex");
  const hid = digest(JSON.stringify([actor.uid, commandId]));
  const payloadHash = digest(JSON.stringify({ name, nickname, timezone }));
  const receipt = db.doc(`commands/${hid}`);
  const user = db.doc(`users/${actor.uid}`);
  const home = db.doc(`households/${hid}`);
  return db.runTransaction(async (tx) => {
    const previous = await tx.get(receipt);
    const account = await tx.get(user);
    if (
      account.data()?.status === "disabled" ||
      account.data()?.accountType === "supervised_device"
    )
      throw new HttpsError("permission-denied", "Account is unavailable.");
    if (previous.exists) {
      if (previous.data()?.payloadHash !== payloadHash)
        throw new HttpsError(
          "already-exists",
          "This request ID was already used.",
        );
      const member = await tx.get(home.collection("members").doc(actor.uid));
      if (member.data()?.status !== "active")
        throw new HttpsError(
          "permission-denied",
          "Household access is unavailable.",
        );
      return { householdId: hid };
    }
    const created = Number(account.data()?.householdsCreated ?? 0);
    if (created >= 5)
      throw new HttpsError(
        "resource-exhausted",
        "Household creation limit reached.",
      );
    const now = Timestamp.now();
    tx.create(home, {
      name,
      timezoneIana: timezone,
      ownerUid: actor.uid,
      createdAt: now,
      archivedAt: null,
      version: 1,
    });
    tx.create(home.collection("members").doc(actor.uid), {
      role: "guardian",
      status: "active",
      canAssign: true,
      joinedAt: now,
    });
    tx.create(home.collection("profiles").doc(actor.uid), {
      nickname,
      avatarKey: "home",
      role: "guardian",
      supervised: false,
    });
    tx.set(
      user,
      { status: "active", householdsCreated: created + 1 },
      { merge: true },
    );
    tx.create(user.collection("households").doc(hid), {
      householdId: hid,
      name,
      role: "guardian",
      joinedAt: now,
    });
    tx.create(home.collection("activity").doc(hid), {
      actorId: actor.uid,
      action: "household_created",
      entityId: hid,
      serverAt: now,
    });
    tx.create(receipt, {
      uid: actor.uid,
      payloadHash,
      householdId: hid,
      acceptedAt: now,
    });
    return { householdId: hid };
  });
}
