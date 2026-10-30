import { enqueueOccurrenceNotifications } from "./notification_outbox.js";
import { assignmentNotificationState } from "./notification_assignment.js";
import {
  Timestamp,
  type Firestore,
  type Transaction,
  type DocumentSnapshot,
} from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";
import type { Actor } from "./contracts.js";
import { requireAdult } from "./households.js";
import { authorizeChoreManager, parseChoreContent } from "./chores.js";
import { identifier, commandId, record, text, hash } from "./validation.js";
import {
  addCivilDays,
  householdDate,
  previewRecurrence,
  validateRule,
  type RecurrenceRule,
  type RecurrenceSlot,
} from "./recurrence_engine.js";

type Content = ReturnType<typeof parseChoreContent>;
function canonical(value: unknown): unknown {
  if (value instanceof Timestamp)
    return { seconds: value.seconds, nanoseconds: value.nanoseconds };
  if (Array.isArray(value)) return value.map(canonical);
  if (value !== null && typeof value === "object")
    return Object.fromEntries(
      Object.entries(value)
        .sort(([a], [b]) => a.localeCompare(b))
        .map(([key, item]) => [key, canonical(item)]),
    );
  return value;
}
type TimelineEntry = { effectiveFrom: string; version: number };
type Definition = {
  version: number;
  effectiveFrom: string;
  rule: RecurrenceRule;
  paused: boolean;
  content: Content;
  templateVersion: number;
};
function normalizeRule(input: unknown, zone: string): RecurrenceRule {
  try {
    const raw = record(input);
    const timing = record(raw.timing);
    const rotation = record(raw.rotation);
    if (
      !Array.isArray(rotation.order) ||
      rotation.order.length > 20 ||
      !Array.isArray(raw.exceptions) ||
      raw.exceptions.length > 100
    )
      throw new Error();
    const rule: RecurrenceRule = {
      frequency: raw.frequency as RecurrenceRule["frequency"],
      startDate: text(raw.startDate, "start", 10),
      endDate: raw.endDate == null ? null : text(raw.endDate, "end", 10),
      count: (raw.count ?? null) as number | null,
      weekdays: raw.weekdays as number[],
      monthDay: (raw.monthDay ?? null) as number | null,
      timing: {
        kind: timing.kind as RecurrenceRule["timing"]["kind"],
        at: (timing.at ?? null) as string | null,
        endAt: (timing.endAt ?? null) as string | null,
        endDayOffset: (timing.endDayOffset ?? 0) as number,
      },
      timezoneIana: zone,
      rotation: {
        order: rotation.order.map(identifier),
        policy: rotation.policy as RecurrenceRule["rotation"]["policy"],
      },
      exceptions: raw.exceptions.map((item) => {
        const e = record(item);
        if (
          !Array.isArray(e.excludedActorIds) ||
          e.excludedActorIds.length > 20
        )
          throw new Error();
        return {
          date: text(e.date, "exception date", 10),
          excludedActorIds: e.excludedActorIds.map(identifier),
        };
      }),
    };
    validateRule(rule);
    return rule;
  } catch {
    throw new HttpsError(
      "invalid-argument",
      "Check the repeat dates, timing, rotation and exceptions.",
    );
  }
}
async function roster(db: Firestore, tx: Transaction, hid: string) {
  const profiles = await tx.get(db.collection(`households/${hid}/profiles`));
  const members = await tx.get(db.collection(`households/${hid}/members`));
  const active = new Set<string>();
  const guardians = new Set<string>();
  for (const p of profiles.docs) {
    if (p.get("status") === "revoked") continue;
    if (p.get("role") === "child") {
      if (p.get("status") === "active") active.add(p.id);
    } else {
      const member = members.docs.find((m) => m.id === p.id);
      if (
        member?.get("status") === "active" &&
        ["guardian", "adult"].includes(member.get("role"))
      ) {
        const account = await tx.get(db.doc(`users/${p.id}`));
        if (
          account.get("status") !== "disabled" &&
          account.get("accountType") !== "supervised_device"
        ) {
          active.add(p.id);
          if (member.get("role") === "guardian") guardians.add(p.id);
        }
      }
    }
  }
  return { active, guardians };
}
function reviewerAvailable(
  content: Content,
  order: string[],
  guardians: ReadonlySet<string>,
) {
  if (
    content.reviewMode === "guardian" &&
    order.some((id) => ![...guardians].some((g) => g !== id))
  )
    throw new HttpsError(
      "failed-precondition",
      "Each turn needs a guardian reviewer who is not assigned.",
    );
}
export async function previewRule(
  db: Firestore,
  actor: Actor | null,
  input: unknown,
) {
  requireAdult(actor);
  const data = record(input),
    hid = identifier(data.householdId),
    tid = identifier(data.templateId);
  if (data.paused !== undefined && typeof data.paused !== "boolean")
    throw new HttpsError("invalid-argument", "Invalid pause state.");
  return db.runTransaction(async (tx) => {
    const home = await authorizeChoreManager(db, tx, actor, hid);
    const rule = normalizeRule(data.rule, home.get("timezoneIana") as string);
    const template = await tx.get(
      db.doc(`households/${hid}/choreTemplates/${tid}`),
    );
    if (!template.exists || template.get("active") !== true)
      throw new HttpsError("not-found", "Chore definition unavailable.");
    const people = await roster(db, tx, hid);
    reviewerAvailable(
      parseChoreContent(template.data()!),
      rule.rotation.order,
      people.guardians,
    );
    try {
      const fromDate = text(data.fromDate, "preview date", 10);
      addCivilDays(fromDate, 0);
      const today = householdDate(Date.now(), rule.timezoneIana);
      if (
        fromDate <= today ||
        fromDate > addCivilDays(today, 30) ||
        rule.startDate > fromDate
      )
        throw new Error("Invalid effective date");
      return {
        slots:
          data.paused === true
            ? []
            : previewRecurrence(
                rule,
                text(data.fromDate, "preview date", 10),
                14,
                people.active,
              ),
        timezoneIana: rule.timezoneIana,
        paused: data.paused === true,
        policy: "monthly_skip;gap_first_valid;overlap_earlier",
      };
    } catch {
      throw new HttpsError("invalid-argument", "Choose a valid preview date.");
    }
  });
}

