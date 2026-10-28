import { after, before, beforeEach, test } from "node:test";
import { readFile } from "node:fs/promises";
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";
import {
  doc,
  getDoc,
  setDoc,
  getDocs,
  collection,
  query,
  where,
} from "firebase/firestore";

let env;
before(async () => {
  if (!process.env.FIRESTORE_EMULATOR_HOST)
    throw new Error("Run with Firebase emulator; never production");
  env = await initializeTestEnvironment({
    projectId: "demo-chorely",
    firestore: { rules: await readFile("firestore.rules", "utf8") },
  });
});
after(async () => {
  await env?.cleanup();
});
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    for (const hid of ["homeA", "homeB"]) {
      await setDoc(doc(db, `households/${hid}`), { name: hid });
      for (const [uid, role, status] of [
        [hid + "guardian", "guardian", "active"],
        [hid + "child", "child", "active"],
        [hid + "revoked", "adult", "revoked"],
      ]) {
        await setDoc(doc(db, `households/${hid}/members/${uid}`), {
          role,
          status,
          canAssign: role === "guardian",
        });
        await setDoc(doc(db, `households/${hid}/profiles/${uid}`), {
          nickname: "Fictional",
          role,
        });
      }
      await setDoc(doc(db, `households/${hid}/occurrences/assigned`), {
        assignedActorIds: [hid + "child"],
        status: "scheduled",
      });
      await setDoc(doc(db, `households/${hid}/occurrences/private`), {
        assignedActorIds: [hid + "guardian"],
        status: "scheduled",
      });
      await setDoc(doc(db, `households/${hid}/choreTemplates/public`), {
        childVisible: true,
      });
      await setDoc(doc(db, `households/${hid}/activity/event`), {
        action: "created",
      });
    }
    await setDoc(doc(db, "invites/secret"), { nonceHash: "hash" });
  });
});
const dbFor = (uid) => env.authenticatedContext(uid).firestore();
test("AUTH-01 anonymous and unrelated household reads denied", async () => {
  await assertFails(
    getDoc(doc(env.unauthenticatedContext().firestore(), "households/homeA")),
  );
  await assertFails(getDoc(doc(dbFor("homeAguardian"), "households/homeB")));
  await assertFails(
    getDoc(
      doc(dbFor("homeAguardian"), "households/homeB/occurrences/assigned"),
    ),
  );
});
test("AUTH-01 active guardian reads own household and occurrences", async () => {
  await assertSucceeds(getDoc(doc(dbFor("homeAguardian"), "households/homeA")));
  await assertSucceeds(
    getDocs(collection(dbFor("homeAguardian"), "households/homeA/occurrences")),
  );
});
test("AUTH-02 child cannot elevate, mutate occurrence or read secrets", async () => {
  const db = dbFor("homeAchild");
  await assertFails(
    setDoc(doc(db, "households/homeA/members/homeAchild"), {
      role: "guardian",
      status: "active",
    }),
  );
  await assertFails(
    setDoc(doc(db, "households/homeA/occurrences/assigned"), {
      status: "approved",
    }),
  );
  await assertFails(getDoc(doc(db, "invites/secret")));
  await assertFails(getDoc(doc(db, "households/homeA/activity/event")));
  await assertFails(getDoc(doc(db, "households/homeA/members/homeAguardian")));
});
test("Child queries must restrict assigned scope; appropriate roster readable", async () => {
  const db = dbFor("homeAchild");
  await assertSucceeds(
    getDoc(doc(db, "households/homeA/occurrences/assigned")),
  );
  await assertFails(getDoc(doc(db, "households/homeA/occurrences/private")));
  await assertFails(getDocs(collection(db, "households/homeA/occurrences")));
  await assertSucceeds(
    getDocs(
      query(
        collection(db, "households/homeA/occurrences"),
        where("assignedActorIds", "array-contains", "homeAchild"),
      ),
    ),
  );
  await assertSucceeds(getDocs(collection(db, "households/homeA/profiles")));
});
test("SYNC-03 revoked membership immediately denies server reads", async () => {
  await assertFails(getDoc(doc(dbFor("homeArevoked"), "households/homeA")));
  await assertFails(
    getDocs(collection(dbFor("homeArevoked"), "households/homeA/profiles")),
  );
});
test("All client mutations denied even for guardian", async () => {
  await assertFails(
    setDoc(doc(dbFor("homeAguardian"), "households/homeA/occurrences/new"), {
      status: "completed",
    }),
  );
  await assertFails(
    setDoc(doc(dbFor("homeAguardian"), "users/homeAguardian"), {
      role: "guardian",
    }),
  );
});
