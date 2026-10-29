# Data Model and Invariants

## Canonical entities
| Entity | Fields (minimum) | Sensitive invariants |
|---|---|---|
| `user_account` | `uid`, verified adult auth method, createdAt, status | Adults authenticated, not silently converted from child profile. |
| `household` | `id`, name, timezoneIana, ownerUid, createdAt, archivedAt, version | Stable tenant ID; access restricted to membership. |
| `membership` | `householdId`, `actorId`, `uid?`, `role`, `capabilities`, status, joinedAt, revokedAt | Role server-controlled; child may be device-linked actor without personal auth credentials. |
| `profile` | `actorId`, displayNickname, avatarKey, themeColor, supervised, displayOrder | Minimal data, no DOB/email default for kids. |
| `paired_device` | deviceIdOpaque, actorId, householdId, keyFingerprint, issuedAt, revokedAt, lastSeenAt | Guardian-approved, scoped, revocable; never raw key in Firestore. |
| `invite` | inviteId, householdId, nonceHash, intendedRole, expiresAt, consumedAt, createdBy | Single-use, short TTL, no raw token logged. |
| `chore_template` | id, householdId, title, category, icon, instructions, steps, locationTag, duePolicy, active, reviewMode, defaultAssigneeId | Template is not completion record. |
| `recurrence_rule` | templateId, timezoneIana, startLocal, endLocal?, freq, byWeekday, byMonthDay?, localDue, window, rotationId?, version | Preserve policy and preview changes; explicit DST and nonexistent dates. |
| `rotation` | id, eligibleActorIds, anchorLocalDate, order, rotationPolicy, exclusions, version | Assign deterministic future turns; don't retroactively rewrite history. |
| `chore_occurrence` | id, householdId, templateId, recurrenceVersion, localDateSlot, dueAtUtc, assignedActorIds, status, createdAt, completedAt?, approvedAt?, version | Unique instance key, authoritative status and timestamps; correct tenant isolation. |
| `completion_command` | commandId, occurrenceId, actorId, intendedAction, baseVersion, clientCreatedAt, serverAcceptedAt?, result | Idempotency + conflict reason; do not duplicate completion. |
| `approval_request` | occurrenceId, completedBy, reviewerIds, status, requestedAt, resolvedAt, resolution | Child cannot self-approve; guardian review not required by default. |
| `notification_job` | id, occurrenceId, eventType, targetActorId, scheduledAtUtc, deliveredAt?, dedupeKey, status | Unique idempotency key; account quiet hours; safe content. |
| `activity_event` | id, householdId, actorId, entityType, entityId, action, serverAt, metadataMinimal | No fake activity; immutable/audited where lawful. |
| `shopping_item` | id, householdId, title, quantity, unit, checked, addedBy, checkedBy, version | Household-only, revision-aware, P1. |
| `supply_item` | id, householdId, name, quantityApprox, threshold, locationTag, lastCheckedAt | Optional P1; no inventory claims based on guess. |
| `routine` | id, householdId, name, stepsTemplateIds, optionalDependencies, active | Bundle does not conflate independent task states, P1. |
| `preference` | actorId, householdId, quietHours, reminderMinutes, channelPreferences, language, childMode | Guardian protections + per-actor choices. |

## Suggested Firestore layout (exact security/rules to be validated)
```text
users/{uid}
users/{uid}/households/{householdId}               # server-maintained private discovery index
households/{householdId}
households/{householdId}/members/{actorId}
households/{householdId}/profiles/{actorId}
households/{householdId}/choreTemplates/{templateId}
households/{householdId}/recurrenceRules/{templateId}
households/{householdId}/rotations/{rotationId}
households/{householdId}/occurrences/{occurrenceId}
households/{householdId}/activity/{eventId}
households/{householdId}/shoppingItems/{itemId}
households/{householdId}/supplies/{itemId}
households/{householdId}/notificationJobs/{jobId}   # backend only
invites/{inviteId}                                # server only
pairedDevices/{opaqueDeviceId}                    # server only
commands/{commandId}                              # server only
pairings/{codeHash}                               # server only, expiring child approval
rateLimits/{uid}                                  # server only, transactional daily counters
households/{householdId}/invitations/{codeHash}     # guardian-only minimal status index
households/{householdId}/pairings/{codeHash}        # guardian-only minimal status index
households/{householdId}/devices/{deviceUid}        # guardian-only minimal device index
```

