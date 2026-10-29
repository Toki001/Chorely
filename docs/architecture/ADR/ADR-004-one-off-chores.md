# ADR-004 — One-off chore commands and household time

Accepted for the local M07 gate, 2026-10-29. Production hardening remains M16.

`writeOneOffChore` is the sole creation/edit/archive boundary. The caller must be
an authenticated verified adult with a current active guardian membership, or an
adult membership with server-owned `canAssign=true`. Server-owned supervised
account type and token supervision both deny adult commands. Body roles/UIDs have
no authority. Every assignee must resolve to a current household profile; adult
assignees also need active membership. Choosing a child never implies age or
capability approval. A guardian explicitly chooses instructions and eligibility.

Creation writes a reusable definition and a separate concrete assignment, each
versioned. The occurrence snapshots title, category/icon key, room, description,
steps, team/review policies, assignees and timing. Completion will target only the
occurrence in M09. Presets supply title/category only; there is no generated
cooking, parenting or safety advice. The UI supports text instructions and the optional original bundled `assign`
illustration with an accessible label. No arbitrary URL or upload is accepted.
External instruction uploads require a separate storage/security design under
the PRD and remain outside the initial slice.

A UUIDv4 command ID and SHA-256 UID-scoped receipt bind a normalized payload.
Repeated requests recheck authority and return the accepted result. A changed
payload with the same ID is rejected. Template and occurrence IDs are deterministic
hashes; one-off slot identity is stable across retries. Create/edit/archive,
receipt, rate counter and immutable activity event commit together. Daily writes
are bounded at 500 per actor; retries do not spend a new write quota.

Edits carry both base versions and can update only an active one-off definition
and its still-scheduled occurrence. A stale version returns `aborted` with current
versions; neither newer instructions nor completed history is silently replaced.
The occurrence's `templateVersion` identifies the snapshotted definition. Cancel
soft-archives the definition and cancels the assignment, preserving both and the
audit. No hard-delete action is exposed. Recurring definitions will have a separate
rule/version workflow in M08; this command cannot rewrite them.

Team policies are explicit: one assignee for the team, or every assignee's part.
Review requires a currently active guardian outside the assignee set. These are
stored policies, not a claim that M09 status transitions already exist.

Dates are explicit Gregorian household dates, 2000–2100. No-time assignments have
a date and null UTC deadline. Time/deadline uses HH:mm; windows have a start on the
selected household date and a later end, at most seven days in UTC duration.
Cross-midnight windows are supported. Household IANA zone is read inside the
transaction, not supplied by the client. Node Intl's IANA data resolves requested
wall minutes: choose the earlier instant during an overlap and the first valid
minute after a gap, including a skipped civil date. Store requested and effective
local values, zone and UTC instants. An adjustment is visible in chore details.
The algorithm has deterministic tests for New York, Lord Howe and Apia. The Node
version is pinned; timezone database updates require regression verification.

The app shows success only after the server command acknowledges and a server
refresh succeeds. An uncertain save locks the submitted details and retries the
same request. Conflicts require reopening current details. Reads remain streams
under tenant/assignee rules. This is online command behavior; durable process-kill
outbox and offline reconciliation remain M12. Nothing claims offline success.

Bounds: title 100 UTF-16 units, description 2000, room 80, 12 text steps of 200,
1–6 distinct assignees. No child email/DOB, external instruction uploads, public sharing or
live notifications were added by this milestone.
