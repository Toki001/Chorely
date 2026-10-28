import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { createHousehold as createHouseholdCommand } from "./households.js";

initializeApp();

export const connectionStatus = onCall({ maxInstances: 2 }, (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in first.");
  return { protocolVersion: 1, ready: true };
});

export const createHousehold = onCall({ maxInstances: 2 }, (request) => {
  const auth = request.auth;
  return createHouseholdCommand(
    getFirestore(),
    auth
      ? {
          uid: auth.uid,
          emailVerified: auth.token.email_verified === true,
          provider: String(auth.token.firebase?.sign_in_provider ?? ""),
          scopedChild: auth.token.scopedChild === true,
        }
      : null,
    request.data,
  );
});
