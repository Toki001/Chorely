import "./seed_family_fixture.mjs";
import { initializeApp, deleteApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { randomUUID } from "node:crypto";
import { addChildProfile } from "../functions/lib/child_access.js";
import { writeOneOffChore } from "../functions/lib/chores.js";
import { householdDate } from "../functions/lib/recurrence_engine.js";
import { runNotificationWorker } from "../functions/lib/notification_worker.js";
const app = initializeApp({ projectId: "demo-chorely" }),
  db = getFirestore(app);
const guardian = {
  uid: "native-fictional-guardian",
  emailVerified: true,
  provider: "password",
  scopedChild: false,
};
try {
  const home = (await db.collection("households").get()).docs[0];
  const child = await addChildProfile(db, guardian, {
    householdId: home.id,
    nickname: "Fictional child",
    commandId: randomUUID(),
  });
  for (const [title, owner, reviewMode] of [
    ["Cook rice", child.profileId, "guardian"],
    ["Feed pets", guardian.uid, "none"],
  ]) {
    await writeOneOffChore(db, guardian, {
      householdId: home.id,
      commandId: randomUUID(),
      action: "create",
      title,
      category: "household",
      description: "Fictional native test",
      steps: [],
      room: "",
      assignedActorIds: [owner],
      completionPolicy: "any_one_completes",
      reviewMode,
      schedule: {
        kind: "none",
        date: householdDate(Date.now(), "Asia/Manila"),
      },
    });
  }
  await runNotificationWorker(db);
  console.log(
    "Created fictional notification fixtures and private in-app assignment updates.",
  );
} finally {
  await deleteApp(app);
}
