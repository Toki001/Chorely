# User Flows / Critical Journeys

## F01 Adult create household
Launch → intro (illustrated) → guardian account auth / consent → household name and timezone → optionally add members → land on Today empty state → create first chore. Handle retry, duplicate name, offline condition, no notification permission.

## F02 Invite adult
Family → invite adult → server issues short-lived single-use invite/code/QR → recipient authenticates → server validates token and role → household appears → invite event logged. Expired/revoked/reused invites fail gracefully.

## F03 Add supervised child without email
Family → add child nickname/avatar → choose permission preset → optional shared-device profile or guardian-approved QR device pairing → device acquires backend-scoped permission via secure short-lived flow; no PIN-only auth → child Today with minimal data. Guardian can revoke device anytime.

## F04 Create a one-off chore
Chores → + → pick suggested preset or custom → name, icon, steps, eligible assignee, due window, reminder, optional requires-review → preview → save → assignee notified once → appears on personal and shared calendars.

## F05 Create rotating dinner chore
Chores → + → Wash dishes → repeat weekdays → choose Alice/Bob/Parent eligible rotation order → preview 2 weeks of actual assignees → save recurrence rule → provision occurrences idempotently → members view turns. Changes affect future occurrences according to explicit policy.

## F06 Complete a chore
Child Today → assigned chore → mark done → immediate pending sync UI if offline → server validates member, occurrence and idempotency key → state completed/pending_review → household progress, history, optional guardian notification update. Undo allowed only within defined policy and audited.

## F07 Missed or unavailable
Assignee chooses Need help / Postpone → optional reason → permitted adult reviews / grants extension or reassigns → prevent misleading past completion and notification duplication. Away-day future assignment adjustment is P1.

## F08 Routine
Guardian creates Dinner routine grouping cook rice / set table / wash dishes → configure dependencies/reminder suggestions → occurrences stay individually assigned and completable → family sees sequence and progress. P1.

## F09 Offline
Device loses internet → previously loaded chores still appear → member marks task as pending offline → local outbox stores unique command → when back online reconcile authoritative server state → accepted, rejected/revoked, or conflict shown with explanation; do not overwrite silently.

## F10 Shopping list (P1)
Lists → Shared groceries → add item → second device sees change → one marks purchased → duplicate update resolves deterministically → recent activity accurately reflects action.

## F11 Leaving household / delete data
Guardian/member → manage data → leave (according to role) or request export/deletion → server revokes tokens and access → cached sensitive data cleared promptly → legal/technical retention policy explained. Never strand a household without an admin without warning.