M05 discovery index: an account can list only its own index. Rules cannot safely
authorize that query by joining every result to a membership, so tenant data still
checks active membership independently. Membership revocation must atomically
remove the index (M06). An index never grants access or authority. Initial creation
atomically writes home/member/profile/index/audit/receipt and caps account creation
at five households to bound bootstrap abuse. This is a development policy pending
review of account lifecycle limits in M16.

M06 implements `members/{deviceUid}.actorId = childProfileId`: profile identity is
stable across device replacement; each device has separate revocable membership.
Adult memberships use their Auth UID as actor. Child assignment reads resolve this
server-owned mapping. Pairing retry proofs are hashed in private pairing records;
no hardware attestation or device public-key enrollment is claimed. See ADR-003
for actual token/retry/revocation behavior and the difference from a hardware key.

## Chore state machine
`scheduled` -> `in_progress` (optional) -> `completed` OR `pending_review` -> `approved`/`needs_redo`. Also `missed`, `cancelled`, `skipped` with explicit policy. A task can be marked overdue based on current time without falsely mutating its base completion state. Changes must be validated against current authoritative state. Map child UI labels: 'To do', 'Done', 'Waiting for review', 'Need help', 'Past due'. Use deterministic event and notification semantics.

## Specific invariants
- `occurrenceId = stableHash(householdId, templateId, recurrenceVersion, slotLocalDateTime, slotSequence)` or equivalent, collisions/test policy documented.
- For two-assignee team tasks, explicitly choose `any_one_completes` vs `all_members_complete` and store individual contributions if all required.
- Store UTC instants for ordering and household IANA zone for scheduling; on time-zone change show impact and re-materialize future slots only.
- A denied, revoked or expired member cannot see cached household data after local account change and cannot execute backend writes.
- If member removed from rotation, preserve historical assignment; future reallocation recorded as a rotation rule version change.
- Strongly prefer server-generated `createdAt`, acceptedAt, actor and audit role; sanitize user display text.
- System does not automatically equate a child age with chore capability.

## Data lifecycle
Define export schema, user/household deletion, retention, device logout cache erase, audit minimization and purging. Test guardianship changes, ownership transfer, last-admin prevention. Never store secrets or raw invite tokens in client-readable documents.

M07 one-off implementation: `choreTemplates` and `occurrences` are distinct stored
records. The occurrence snapshots content, assigned actor IDs, team/review policy,
requested schedule, effective household local times, IANA zone and UTC instants.
A stable once-slot ID plus a payload-bound receipt prevents duplicate instances.
Every edit checks both versions; cancellation preserves the occurrence and audit.
See ADR-004 for actual bounds, DST policy and the optional bundled illustration allowlist.

M08 recurrence storage adds `recurrenceRules/{templateId}/versions/{version}`,
immutable definitions and a bounded current/future effective-date timeline. Root
and version reads are adult-only; all writes remain trusted commands. Stable
household/template/date occurrence IDs preserve identity across rule versions.
Each occurrence records ordinal, planned actor, actual assignment, skip/substitute
reason, template/rule versions, requested/effective timing and a canonical content
hash. Future revisions audit prior/new assignees and status. Today's stored turn
and terminal work stay intact during automatic reconciliation.

`households/{hid}/schedulerLeases/{templateId}`, `schedulerState/recurrence` and
`schedulerFailures/{opaqueHash}` are server-only operational records. The worker
uses atomic per-rule work plus a global bounded scan/cursor. Deployment, index
rollout and live scheduler IAM are not implied by locally authored configuration.
See ADR-005 and M08 verification for actual evidence and remaining platform gates.
