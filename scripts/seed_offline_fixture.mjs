import "./seed_notification_fixture.mjs";
import { initializeApp, deleteApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { randomUUID } from "node:crypto";
import { writeOneOffChore } from "../functions/lib/chores.js";
import { householdDate } from "../functions/lib/recurrence_engine.js";
const app = initializeApp({ projectId: "demo-chorely" }),
  db = getFirestore(app);
try {
  const home = (await db.collection("households").get()).docs[0];
  await writeOneOffChore(
    db,
    {
      uid: "native-fictional-guardian",
      emailVerified: true,
      provider: "password",
      scopedChild: false,
    },
    {
      householdId: home.id,
      commandId: randomUUID(),
      action: "create",
      title: "Sweep floor",
      category: "household",
      description: "Fictional offline fixture",
      steps: [],
      room: "",
      assignedActorIds: ["native-fictional-guardian"],
      completionPolicy: "any_one_completes",
      reviewMode: "none",
      schedule: {
        kind: "none",
        date: householdDate(Date.now(), "Asia/Manila"),
      },
    },
  );
  console.log("Created fictional offline recovery fixture.");
} finally {
  await deleteApp(app);
}
