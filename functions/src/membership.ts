import type { Firestore, Transaction } from "firebase-admin/firestore";
import { Timestamp } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";
import type { Actor } from "./contracts.js";
import { requireAdult } from "./households.js";
import {
  record,
  text,
  identifier,
  commandId,
  hash,
  nonceHash,
  emailHash,
} from "./validation.js";

export async function guardian(
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
    member.get("role") !== "guardian" ||
    account.get("status") === "disabled" ||
    account.get("accountType") === "supervised_device"
  )
    throw new HttpsError("permission-denied", "Guardian access is required.");
  return home;
}

export async function issueInvite(
  db: Firestore,
  actor: Actor | null,
  input: unknown,
) {
  requireAdult(actor);
  const data = record(input);
  const hid = identifier(data.householdId);
  const id = nonceHash(data.nonce);
  const recipientHash = emailHash(data.recipientEmail);
  const role = data.role;
  if (role !== "adult" && role !== "guardian")
    throw new HttpsError(
      "invalid-argument",
      "Choose an adult membership role.",
    );
  const cid = commandId(data.commandId);
  const receipt = db.doc(
    `commands/${hash(JSON.stringify([actor.uid, cid, "issueInvite"]))}`,
  );
  const payloadHash = hash(JSON.stringify([hid, id, recipientHash, role]));
  return db.runTransaction(async (tx) => {
    await guardian(db, tx, actor, hid);
    const prior = await tx.get(receipt);
    const invite = db.doc(`invites/${id}`);
    const existing = await tx.get(invite);
    const rateRef = db.doc(`rateLimits/${actor.uid}`);
    const rate = await tx.get(rateRef);
    const now = Timestamp.now();
    if (prior.exists) {
      if (prior.get("payloadHash") !== payloadHash)
        throw new HttpsError("already-exists", "Request ID already used.");
      if (
        existing.get("status") !== "active" ||
        existing.get("expiresAt").toMillis() <= now.toMillis()
      )
        throw new HttpsError(
          "failed-precondition",
          "Invite is no longer available.",
        );
      return {
        inviteId: id,
        expiresAt: existing.get("expiresAt").toMillis() as number,
      };
    }
    if (existing.exists)
      throw new HttpsError("already-exists", "Use a new one-use code.");
    const day = new Date(now.toMillis()).toISOString().slice(0, 10);
    const count =
      rate.get("inviteDay") === day ? Number(rate.get("inviteCount")) : 0;
    if (count >= 20)
      throw new HttpsError(
        "resource-exhausted",
        "Daily invitation limit reached.",
      );
    const expiresAt = Timestamp.fromMillis(now.toMillis() + 10 * 60_000);
    tx.create(invite, {
      householdId: hid,
      recipientHash,
      role,
      createdBy: actor.uid,
      createdAt: now,
      expiresAt,
      status: "active",
    });
    tx.create(db.doc(`households/${hid}/invitations/${id}`), {
      role,
      createdAt: now,
      expiresAt,
      status: "active",
    });
    tx.set(
      rateRef,
      { inviteDay: day, inviteCount: count + 1 },
      { merge: true },
    );
    tx.create(receipt, { uid: actor.uid, payloadHash, acceptedAt: now });
    tx.create(db.doc(`households/${hid}/activity/${receipt.id}`), {
      action: "invite_created",
      actorId: actor.uid,
      entityId: id,
      serverAt: now,
    });
    return { inviteId: id, expiresAt: expiresAt.toMillis() };
  });
}

