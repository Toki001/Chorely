import { initializeApp } from "firebase-admin/app";
import { onCall, HttpsError } from "firebase-functions/v2/https";

initializeApp();

export const connectionStatus = onCall({ maxInstances: 2 }, (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in first.");
  return { protocolVersion: 1, ready: true };
});
