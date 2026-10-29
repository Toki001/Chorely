import { enqueueHouseholdNotificationRefresh } from "./notification_outbox.js";
import type { Firestore } from "firebase-admin/firestore";
import { Timestamp } from "firebase-admin/firestore";
import type { Auth } from "firebase-admin/auth";
import { HttpsError } from "firebase-functions/v2/https";
import type { Actor } from "./contracts.js";
import { requireAdult } from "./households.js";
import { guardian } from "./membership.js";
import {
  record,
  text,
  identifier,
  commandId,
  hash,
  nonceHash,
} from "./validation.js";

export async function addChildProfile(
  db: Firestore,
  actor: Actor | null,
  input: unknown,
) {
  requireAdult(actor);
  const data = record(input);
  const hid = identifier(data.householdId);
  const nickname = text(data.nickname, "nickname", 40);
  const cid = commandId(data.commandId);
  const id = `child_${hash(JSON.stringify([actor.uid, cid]))}`;
  const receipt = db.doc(
    `commands/${hash(JSON.stringify([actor.uid, cid, "addChild"]))}`,
  );
  const payloadHash = hash(JSON.stringify([hid, nickname]));
  return db.runTransaction(async (tx) => {
    await guardian(db, tx, actor, hid);
    const prior = await tx.get(receipt);
    const profiles = await tx.get(
      db.collection(`households/${hid}/profiles`).where("role", "==", "child"),
    );
    const profile = db.doc(`households/${hid}/profiles/${id}`);
    const existing = await tx.get(profile);
    if (prior.exists) {
      if (prior.get("payloadHash") !== payloadHash)
        throw new HttpsError("already-exists", "Request ID already used.");
      if (existing.get("status") !== "active")
        throw new HttpsError("permission-denied", "Profile unavailable.");
      return { profileId: id };
    }
    if (profiles.size >= 20)
      throw new HttpsError(
        "resource-exhausted",
        "Child profile limit reached.",
      );
    const now = Timestamp.now();
    tx.create(profile, {
      nickname,
      avatarKey: "home",
      role: "child",
      supervised: true,
      status: "active",
    });
    tx.create(receipt, { uid: actor.uid, payloadHash, acceptedAt: now });
    tx.create(db.doc(`households/${hid}/activity/${receipt.id}`), {
      action: "child_profile_added",
      actorId: actor.uid,
      entityId: id,
      serverAt: now,
    });
    return { profileId: id };
  });
}

export async function issueChildPairing(
  db: Firestore,
  actor: Actor | null,
  input: unknown,
) {
  requireAdult(actor);
  const data = record(input);
  const hid = identifier(data.householdId);
  const profileId = identifier(data.profileId);
  const id = nonceHash(data.nonce);
  return db.runTransaction(async (tx) => {
    await guardian(db, tx, actor, hid);
    const profile = await tx.get(
      db.doc(`households/${hid}/profiles/${profileId}`),
    );
    const pairing = db.doc(`pairings/${id}`);
    const existing = await tx.get(pairing);
    const rateRef = db.doc(`rateLimits/${actor.uid}`);
    const rate = await tx.get(rateRef);
    const now = Timestamp.now();
    if (profile.get("role") !== "child" || profile.get("status") !== "active")
      throw new HttpsError(
        "invalid-argument",
        "Choose an active child profile.",
      );
    if (existing.exists) {
      if (
        existing.get("householdId") !== hid ||
        existing.get("profileId") !== profileId ||
        existing.get("createdBy") !== actor.uid ||
        existing.get("status") !== "active" ||
        existing.get("expiresAt").toMillis() <= now.toMillis()
      )
        throw new HttpsError(
          "failed-precondition",
          "Pairing code unavailable.",
        );
      return {
        pairingId: id,
        expiresAt: existing.get("expiresAt").toMillis() as number,
      };
    }
    const day = new Date(now.toMillis()).toISOString().slice(0, 10);
    const count =
      rate.get("pairDay") === day ? Number(rate.get("pairCount") ?? 0) : 0;
    if (count >= 20)
      throw new HttpsError(
        "resource-exhausted",
        "Daily pairing limit reached.",
      );
    const expiresAt = Timestamp.fromMillis(now.toMillis() + 10 * 60_000);
    tx.create(pairing, {
      householdId: hid,
      profileId,
      createdBy: actor.uid,
      status: "active",
      createdAt: now,
      expiresAt,
    });
    tx.create(db.doc(`households/${hid}/pairings/${id}`), {
      profileId,
      status: "active",
      createdAt: now,
      expiresAt,
    });
    tx.set(rateRef, { pairDay: day, pairCount: count + 1 }, { merge: true });
    tx.create(db.doc(`households/${hid}/activity/pairing_${id}`), {
      action: "child_pairing_approved",
      actorId: actor.uid,
      entityId: profileId,
      serverAt: now,
    });
    return { pairingId: id, expiresAt: expiresAt.toMillis() };
  });
}

