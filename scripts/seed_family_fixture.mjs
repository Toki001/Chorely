// This import enforces demo project and loopback Auth/Firestore endpoints.
import "./seed_native_fixture.mjs";
import { initializeApp, deleteApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { randomUUID } from "node:crypto";
import { createHousehold } from "../functions/lib/households.js";
const app = initializeApp({ projectId: "demo-chorely" });
await createHousehold(
  getFirestore(app),
  {
    uid: "native-fictional-guardian",
    email: "native-guardian@example.test",
    emailVerified: true,
    provider: "password",
    scopedChild: false,
  },
  {
    commandId: randomUUID(),
    name: "Native fictional home",
    nickname: "Alex",
    timezone: "Asia/Manila",
  },
);
await deleteApp(app);
console.log("Created fictional native household in local Firestore emulator.");
