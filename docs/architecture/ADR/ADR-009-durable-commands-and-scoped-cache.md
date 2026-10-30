# ADR 009 — Durable chore commands and identity-scoped reads

Status: accepted for the local M12 gate, 2026-10-30. Physical storage/expired-token
and release verification remain M16–M18.

An occurrence action persists its immutable UUID, SDK UID, household/occurrence,
action, expected version, optional note/target and attempt metadata before its
first network call. Only one pending/conflicting/rejected command per identity
and occurrence is allowed; 100 active requests bound local work. Five due commands
run per pass, with capped retry backoff and a ten-second callable timeout. Process
restart and unknown responses replay the original envelope. Actual state/progress
comes only from server occurrences. A server acknowledgement adds a local receipt
fence until the corresponding newer snapshot arrives, preventing an immediate
second tap on an old view. No local optimistic completion is counted.

Known conflicts and permanent rejection stop replay. A user must load current
server state and explicitly review before replacing the request; no silent base
version advance exists. Pending requests cannot be silently discarded as assumed
failures because the server may already have committed. Logout/identity change
purges the old account's commands; late replies cannot recreate a removed row.
Auth restoration is explicitly distinct from signed-out state. During credential
restoration/error, replay is suspended and durable bytes remain isolated. Only a
confirmed signed-out state purges all. This avoids deleting the queue during the
initial SDK/claims lookup. Server authorization remains current at replay.

A separate SQLite read cache stores only confirmed household/index, membership,
roster, range/detail and clock DTOs, scoped to SDK UID and household, with an
additional supervised-profile key and a household scope fence. A confirmed
supervised scope change purges the previous household copy. Firestore
memory snapshots never establish fresh authority or an empty household. A view
may display its own previously confirmed snapshot with a persistent saved-data
banner while checking the connection. Cached clock data remains the last observed
household date/time, visibly stale; it is not a fresh server clock. Permission
failure never falls back to cache. Known membership/profile removal revokes the
home, purges its cache/commands and invalidates delayed responses. Confirmed adult
home-index removals also purge those previously listed household copies. Returning
a removed membership currently requires a fresh authenticated session.

Read entries expire after seven device-clock days, cap at 300 per identity and
2 MB per entry. These bound storage, not backend query pagination or guaranteed
availability. Last confirmed session scope can be restored only for the SDK's
same current UID on a network-only token lookup failure; disabled/revoked auth
errors do not fall back. No token or email is copied into this session record.
Offline cached roles grant no server capability; all replay rechecks membership,
profile, assignee, state, quota and command receipt on the backend.

Native database identity/household epochs invalidate queued inserts before purge,
so a late write cannot recreate rows after logout or known removal.

The databases live in a dedicated iOS directory excluded from backup with OS
complete-until-first-authentication file protection. Android disables application
backup. SQLite uses FULL synchronous transactions, secure_delete and a DELETE
journal for sync data. This is OS-backed local storage, not application-level
cryptography or a promise of forensic erasure; hardware/locked-state behavior and
privacy text remain M16–M18 verification gates. Logout clears rows. Private notes
remain only in the submitting identity's queue; cached roster/task DTOs contain
no invite secret, child email/DOB, remote registration token or private help note.

The sync status area preserves the active navigator, caps itself at one-third of
the available viewport and scrolls at large text. Pending counts describe durable
requests, never completed chores. An offline queued command keeps its detail
state unchanged until actual server acceptance. No connectivity plugin or device
network observation is treated as an acknowledgement.