export async function acceptInvite(
  db: Firestore,
  actor: Actor | null,
  input: unknown,
) {
  requireAdult(actor);
  const data = record(input);
  const id = nonceHash(data.nonce);
  const nickname = text(data.nickname, "nickname", 40);
  const cid = commandId(data.commandId);
  const receipt = db.doc(
    `commands/${hash(JSON.stringify([actor.uid, cid, "acceptInvite"]))}`,
  );
  const payloadHash = hash(JSON.stringify([id, nickname]));
  return db.runTransaction(async (tx) => {
    const invite = await tx.get(db.doc(`invites/${id}`));
    const prior = await tx.get(receipt);
    const account = await tx.get(db.doc(`users/${actor.uid}`));
    if (
      !invite.exists ||
      !actor.email ||
      invite.get("recipientHash") !== emailHash(actor.email) ||
      account.get("status") === "disabled" ||
      account.get("accountType") === "supervised_device"
    )
      throw new HttpsError(
        "permission-denied",
        "Invite is unavailable for this account.",
      );
    const hid = identifier(invite.get("householdId"));
    const home = await tx.get(db.doc(`households/${hid}`));
    const issuer = await tx.get(
      db.doc(`households/${hid}/members/${invite.get("createdBy")}`),
    );
    const issuerAccount = await tx.get(
      db.doc(`users/${invite.get("createdBy")}`),
    );
    const membership = db.doc(`households/${hid}/members/${actor.uid}`);
    const existing = await tx.get(membership);
    const members = await tx.get(
      db
        .collection(`households/${hid}/members`)
        .where("status", "==", "active"),
    );
    if (
      !home.exists ||
      home.get("archivedAt") != null ||
      issuerAccount.get("status") === "disabled" ||
      issuer.get("status") !== "active" ||
      issuer.get("role") !== "guardian"
    )
      throw new HttpsError("permission-denied", "Invite is unavailable.");
    if (prior.exists) {
      if (prior.get("payloadHash") !== payloadHash)
        throw new HttpsError("already-exists", "Request ID already used.");
      if (existing.get("status") !== "active")
        throw new HttpsError("permission-denied", "Access was removed.");
      return { householdId: hid };
    }
    const now = Timestamp.now();
    if (
      invite.get("status") !== "active" ||
      invite.get("expiresAt").toMillis() <= now.toMillis()
    )
      throw new HttpsError(
        "failed-precondition",
        "Invite expired, was used or was revoked.",
      );
    if (existing.get("status") === "active")
      throw new HttpsError(
        "failed-precondition",
        "You already belong to this household.",
      );
    if (members.size >= 50)
      throw new HttpsError(
        "resource-exhausted",
        "Household member limit reached.",
      );
    const role = invite.get("role") as string;
    tx.set(membership, {
      role,
      status: "active",
      canAssign: role === "guardian",
      actorId: actor.uid,
      joinedAt: now,
    });
    tx.set(db.doc(`households/${hid}/profiles/${actor.uid}`), {
      nickname,
      avatarKey: "home",
      role,
      supervised: false,
      status: "active",
    });
    tx.set(db.doc(`users/${actor.uid}`), { status: "active" }, { merge: true });
    tx.set(db.doc(`users/${actor.uid}/households/${hid}`), {
      householdId: hid,
      name: home.get("name"),
      role,
      joinedAt: now,
    });
    tx.update(invite.ref, {
      status: "consumed",
      consumedBy: actor.uid,
      consumedAt: now,
    });
    tx.update(db.doc(`households/${hid}/invitations/${id}`), {
      status: "consumed",
    });
    tx.create(receipt, {
      uid: actor.uid,
      payloadHash,
      householdId: hid,
      acceptedAt: now,
    });
    tx.create(db.doc(`households/${hid}/activity/${receipt.id}`), {
      action: "member_joined",
      actorId: actor.uid,
      entityId: actor.uid,
      serverAt: now,
    });
    return { householdId: hid };
  });
}

export async function revokeInvite(
  db: Firestore,
  actor: Actor | null,
  input: unknown,
) {
  requireAdult(actor);
  const data = record(input);
  const hid = identifier(data.householdId);
  const id = identifier(data.inviteId);
  return db.runTransaction(async (tx) => {
    await guardian(db, tx, actor, hid);
    const invite = await tx.get(db.doc(`invites/${id}`));
    if (!invite.exists || invite.get("householdId") !== hid)
      throw new HttpsError("not-found", "Invite unavailable.");
    if (invite.get("status") === "consumed")
      throw new HttpsError(
        "failed-precondition",
        "Invite was accepted. Manage the member instead.",
      );
    if (invite.get("status") === "revoked") return { revoked: true };
    const now = Timestamp.now();
    tx.update(invite.ref, { status: "revoked", revokedAt: now });
    tx.update(db.doc(`households/${hid}/invitations/${id}`), {
      status: "revoked",
    });
    tx.create(db.doc(`households/${hid}/activity/invite_revoke_${id}`), {
      action: "invite_revoked",
      actorId: actor.uid,
      entityId: id,
      serverAt: now,
    });
    return { revoked: true };
  });
}

export async function revokeMember(
  db: Firestore,
  actor: Actor | null,
  input: unknown,
) {
  requireAdult(actor);
  const data = record(input);
  const hid = identifier(data.householdId);
  const uid = identifier(data.memberUid);
  return db.runTransaction(async (tx) => {
    await guardian(db, tx, actor, hid);
    const ref = db.doc(`households/${hid}/members/${uid}`);
    const target = await tx.get(ref);
    const profile = await tx.get(db.doc(`households/${hid}/profiles/${uid}`));
    const members = await tx.get(
      db
        .collection(`households/${hid}/members`)
        .where("status", "==", "active"),
    );
    if (!target.exists)
      throw new HttpsError("not-found", "Member unavailable.");
    if (target.get("role") === "child")
      throw new HttpsError(
        "failed-precondition",
        "Manage supervised device access instead.",
      );
    if (target.get("status") === "revoked") return { revoked: true };
    if (
      target.get("role") === "guardian" &&
      members.docs.filter((d) => d.get("role") === "guardian").length <= 1
    )
      throw new HttpsError(
        "failed-precondition",
        "Keep at least one guardian in this household.",
      );
    const now = Timestamp.now();
    tx.update(ref, { status: "revoked", revokedAt: now, canAssign: false });
    tx.delete(db.doc(`users/${uid}/households/${hid}`));
    if (profile.exists) tx.update(profile.ref, { status: "revoked" });
    tx.create(
      db.doc(
        `households/${hid}/activity/revoke_${uid}_${target.get("joinedAt").toMillis()}`,
      ),
      {
        action: "member_revoked",
        actorId: actor.uid,
        entityId: uid,
        serverAt: now,
      },
    );
    return { revoked: true };
  });
}
