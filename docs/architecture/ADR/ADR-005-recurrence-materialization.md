# ADR-005 — Versioned recurrence, rotation and materialization

Accepted for the local M08 gate, 2026-10-29. This is not release readiness.

A recurring definition has immutable numbered versions plus a small effective-date
timeline. Rule publication checks the current template and rule versions, manager
capability and current household zone. It binds normalized input and expected zone
to an idempotency receipt. Accepted retries recheck authority and remain retrievable
after the original effective date or a later household-zone change. A new future
version starts tomorrow through thirty household days ahead. A new version replaces pending settings from its effective date onward; all
superseded immutable records remain. The timeline then matches the advertised
preview instead of allowing a later pending version to silently override it. Keep the current anchor and future timeline entries; stored past
occurrences preserve historical versions even after timeline pruning.

Supported cadence: daily, selected ISO weekdays, weekly on the start-date weekday,
and monthly on a specified day. Missing monthly dates skip. Count is a global count
of scheduled slots from the anchor, not a count of visible/query results or completed
chores. Optional end date is inclusive. Bounds: dates 2000–2100, count 1–3660,
1–20 ordered selected people, up to 100 explicit date exclusions. Timing supports
no time, at, deadline and windows crossing up to seven civil dates, with a seven-day
UTC duration cap. DST gaps use first valid minute and overlaps the earlier instant.
A collapsed/overlong clock-change window is explicitly skipped with a reason.

Rotation is `ordinal % order.length`. Unavailable people/exclusions either preserve
an empty turn or substitute the next explicitly selected available person. Neither
completion nor substitution moves later ordinals. Deleted/revoked members cannot
silently shift stored history. New publication requires all selected profiles to be
eligible. Later reconciliation follows the stored unavailability policy and records
revisions. A missing separate guardian reviewer skips affected future turns; it
never downgrades review. Recurrence exception negotiation UI remains P1/M13.

Date-slot IDs hash household/template/date, independent of rule version. A version
change updates still-future scheduled/skipped state or cancels omitted dates; it
never creates a second active identity for the same date. Today’s stored turn is
protected from automatic reassignment, even if membership changes during the day.
The occurrence’s stored timezone also protects a date that already began there,
even when a new household zone still labels that date as tomorrow. Completed/pending/reviewed
and manually cancelled records are preserved. A superseded future one-off is
explicitly cancelled while retaining its identity/audit. A recorded future one-off
requires repeating to begin after its date. Each occurrence snapshots content,
rule/template version, original scheduled owner, actual assignment and timing.

A transaction reads household, rule versions, roster, current future occurrences
and lease before writing. It materializes a rolling 31-day horizon and reconciles
already stored future dates beyond the new horizon boundary. Each changed slot
receives a new version and immutable activity event with prior/new assignee IDs
and status, so future substitutions remain auditable. Canonically sorted hashes
prevent Firestore map key ordering from inflating revisions. Duplicate worker runs
and concurrent publication converge on one stored slot. A per-rule 60-second lease
and all its work commit together; no separate partially acquired work state exists.
Membership/guardian-set changes invalidate the lease signature.

The worker uses a global five-minute lease, a persisted document cursor, pages of
25 and at most eight pages per run. Failures record private error codes and do not
block other rules. A subsequent run resumes and wraps the cursor. The scheduled
entry point is every six UTC hours; local development uses a strict demo/loopback
adapter ticking once per minute, or `--once`. Both invoke the same trusted worker.
No client can choose a worker clock, scan other households or read worker state.
A manager-only refresh rechecks authority in the materialization transaction.

The SDK schedule entry is authored but no Cloud Scheduler job has been deployed.
Firebase's [schedule documentation](https://firebase.google.com/docs/functions/schedule-functions)
notes overlapping executions and that deployment creates the scheduler resource.
The pinned installed SDK `scheduler.d.ts` was inspected; billing/account/deployment
remain authorized release gates. No production account or billed job was created.

The server preview uses the same engine and current household/roster/review policy.
It covers fourteen calendar days, and is explicitly marked preview until saved.
Native controls invalidate a preview after edits, preserve uncertain request IDs,
and route recurring edits through future rule versions. One-off edit/cancel stays
available only while the definition has no recurrence configuration.

Limits to retain in verification: no live scheduler/IAM result; Android runtime and
physical devices remain untested. Household timezone setting UI is still later
settings work; tests use Admin solely to simulate that separately authorized change
and verify future version/previous UTC preservation. There is no silent rewrite of
old rule zones. Past missing slots beyond the rolling operational horizon need a
separate backfill policy. Broad household-list pagination/filtering remains M10/M17.
