# ADR-006 — Completion, review, undo and help

Accepted for the local M09 gate, 2026-10-29. Production hardening remains M16.

Each command targets a concrete occurrence and current base version. The server
resolves the actor from current membership; supervised device UIDs resolve to a
stable active child profile. Adults require verified trusted auth and a normal
server account type. Body UID/role/clock fields have no authority. Household,
account, membership/profile, assignment and action permissions are rechecked,
including accepted retries. No completion command writes a reusable definition or
future occurrence.

An actor contributes once. Any-one policy finishes with the first accepted
contribution; all-members records each assigned contribution and reaches quorum
only when all contribute. Quorum enters completed or pending_review according to
the stored policy. An exact UID-scoped command retry returns its accepted result;
a different command cannot inflate contributions. Stale versions produce a
structured conflict and require current-state review. Each accepted transition,
receipt, per-profile daily rate counter and immutable activity event commit once.
Activity is ordered by occurrence version, so equal server timestamps do not reorder
causal history. Review feedback remains in immutable activity after later decisions.

Only a current guardian outside the assignment/contributor set can approve or
request redo on a controlled pending chore. Redo requires a task-specific note,
clears current contributions and preserves previous audit. It never rewrites
history or promotes a child. Denied self-review is logged in private security
records, separate from the accepted-only household activity feed.

Own undo lasts five minutes from server acceptance. A separate completion revision
blocks undo after dependent contributions/undo/review while allowing an unrelated
help action to coexist. Undo restores scheduled state, or needs_redo if that was
the contributor's prior state. Approval/redo, cancelled/skipped state, stale scope
and expired/forged client time cannot bypass the gate. No history is erased.

Help is independent of completion. Public occurrence metadata contains only actor,
request reference, open/resolved state and time. Notes live in tenant help records,
readable by their actor and current chore managers; other children/adults without
that capability cannot read them. A manager can acknowledge a request without
changing completion state. New requests after acknowledgement retain prior records.
Help acknowledgement and optional response are real commands, not a fake progress
transition. Detailed postponement/reassignment negotiation remains M13.

Recorded partial work protects content/assignment from one-off editing and future
automatic reconciliation. Explicit cancellation retains contributions and audit.
Reassignment audit includes prior/new assigned IDs; occurrence action audit uses
public stable profile IDs, not extra child-device identities. Private receipts
retain the authenticated UID for replay investigation. Daily action quota is 1000
per household/profile, shared by supervised devices; accepted retries consume no
new action. Production abuse/retention/notification hardening remain later gates.

Offline durable recovery remains M12. During M09 online commands, an uncertain
request must keep its envelope unchanged and never present optimistic remote
success. UI status and contributions must derive from Firestore state. M09
verification records the actual widget/native results and remaining platform gates.
