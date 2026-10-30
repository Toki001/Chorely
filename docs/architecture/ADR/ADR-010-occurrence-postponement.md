# ADR 010 — Explicit guardian postponement

Status: accepted for the verified local M13 postponement slice, 2026-10-30.
Overall M13 remains PARTIAL.

Postponement is a guardian-only occurrence command, distinct from editing a
reusable chore or recurrence rule. Current verified adult authorization, server
account/membership, eligible assignees and independent review policy are checked
in the transaction. Accepted retries still require current guardian access. A
payload-bound UID/UUID receipt and expected occurrence version prevent competing
changes from silently replacing each other. The server clock controls bounds;
client-supplied time has no authority.

Only scheduled or needs_redo occurrences without current contributions may move.
The deadline must be later than both the existing due instant and server now,
within the next thirty civil days in the occurrence's existing IANA zone. Untimed
chores must move to a later day. A new window must begin after now; the shared
wall-clock resolver retains the earlier-overlap/first-valid-gap policy. The
initial UI explicitly chooses a single deadline and explains that this replaces
a time window. The service also validates a supplied later window.

The occurrence ID, slotKey, template/version, rule version, assignment, review,
completion state and history stay intact. Only actual timing/version and an
explicit scheduleOverride change. That override records the first original local
date, latest accepted command/guardian/time. Versioned immutable activity keeps
every previous/new schedule, so later postponements do not erase history. An
automatic recurrence refresh or future rule pause preserves an explicitly moved
occurrence; guardians must manage that individual turn separately. Rule previews
describe the base rotation; Calendar/detail show the actual moved occurrence.

The same transaction enqueues notification reconciliation. Timing jobs change
their schedule revision and old jobs are cancelled; assignment identity now uses
the owner generation/set alone. A postponed deadline cannot issue another copy
of an already published/read assignment. Provider sends remain M11's open gate;
offline OS alerts retain its documented best-effort limitation. No live data
migration or deployed job change was performed.

The online form freezes date/time/UUID/base after an uncertain response, confirms
only after the callable acknowledgement and fresh server read, and stops on
conflict/permanent rejection. Reload must succeed before leaving review. This
authoring request is not part of M12's durable completion journal. Closing the
form/process can lose its local retry envelope; any accepted backend override
remains visible after reopening. Partial work/terminal tasks cannot be reopened
by postponing. Negotiated swaps, routine bundles, away UI and their approval
rules remain separate M13 work.
