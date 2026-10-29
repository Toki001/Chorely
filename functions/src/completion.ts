import {
  Timestamp,
  type Firestore,
  type Transaction,
} from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";
import { error as logError } from "firebase-functions/logger";
import type { Actor } from "./contracts.js";
import { requireAdult } from "./households.js";
import { identifier, commandId, record, hash } from "./validation.js";

type Action =
  "complete" | "undo" | "help" | "approve" | "redo" | "resolve_help";
type Contribution = {
  acceptedAt: Timestamp;
  completionRevision: number;
  priorStatus: string;
};
type Help = {
  requestId: string;
  status: "open" | "resolved";
  requestedAt: Timestamp;
};
function note(value: unknown, required: boolean): string {
  if (
    typeof value !== "string" ||
    value.length > 500 ||
    /[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/.test(value)
  )
    throw new HttpsError(
      "invalid-argument",
      "Use a note of at most 500 characters.",
    );
  const result = value.replace(/\r\n?/g, "\n").trim();
  if (required && !result)
    throw new HttpsError(
      "invalid-argument",
      "Explain what needs another look.",
    );
  return result;
}
async function participant(
  db: Firestore,
  tx: Transaction,
  actor: Actor,
  hid: string,
) {
  const home = await tx.get(db.doc(`households/${hid}`));
  const member = await tx.get(db.doc(`households/${hid}/members/${actor.uid}`));
  const account = await tx.get(db.doc(`users/${actor.uid}`));
  const role = member.get("role") as string;
  if (
    !home.exists ||
    home.get("archivedAt") != null ||
    member.get("status") !== "active" ||
    !["guardian", "adult", "child"].includes(role) ||
    account.get("status") === "disabled"
  )
    throw new HttpsError("permission-denied", "This household is unavailable.");
  let actorId: string;
  if (role === "child") {
    if (
      account.get("accountType") !== "supervised_device" ||
      typeof member.get("actorId") !== "string"
    )
      throw new HttpsError(
        "permission-denied",
        "Supervised access is unavailable.",
      );
    actorId = identifier(member.get("actorId"));
  } else {
    requireAdult(actor);
    if (account.get("accountType") === "supervised_device")
      throw new HttpsError(
        "permission-denied",
        "A supervised account cannot use adult permissions.",
      );
    actorId = actor.uid;
  }
  const profile = await tx.get(db.doc(`households/${hid}/profiles/${actorId}`));
  if (
    !profile.exists ||
    profile.get("status") === "revoked" ||
    (role === "child" &&
      (profile.get("status") !== "active" || profile.get("role") !== "child"))
  )
    throw new HttpsError("permission-denied", "This profile is unavailable.");
  return {
    actorId,
    role,
    canManage:
      role === "guardian" ||
      (role === "adult" && member.get("canAssign") === true),
  };
}
function conflict(reason: string, version: number, status: string): never {
  throw new HttpsError(
    "aborted",
    "This chore changed. Read the latest state before trying again.",
    { reason, version, status },
  );
}
export async function actOnOccurrence(
  db: Firestore,
  actor: Actor | null,
  input: unknown,
) {
  if (!actor) throw new HttpsError("unauthenticated", "Sign in first.");
  const data = record(input),
    hid = identifier(data.householdId),
    oid = identifier(data.occurrenceId),
    cid = commandId(data.commandId);
  const action = data.action as Action;
  if (
    !["complete", "undo", "help", "approve", "redo", "resolve_help"].includes(
      action,
    ) ||
    !Number.isSafeInteger(data.baseVersion) ||
    Number(data.baseVersion) < 1
  )
    throw new HttpsError(
      "invalid-argument",
      "Choose an action and current version.",
    );
  const reason = note(data.note ?? "", action === "redo");
  const target =
    action === "resolve_help" ? identifier(data.targetActorId) : null;
  const payloadHash = hash(
    JSON.stringify([hid, oid, action, data.baseVersion, reason, target]),
  );
  const receipt = db.doc(
    `commands/${hash(JSON.stringify([actor.uid, cid, "occurrence"]))}`,
  );
  try {
    return await db.runTransaction(async (tx) => {
      const person = await participant(db, tx, actor, hid);
      const occurrence = db.doc(`households/${hid}/occurrences/${oid}`),
        snapshot = await tx.get(occurrence);
      const assigned = (snapshot.get("assignedActorIds") ?? []) as string[];
      const contributions = Object.assign(
        Object.create(null),
        snapshot.get("contributions") ?? {},
      ) as Record<string, Contribution>;
      const help = Object.assign(
        Object.create(null),
        snapshot.get("helpRequests") ?? {},
      ) as Record<string, Help>;
      if (action === "approve" || action === "redo") {
        if (
          person.role !== "guardian" ||
          assigned.includes(person.actorId) ||
          Object.hasOwn(contributions, person.actorId)
        )
          throw new HttpsError(
            "permission-denied",
            "A separate guardian must review this chore.",
            { reason: "self_review" },
          );
      } else if (action === "resolve_help") {
        if (!person.canManage)
          throw new HttpsError(
            "permission-denied",
            "Household chore management permission required.",
          );
      } else if (!snapshot.exists || !assigned.includes(person.actorId))
        throw new HttpsError(
          "permission-denied",
          "This chore is unavailable to this profile.",
        );
      if (!snapshot.exists)
        throw new HttpsError("not-found", "This chore is unavailable.");
      const accepted = await tx.get(receipt);
      if (accepted.exists) {
        if (accepted.get("payloadHash") !== payloadHash)
          throw new HttpsError("already-exists", "Request ID already used.");
        return accepted.get("result") as {
          accepted: true;
          version: number;
          status: string;
        };
      }
      const version = Number(snapshot.get("version")),
        status = snapshot.get("status") as string;
      const revision = Number(snapshot.get("completionRevision") ?? 0);
      if (
        action === "complete" &&
        (Object.hasOwn(contributions, person.actorId) ||
          ["completed", "approved", "pending_review"].includes(status))
      )
        conflict("already_done", version, status);
      if (version !== data.baseVersion)
        conflict("version_conflict", version, status);
      const now = Timestamp.now();
      const patch: Record<string, unknown> = {
        version: version + 1,
        updatedAt: now,
      };
      let nextStatus = status;
      let auditAction: string = `occurrence_${action}`;
      let helpRef: ReturnType<Firestore["doc"]> | null = null;
      let helpPatch: Record<string, unknown> | null = null;
      if (action === "complete") {
        if (
          !["scheduled", "needs_redo"].includes(status) ||
          assigned.length === 0
        )
          throw new HttpsError(
            "failed-precondition",
            "This occurrence cannot be completed.",
            { reason: "occurrence_unavailable" },
          );
        const policy = snapshot.get("completionPolicy"),
          review = snapshot.get("reviewMode");
        if (
          !["any_one_completes", "all_members_complete"].includes(policy) ||
          !["none", "guardian"].includes(review) ||
          Object.keys(contributions).some((id) => !assigned.includes(id))
        )
          throw new HttpsError(
            "failed-precondition",
            "This chore’s completion policy needs a guardian’s attention.",
          );
        contributions[person.actorId] = {
          acceptedAt: now,
          completionRevision: revision + 1,
          priorStatus: status,
        };
        const quorum =
          policy === "any_one_completes" ||
          assigned.every((id) => Object.hasOwn(contributions, id));
        nextStatus = quorum
          ? review === "guardian"
            ? "pending_review"
            : "completed"
          : "scheduled";
        Object.assign(patch, {
          contributions,
          completionRevision: revision + 1,
          status: nextStatus,
          completedAt: quorum ? now : null,
          approvedAt: null,
          approvedBy: null,
        });
      } else if (action === "undo") {
        const own = contributions[person.actorId];
        if (
          !own ||
          !["scheduled", "completed", "pending_review"].includes(status) ||
          own.completionRevision !== revision ||
          !(own.acceptedAt instanceof Timestamp) ||
          now.toMillis() < own.acceptedAt.toMillis() ||
          now.toMillis() - own.acceptedAt.toMillis() > 300_000
        )
          throw new HttpsError(
            "failed-precondition",
            "Undo is no longer available. It lasts five minutes and ends after another completion or review.",
            { reason: "undo_unavailable" },
          );
        delete contributions[person.actorId];
        nextStatus =
          Object.keys(contributions).length === 0 &&
          own.priorStatus === "needs_redo"
            ? "needs_redo"
            : "scheduled";
        Object.assign(patch, {
          contributions,
          completionRevision: revision + 1,
          status: nextStatus,
          completedAt: null,
          approvedAt: null,
          approvedBy: null,
        });
      } else if (action === "approve" || action === "redo") {
        if (
          status !== "pending_review" ||
          snapshot.get("reviewMode") !== "guardian" ||
          Object.keys(contributions).length === 0 ||
          Object.keys(contributions).some((id) => !assigned.includes(id)) ||
          (snapshot.get("completionPolicy") === "all_members_complete" &&
            !assigned.every((id) => Object.hasOwn(contributions, id)))
        )
          throw new HttpsError(
            "failed-precondition",
            "This chore is not ready for review.",
          );
        nextStatus = action === "approve" ? "approved" : "needs_redo";
        Object.assign(patch, {
          status: nextStatus,
          completionRevision: revision + 1,
          reviewedAt: now,
          reviewedBy: person.actorId,
          reviewNote: reason,
        });
        if (action === "approve")
          Object.assign(patch, { approvedAt: now, approvedBy: person.actorId });
        else
          Object.assign(patch, {
            contributions: {},
            completedAt: null,
            approvedAt: null,
            approvedBy: null,
          });
      } else if (action === "help") {
        if (
          !["scheduled", "needs_redo"].includes(status) ||
          Object.hasOwn(contributions, person.actorId)
        )
          throw new HttpsError(
            "failed-precondition",
            "Help can be requested while your part still needs doing.",
          );
        if (help[person.actorId]?.status === "open")
          conflict("help_already_requested", version, status);
        helpRef = db.doc(`households/${hid}/helpRequests/${receipt.id}`);
        help[person.actorId] = {
          requestId: receipt.id,
          status: "open",
          requestedAt: now,
        };
        patch.helpRequests = help;
        helpPatch = {
          actorId: person.actorId,
          occurrenceId: oid,
          note: reason,
          status: "open",
          requestedAt: now,
          version: 1,
        };
      } else {
        const request = help[target!];
        if (!request || request.status !== "open")
          throw new HttpsError(
            "failed-precondition",
            "This help request is no longer open.",
          );
        helpRef = db.doc(
          `households/${hid}/helpRequests/${identifier(request.requestId)}`,
        );
        const privateRequest = await tx.get(helpRef);
        if (
          !privateRequest.exists ||
          privateRequest.get("actorId") !== target ||
          privateRequest.get("occurrenceId") !== oid ||
          privateRequest.get("status") !== "open"
        )
          throw new HttpsError(
            "failed-precondition",
            "This help request is unavailable.",
          );
        help[target!] = { ...request, status: "resolved" };
        patch.helpRequests = help;
        helpPatch = {
          status: "resolved",
          resolvedAt: now,
          resolvedBy: person.actorId,
          responseNote: reason,
          version: Number(privateRequest.get("version")) + 1,
        };
        auditAction = "occurrence_help_resolved";
      }
      const rateRef = db.doc(
          `rateLimits/${hash(JSON.stringify([hid, person.actorId, "occurrence"]))}`,
        ),
        rate = await tx.get(rateRef);
      const day = new Date(now.toMillis()).toISOString().slice(0, 10);
      const count =
        rate.get("day") === day ? Number(rate.get("count") ?? 0) : 0;
      if (count >= 1000)
        throw new HttpsError(
          "resource-exhausted",
          "Daily chore action limit reached.",
        );
      tx.update(occurrence, patch);
      if (helpRef && helpPatch) {
        if (action === "help") tx.create(helpRef, helpPatch);
        else tx.update(helpRef, helpPatch);
      }
      const result = {
        accepted: true as const,
        version: version + 1,
        status: nextStatus,
      };
      tx.create(receipt, {
        uid: actor.uid,
        payloadHash,
        result,
        acceptedAt: now,
      });
      tx.set(rateRef, { day, count: count + 1 });
      tx.create(db.doc(`households/${hid}/activity/${receipt.id}`), {
        action: auditAction,
        actorId: person.actorId,
        actorType: "member",
        entityId: oid,
        fromVersion: version,
        toVersion: version + 1,
        fromStatus: status,
        toStatus: nextStatus,
        fromContributors: Object.keys(
          snapshot.get("contributions") ?? {},
        ).sort(),
        toContributors: Object.keys(
          patch.contributions ?? contributions,
        ).sort(),
        targetActorId: target,
        reviewNote: action === "redo" || action === "approve" ? reason : null,
        serverAt: now,
      });
      return result;
    });
  } catch (error) {
    if (
      error instanceof HttpsError &&
      error.code === "permission-denied" &&
      (error.details as { reason?: string } | undefined)?.reason ===
        "self_review"
    ) {
      try {
        await db
          .doc(
            `securityEvents/${hash(JSON.stringify([actor.uid, cid, "review-denial"]))}`,
          )
          .create({
            uid: actor.uid,
            householdId: hid,
            occurrenceId: oid,
            action,
            code: "self_review",
            serverAt: Timestamp.now(),
          });
      } catch (auditError) {
        if ((auditError as { code?: number }).code !== 6)
          logError("Review denial audit unavailable");
      }
    }
    throw error;
  }
}