function timelineFor(
  existing: TimelineEntry[],
  effectiveFrom: string,
  version: number,
  today: string,
) {
  const list = [
    ...existing.filter((e) => e.effectiveFrom < effectiveFrom),
    { effectiveFrom, version },
  ].sort((a, b) => a.effectiveFrom.localeCompare(b.effectiveFrom));
  const older = list.filter((e) => e.effectiveFrom <= today).at(-1);
  return [
    ...(older ? [older] : []),
    ...list.filter((e) => e.effectiveFrom > today),
  ];
}
function versionAt(timeline: TimelineEntry[], date: string) {
  return timeline.filter((e) => e.effectiveFrom <= date).at(-1)?.version;
}
function slotRecord(slot: RecurrenceSlot, def: Definition, tid: string) {
  return {
    ...def.content,
    ...slot,
    templateId: tid,
    templateVersion: def.templateVersion,
    recurrenceVersion: def.version,
    localDate: slot.date,
    dueAtUtc:
      slot.dueAtMillis === null ? null : Timestamp.fromMillis(slot.dueAtMillis),
    windowStartAtUtc:
      slot.windowStartAtMillis === null
        ? null
        : Timestamp.fromMillis(slot.windowStartAtMillis),
  };
}
type Change = {
  id: string;
  before: DocumentSnapshot | null;
  next: Record<string, unknown>;
  signature: string;
  action: string;
};
async function plan(
  db: Firestore,
  tx: Transaction,
  hid: string,
  tid: string,
  timeline: TimelineEntry[],
  definitions: Map<number, Definition>,
  active: ReadonlySet<string>,
  guardians: ReadonlySet<string>,
  from: string,
  nowMillis: number,
) {
  const through = addCivilDays(from, 30);
  const prior = await tx.get(
    db
      .collection(`households/${hid}/occurrences`)
      .where("templateId", "==", tid)
      .where("localDate", ">=", from),
  );
  const extraDates = [
    ...new Set(
      prior.docs
        .filter(
          (d) =>
            Number(d.get("recurrenceVersion")) > 0 &&
            d.get("localDate") > through,
        )
        .map((d) => d.get("localDate") as string),
    ),
  ];
  const desired = new Map<string, { slot: RecurrenceSlot; def: Definition }>();
  for (const def of definitions.values()) {
    if (def.paused) continue;
    const slots = previewRecurrence(def.rule, from, 31, active);
    for (const date of extraDates)
      slots.push(...previewRecurrence(def.rule, date, 1, active));
    for (let slot of slots) {
      if (
        slot.status === "scheduled" &&
        def.content.reviewMode === "guardian" &&
        ![...guardians].some((g) => !slot.assignedActorIds.includes(g))
      )
        slot = { ...slot, status: "skipped", reason: "reviewer_unavailable" };
      if (versionAt(timeline, slot.date) === def.version)
        desired.set(hash(JSON.stringify([hid, tid, "date", slot.date])), {
          slot,
          def,
        });
    }
  }
  const frozen = (snapshot: DocumentSnapshot) => {
    // An explicit guardian change belongs to this occurrence, not the rule.
    if (snapshot.get("scheduleOverride.kind") === "postpone") return true;
    if (Object.keys(snapshot.get("contributions") ?? {}).length > 0)
      return true;
    const date = snapshot.get("localDate") as string;
    const storedZone = snapshot.get("timezoneIana") as string;
    return date <= from || date <= householdDate(nowMillis, storedZone);
  };
  const byId = new Map(prior.docs.map((d) => [d.id, d]));
  const changes: Change[] = [];
  for (const [id, target] of desired) {
    const before = byId.get(id) ?? null;
    // Today's stored turn is history for automatic assignment reconciliation.
    if (before && frozen(before)) continue;
    if (
      before &&
      !["scheduled", "skipped"].includes(before.get("status")) &&
      !(
        before.get("status") === "cancelled" &&
        before.get("cancelReason") === "rule_changed"
      )
    )
      continue;
    const next = slotRecord(target.slot, target.def, tid);
    const signature = hash(JSON.stringify(canonical(next)));
    if (
      before?.get("materializationHash") === signature &&
      before.get("status") === next.status
    )
      continue;
    changes.push({
      id,
      before,
      next,
      signature,
      action: before ? "recurrence_revised" : "recurrence_materialized",
    });
  }
  for (const before of prior.docs) {
    if (
      desired.has(before.id) ||
      frozen(before) ||
      versionAt(timeline, before.get("localDate") as string) === undefined ||
      !["scheduled", "skipped"].includes(before.get("status"))
    )
      continue;
    // Includes the superseded future one-off. Preserve history and all terminal work.
    changes.push({
      id: before.id,
      before,
      next: { status: "cancelled", cancelReason: "rule_changed" },
      signature: hash(
        JSON.stringify([tid, "cancel", before.id, before.get("version")]),
      ),
      action: "recurrence_cancelled",
    });
  }
  if (changes.length > 200)
    throw new HttpsError(
      "resource-exhausted",
      "This schedule requires a separate recovery pass.",
    );
  return { changes, through };
}
function apply(
  db: Firestore,
  tx: Transaction,
  hid: string,
  changes: Change[],
  now: Timestamp,
  actorId: string,
) {
  for (const change of changes) {
    const version = Number(change.before?.get("version") ?? 0) + 1;
    const ref = db.doc(`households/${hid}/occurrences/${change.id}`);
    const value = {
      ...change.next,
      version,
      ...assignmentNotificationState(change.before?.data(), change.next, now),
      materializationHash: change.signature,
      updatedAt: now,
    };
    if (change.before) tx.update(ref, value);
    else tx.create(ref, { ...value, createdAt: now });
    enqueueOccurrenceNotifications(db, tx, hid, change.id, version, now);
    tx.create(
      db.doc(
        `households/${hid}/activity/${hash(JSON.stringify([change.id, version, change.signature]))}`,
      ),
      {
        action: change.action,
        entityId: change.id,
        actorId,
        actorType: actorId === "scheduler" ? "system" : "member",
        fromVersion: Number(change.before?.get("version") ?? 0),
        fromAssignedActorIds: change.before?.get("assignedActorIds") ?? [],
        toAssignedActorIds:
          change.next.assignedActorIds ??
          change.before?.get("assignedActorIds") ??
          [],
        fromStatus: change.before?.get("status") ?? null,
        toStatus: change.next.status,
        reason: change.next.reason ?? change.next.cancelReason ?? null,
        toVersion: version,
        serverAt: now,
      },
    );
  }
}
async function definitionsFor(
  db: Firestore,
  tx: Transaction,
  hid: string,
  tid: string,
  timeline: TimelineEntry[],
) {
  const definitions = new Map<number, Definition>();
  for (const entry of timeline) {
    const snapshot = await tx.get(
      db.doc(
        `households/${hid}/recurrenceRules/${tid}/versions/${entry.version}`,
      ),
    );
    if (!snapshot.exists)
      throw new HttpsError(
        "failed-precondition",
        "Schedule history is unavailable.",
      );
    definitions.set(entry.version, snapshot.data() as Definition);
  }
  return definitions;
}
export async function saveRule(
  db: Firestore,
  actor: Actor | null,
  input: unknown,
) {
  requireAdult(actor);
  const data = record(input),
    hid = identifier(data.householdId),
    tid = identifier(data.templateId),
    cid = commandId(data.commandId);
  if (
    typeof data.paused !== "boolean" ||
    !Number.isSafeInteger(data.baseTemplateVersion) ||
    !Number.isSafeInteger(data.baseRuleVersion)
  )
    throw new HttpsError(
      "invalid-argument",
      "Include the current versions and pause state.",
    );
  const paused = data.paused;
  const expectedTimezone = text(data.expectedTimezone, "expected timezone", 80);
  const receipt = db.doc(
    `commands/${hash(JSON.stringify([actor.uid, cid, "recurrence"]))}`,
  );
  return db.runTransaction(async (tx) => {
    const home = await authorizeChoreManager(db, tx, actor, hid);
    const zone = home.get("timezoneIana") as string;
    const rule = normalizeRule(data.rule, zone);
    const now = Timestamp.now(),
      today = householdDate(now.toMillis(), zone);
    const effectiveFrom = text(data.effectiveFrom, "effective date", 10);
    try {
      addCivilDays(effectiveFrom, 0);
    } catch {
      throw new HttpsError(
        "invalid-argument",
        "Choose a valid effective date.",
      );
    }
    const payloadHash = hash(
      JSON.stringify([
        hid,
        tid,
        { ...rule, timezoneIana: expectedTimezone },
        effectiveFrom,
        paused,
        data.baseTemplateVersion,
        data.baseRuleVersion,
      ]),
    );
    const accepted = await tx.get(receipt);
    if (accepted.exists) {
      if (accepted.get("payloadHash") !== payloadHash)
        throw new HttpsError("already-exists", "Request ID already used.");
      return accepted.get("result") as { version: number; changed: number };
    }
    // Future changes cannot silently shift any previous household date.
    if (
      effectiveFrom <= today ||
      effectiveFrom > addCivilDays(today, 30) ||
      rule.startDate > effectiveFrom
    )
      throw new HttpsError(
        "invalid-argument",
        "Choose an effective date from tomorrow through the next thirty days, on or after the rule start.",
      );
    if (expectedTimezone !== zone)
      throw new HttpsError(
        "aborted",
        "The household timezone changed. Preview again before saving.",
      );
    const templateRef = db.doc(`households/${hid}/choreTemplates/${tid}`),
      root = db.doc(`households/${hid}/recurrenceRules/${tid}`);
    const template = await tx.get(templateRef),
      current = await tx.get(root);
    if (!template.exists || template.get("active") !== true)
      throw new HttpsError("not-found", "Chore definition unavailable.");
    if (
      template.get("version") !== data.baseTemplateVersion ||
      Number(current.get("version") ?? 0) !== data.baseRuleVersion
    )
      throw new HttpsError(
        "aborted",
        "The schedule changed. Reload before editing.",
      );
    const content = parseChoreContent(template.data()!);
    const people = await roster(db, tx, hid);
    if (rule.rotation.order.some((id) => !people.active.has(id)))
      throw new HttpsError(
        "invalid-argument",
        "Choose only current eligible household profiles.",
      );
    reviewerAvailable(content, rule.rotation.order, people.guardians);
    const version = Number(current.get("version") ?? 0) + 1;
    const timeline = timelineFor(
      (current.get("timeline") ?? []) as TimelineEntry[],
      effectiveFrom,
      version,
      today,
    );
    const definitions = await definitionsFor(
      db,
      tx,
      hid,
      tid,
      timeline.filter((e) => e.version !== version),
    );
    const definition: Definition = {
      version,
      effectiveFrom,
      rule,
      paused,
      content,
      templateVersion: Number(data.baseTemplateVersion) + 1,
    };
    definitions.set(version, definition);
    const rateRef = db.doc(`rateLimits/${actor.uid}`),
      rate = await tx.get(rateRef);
    const day = new Date(now.toMillis()).toISOString().slice(0, 10);
    const writes =
      rate.get("choreDay") === day ? Number(rate.get("choreWrites") ?? 0) : 0;
    if (writes >= 500)
      throw new HttpsError(
        "resource-exhausted",
        "Daily chore management limit reached.",
      );
    const planned = await plan(
      db,
      tx,
      hid,
      tid,
      timeline,
      definitions,
      people.active,
      people.guardians,
      today,
      now.toMillis(),
    );
    // An already recorded future one-off must not acquire a second active identity.
    const oneOff = await tx.get(
      db.doc(
        `households/${hid}/occurrences/${hash(JSON.stringify([hid, tid, "once"]))}`,
      ),
    );
    if (
      oneOff.exists &&
      oneOff.get("localDate") >= effectiveFrom &&
      (!["scheduled", "cancelled", "skipped"].includes(oneOff.get("status")) ||
        Object.keys(oneOff.get("contributions") ?? {}).length > 0)
    )
      throw new HttpsError(
        "failed-precondition",
        "Start repeating after the existing recorded assignment date.",
      );
    tx.create(root.collection("versions").doc(String(version)), {
      ...definition,
      createdAt: now,
      createdBy: actor.uid,
    });
    tx.set(root, { version, timeline, managed: true, updatedAt: now });
    tx.update(templateRef, {
      scheduleKind: "recurring",
      version: Number(data.baseTemplateVersion) + 1,
      updatedAt: now,
    });
    apply(db, tx, hid, planned.changes, now, actor.uid);
    const result = { version, changed: planned.changes.length };
    tx.create(receipt, {
      uid: actor.uid,
      payloadHash,
      result,
      acceptedAt: now,
    });
    tx.set(
      rateRef,
      { choreDay: day, choreWrites: writes + 1 },
      { merge: true },
    );
    tx.create(db.doc(`households/${hid}/activity/${receipt.id}`), {
      action: "recurrence_rule_saved",
      actorId: actor.uid,
      entityId: tid,
      ruleVersion: version,
      supersededVersions: ((current.get("timeline") ?? []) as TimelineEntry[])
        .filter((e) => e.effectiveFrom >= effectiveFrom)
        .map((e) => e.version),
      effectiveFrom,
      serverAt: now,
    });
    return result;
  });
}
export async function materializeRule(
  db: Firestore,
  hid: string,
  tid: string,
  nowMillis = Date.now(),
  actor?: Actor,
) {
  return db.runTransaction(async (tx) => {
    if (actor) await authorizeChoreManager(db, tx, actor, hid);
    const home = await tx.get(db.doc(`households/${hid}`));
    const template = await tx.get(
      db.doc(`households/${hid}/choreTemplates/${tid}`),
    );
    const root = await tx.get(
      db.doc(`households/${hid}/recurrenceRules/${tid}`),
    );
    if (
      !home.exists ||
      home.get("archivedAt") != null ||
      template.get("active") !== true ||
      !root.exists
    )
      return { changed: 0 };
    const timeline = root.get("timeline") as TimelineEntry[];
    const definitions = await definitionsFor(db, tx, hid, tid, timeline);
    const people = await roster(db, tx, hid);
    const today = householdDate(nowMillis, home.get("timezoneIana") as string);
    const lease = db.doc(`households/${hid}/schedulerLeases/${tid}`),
      priorLease = await tx.get(lease);
    const signature = hash(
      JSON.stringify([
        root.get("version"),
        today,
        [...people.active].sort(),
        [...people.guardians].sort(),
      ]),
    );
    if (
      priorLease.get("signature") === signature &&
      (priorLease.get("expiresAt") as Timestamp)?.toMillis() > nowMillis
    )
      return { changed: 0 };
    const planned = await plan(
      db,
      tx,
      hid,
      tid,
      timeline,
      definitions,
      people.active,
      people.guardians,
      today,
      nowMillis,
    );
    const now = Timestamp.fromMillis(nowMillis);
    // The lease and all work commit together; no abandoned partial materialization.
    tx.set(lease, {
      signature,
      expiresAt: Timestamp.fromMillis(nowMillis + 60_000),
      lastRunAt: now,
      through: planned.through,
    });
    apply(db, tx, hid, planned.changes, now, "scheduler");
    return { changed: planned.changes.length };
  });
}
export async function refreshRule(
  db: Firestore,
  actor: Actor | null,
  input: unknown,
) {
  requireAdult(actor);
  const data = record(input),
    hid = identifier(data.householdId),
    tid = identifier(data.templateId);
  return materializeRule(db, hid, tid, Date.now(), actor);
}
