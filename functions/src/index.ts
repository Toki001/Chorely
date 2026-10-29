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
import * as recurrence from "./recurrence_service.js";
import { getHouseholdClock as clockCommand } from "./household_clock.js";
import * as notifications from "./notification_preferences.js";
import { actOnOccurrence as occurrenceAction } from "./completion.js";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { runRecurrenceWorker } from "./recurrence_worker.js";
import { runNotificationWorker } from "./notification_worker.js";
import { openNotification as openNotificationCommand } from "./notification_open.js";
import { getLocalNotificationPlan as localPlanCommand } from "./notification_local_plan.js";
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
export const previewRecurrence = command(recurrence.previewRule);
export const saveRecurrence = command(recurrence.saveRule);
export const refreshRecurrence = command(recurrence.refreshRule);
export const actOnOccurrence = command(occurrenceAction);
export const getHouseholdClock = command(clockCommand);
export const openNotification = command(openNotificationCommand);
export const getLocalNotificationPlan = command(localPlanCommand);
export const getNotificationPreferences = command(
  notifications.getNotificationPreferences,
);
export const saveNotificationPreferences = command(
  notifications.saveNotificationPreferences,
);
// Source only. No provider sends or live scheduler creation in the demo setup.
export const notificationInboxWorker = onSchedule(
  {
    schedule: "every 1 minutes",
    timeZone: "Etc/UTC",
    maxInstances: 1,
    timeoutSeconds: 120,
    retryCount: 0,
  },
  async () => {
    await runNotificationWorker(getFirestore());
  },
);
// Source only: deploying this billed scheduler remains an explicit release gate.
export const recurringHorizon = onSchedule(
  {
    schedule: "every 6 hours",
    timeZone: "Etc/UTC",
    maxInstances: 1,
    timeoutSeconds: 300,
    retryCount: 0,
  },
  async () => {
    await runRecurrenceWorker(getFirestore());
  },
);
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