export async function redeemChildPairing(
  db: Firestore,
  auth: Auth,
  callerUid: string | null,
  input: unknown,
) {
  if (callerUid)
    throw new HttpsError(
      "failed-precondition",
      "Sign out before setting up a supervised device.",
    );
  const data = record(input);
  const id = nonceHash(data.nonce);
  const proofHash = nonceHash(data.deviceSecret);
  const uid = `device_${hash(JSON.stringify([id, proofHash]))}`;
  const result = await db.runTransaction(async (tx) => {
    const pairing = await tx.get(db.doc(`pairings/${id}`));
    const now = Timestamp.now();
    if (
      !pairing.exists ||
      pairing.get("expiresAt").toMillis() <= now.toMillis()
    )
      throw new HttpsError(
        "permission-denied",
        "Pairing code expired or unavailable.",
      );
    const hid = identifier(pairing.get("householdId"));
    const profileId = identifier(pairing.get("profileId"));
    const home = await tx.get(db.doc(`households/${hid}`));
    const issuer = await tx.get(
      db.doc(`households/${hid}/members/${pairing.get("createdBy")}`),
    );
    const issuerAccount = await tx.get(
      db.doc(`users/${pairing.get("createdBy")}`),
    );
    const profile = await tx.get(
      db.doc(`households/${hid}/profiles/${profileId}`),
    );
    const memberRef = db.doc(`households/${hid}/members/${uid}`);
    const existing = await tx.get(memberRef);
    const members = await tx.get(
      db
        .collection(`households/${hid}/members`)
        .where("status", "==", "active"),
    );
    if (
      !home.exists ||
      home.get("archivedAt") != null ||
      issuerAccount.get("status") === "disabled" ||
      issuer.get("role") !== "guardian" ||
      issuer.get("status") !== "active" ||
      profile.get("role") !== "child" ||
      profile.get("status") !== "active"
    )
      throw new HttpsError(
        "permission-denied",
        "Pairing approval is unavailable.",
      );
    if (pairing.get("status") === "consumed") {
      if (
        pairing.get("deviceProofHash") !== proofHash ||
        existing.get("status") !== "active"
      )
        throw new HttpsError(
          "permission-denied",
          "Pairing code was already used or revoked.",
        );
      return { uid, householdId: hid, profileId };
    }
    if (pairing.get("status") !== "active")
      throw new HttpsError("permission-denied", "Pairing code was revoked.");
    if (members.size >= 50)
      throw new HttpsError(
        "resource-exhausted",
        "Household member limit reached.",
      );
    tx.create(memberRef, {
      actorId: profileId,
      deviceId: uid,
      role: "child",
      status: "active",
      canAssign: false,
      joinedAt: now,
    });
    tx.create(db.doc(`pairedDevices/${uid}`), {
      householdId: hid,
      actorId: profileId,
      status: "active",
      issuedAt: now,
    });
    tx.create(db.doc(`users/${uid}`), {
      status: "active",
      accountType: "supervised_device",
    });
    tx.create(db.doc(`households/${hid}/devices/${uid}`), {
      profileId,
      status: "active",
      issuedAt: now,
    });
    tx.update(pairing.ref, {
      status: "consumed",
      deviceProofHash: proofHash,
      consumedAt: now,
    });
    tx.update(db.doc(`households/${hid}/pairings/${id}`), {
      status: "consumed",
    });
    tx.create(db.doc(`households/${hid}/activity/device_${uid}`), {
      action: "child_device_paired",
      actorId: uid,
      entityId: profileId,
      serverAt: now,
    });
    enqueueHouseholdNotificationRefresh(db, tx, hid, now);
    return { uid, householdId: hid, profileId };
  });
  // Token minting follows the atomic claim. Same device proof can retry a lost
  // response until expiry; another device cannot claim the consumed approval.
  const claims = {
    scopedChild: true,
    householdId: result.householdId,
    actorId: result.profileId,
  };
  // Persist scope across provider linking/password sign-in. Custom-token inline
  // claims alone would disappear when a child links a different provider.
  try {
    await auth.getUser(result.uid);
  } catch (error) {
    if ((error as { code?: string }).code !== "auth/user-not-found")
      throw error;
    try {
      await auth.createUser({ uid: result.uid });
    } catch (createError) {
      if ((createError as { code?: string }).code !== "auth/uid-already-exists")
        throw createError;
    }
  }
  await auth.setCustomUserClaims(result.uid, claims);
  const customToken = await auth.createCustomToken(result.uid, claims);
  return { customToken };
}

export async function revokeChildAccess(
  db: Firestore,
  actor: Actor | null,
  input: unknown,
) {
  requireAdult(actor);
  const data = record(input);
  const hid = identifier(data.householdId);
  const target = identifier(data.targetId);
  const kind = data.kind;
  if (kind !== "device" && kind !== "pairing")
    throw new HttpsError("invalid-argument", "Invalid access type.");
  return db.runTransaction(async (tx) => {
    await guardian(db, tx, actor, hid);
    const ref = db.doc(
      `${kind === "device" ? "pairedDevices" : "pairings"}/${target}`,
    );
    const item = await tx.get(ref);
    if (!item.exists || item.get("householdId") !== hid)
      throw new HttpsError("not-found", "Access unavailable.");
    if (item.get("status") === "revoked") return { revoked: true };
    if (kind === "pairing" && item.get("status") === "consumed")
      throw new HttpsError(
        "failed-precondition",
        "Revoke the paired device instead.",
      );
    const now = Timestamp.now();
    tx.update(ref, { status: "revoked", revokedAt: now });
    if (kind === "device") {
      tx.update(db.doc(`households/${hid}/members/${target}`), {
        status: "revoked",
        revokedAt: now,
      });
      tx.update(db.doc(`households/${hid}/devices/${target}`), {
        status: "revoked",
        revokedAt: now,
      });
    } else {
      tx.update(db.doc(`households/${hid}/pairings/${target}`), {
        status: "revoked",
      });
    }
    tx.create(db.doc(`households/${hid}/activity/${kind}_revoke_${target}`), {
      action: `${kind}_revoked`,
      actorId: actor.uid,
      entityId: target,
      serverAt: now,
    });
    enqueueHouseholdNotificationRefresh(db, tx, hid, now);
    return { revoked: true };
  });
}
