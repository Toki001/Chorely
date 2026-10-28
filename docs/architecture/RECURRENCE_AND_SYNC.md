# Recurrence, Rotation, Offline & Conflict Specification

## Recurrence model
1. Template defines the chore identity and instructions. Recurrence rule defines calendar generation. Occurrence represents one real scheduled turn. **Never treat one recurring template as one mutable task row**.
2. All rules stored in a household's IANA timezone, e.g. `Asia/Manila`; schedule slots are local civil dates/times; derive UTC `dueAt` using a library with documented DST handling.
3. Supported P0 recurrence: once; daily; chosen weekdays; weekly; monthly on specified day with explicit handling of nonexistent dates; optional end date or occurrence count.
4. Scheduler materializes a bounded rolling horizon (e.g. next 30 days, reevaluate) via idempotent deterministic IDs and server lease; clients can preview further without claiming server provisioned.
5. Rule changes require effective-from choice. Maintain historical immutable occurrences and preserve completed state; apply new version to future slots and gracefully cancel/recreate if policy allows. Duplicate slots must be prevented.
6. A pause/sick/away exception may omit or reassign future occurrences, never rewrite completed history. Existing due reminders must be invalidated/rescheduled.

## Rotation rules
- Eligible actor set, ordered round-robin or explicitly selected weekdays; cursor anchored to local schedule slots, not incremented by unpredictable completion time.
- Skip/absence policy must be explicit: `preserve_turn` / `give_to_next_eligible` (documented). Assignment preview displays exceptions.
- Concurrent editing resolves via rule version / server transaction. Never silently assign an age-inappropriate task to a child.
- Example: Mon Alex, Tue Jamie, Wed adult, Thu Alex. If Jamie absent Tue, selected policy determines substitute; Wed historical and future anchor remain deterministic.

## Task completion transitions
- Client generates UUID `commandId` and baseOccurrenceVersion, stores pending UI action; callable backend validates membership, role, assignee, status, idempotency and task version; writes state + audit once.
- Server returns accepted/current state or structured conflict (`already_done`, `reassigned`, `approval_required`, `membership_revoked`, `occurrence_cancelled`, `version_conflict`).
- If review enabled, child completion enters `pending_review` rather than `approved`. A guardian can confirm or request redo with respectful explanation.
- Undo permitted only if still legal after other actors' actions; never delete audit. Don't report completion notifications multiple times.

## Offline approach
- Read from Firestore local cache; show last-sync time / pending indicator when offline.
- For durable offline commands, local outbox includes idempotency key, `householdId`, occurrence id, action, expected version, time and retry status.
- Replay in order per occurrence after reauth; backoff and stop on permanent denial, expose user decision for conflict. No background phantom success.
- Firestore's own queued writes are last-write-wins for same document; **do not rely on this for important state transitions**. Use trusted server adjudication, version preconditions and audit.
- Keep local secure cache partitioned by logged-in identity; wipe inaccessible household copies promptly on membership revocation/logout after reconnect and on known revocation events.

## Required deterministic test cases
- Daily recurrence across month end, leap day, DST spring/fall for a non-Manila timezone, household timezone update, midnight due slots, app offline 3 days.
- Monthly on 31st in February, weekly skipped dates, empty eligible rotation, removed child, duplicate scheduler run, late command for cancelled occurrence.
- Two devices completing same occurrence, adult rejects child pending review, device offline through revocation, two swap requests, resumed queue after process kill.
- Recurrence editing after 5 completed historical occurrences; no history loss, next 14-day preview stable.

## Notification interaction
Every rule edit/occurrence status transition updates unique notification jobs; jobs check current server state, authorization, quiet hours and deduplication at dispatch time.
