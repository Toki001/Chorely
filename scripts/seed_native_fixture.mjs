// Test-only identity. Refuse to contact any live service.
import assert from "node:assert/strict";
import { initializeApp, deleteApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
assert.equal(process.env.GCLOUD_PROJECT, "demo-chorely");
assert.equal(process.env.FIREBASE_AUTH_EMULATOR_HOST, "127.0.0.1:9099");
assert.equal(process.env.FIRESTORE_EMULATOR_HOST, "127.0.0.1:8080");
const app = initializeApp({ projectId: "demo-chorely" });
await getAuth(app).createUser({
  uid: "native-fictional-guardian",
  email: "native-guardian@example.test",
  emailVerified: true,
  password: "fictional-only-password-42",
});
await deleteApp(app);
console.log("Created fictional native-test guardian in local Auth emulator.");
