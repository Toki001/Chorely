import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";
import {
  onCall,
  HttpsError,
  type CallableRequest,
} from "firebase-functions/v2/https";
import type { Actor } from "./contracts.js";
import { createHousehold as createHouseholdCommand } from "./households.js";
import * as membership from "./membership.js";
import * as child from "./child_access.js";
import { writeOneOffChore as writeOneOffCommand } from "./chores.js";
initializeApp();
function trustedActor(request: CallableRequest<unknown>): Actor | null {
  const auth = request.auth;
  return auth
    ? {
        uid: auth.uid,
        email:
          typeof auth.token.email === "string" ? auth.token.email : undefined,
        emailVerified: auth.token.email_verified === true,
        provider: String(auth.token.firebase?.sign_in_provider ?? ""),
        scopedChild: auth.token.scopedChild === true,
      }
    : null;
}
function command(
  handler: (
    db: ReturnType<typeof getFirestore>,
    actor: Actor | null,
    input: unknown,
  ) => Promise<unknown>,
) {
  return onCall({ maxInstances: 2 }, (request) =>
    handler(getFirestore(), trustedActor(request), request.data),
  );
}
export const connectionStatus = onCall({ maxInstances: 2 }, (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in first.");
  return { protocolVersion: 1, ready: true };
});
export const createHousehold = command(createHouseholdCommand);
export const writeOneOffChore = command(writeOneOffCommand);
export const issueInvite = command(membership.issueInvite);
export const acceptInvite = command(membership.acceptInvite);
export const revokeInvite = command(membership.revokeInvite);
export const revokeMember = command(membership.revokeMember);
export const addChildProfile = command(child.addChildProfile);
export const issueChildPairing = command(child.issueChildPairing);
export const revokeChildAccess = command(child.revokeChildAccess);
export const redeemChildPairing = onCall({ maxInstances: 2 }, (request) =>
  child.redeemChildPairing(
    getFirestore(),
    getAuth(),
    request.auth?.uid ?? null,
    request.data,
  ),
);
