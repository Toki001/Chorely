// seed_family_fixture enforces demo project and both loopback emulator endpoints.
import "./seed_family_fixture.mjs";
import { initializeApp, deleteApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { randomUUID } from "node:crypto";
import { addChildProfile } from "../functions/lib/child_access.js";
const app = initializeApp({ projectId: "demo-chorely" });
const db = getFirestore(app);
const homes = await db.collection("households").get();
for (const nickname of ["Fictional Sam", "Fictional Lee"])
  await addChildProfile(
    db,
    {
      uid: "native-fictional-guardian",
      emailVerified: true,
      provider: "password",
      scopedChild: false,
    },
    { householdId: homes.docs[0].id, commandId: randomUUID(), nickname },
  );
await deleteApp(app);
console.log("Created two fictional rotation profiles in local Firestore.");
