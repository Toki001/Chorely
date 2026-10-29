# ADR-002 — Command and identity boundaries

Status: ACCEPTED for local implementation, 2026-10-29. Production deployment unapproved.

Use Flutter 3.47.5 / Dart 3.13.4 and Node 22 Firebase Functions. Dependencies
resolved from registry and pinned in lockfiles. Riverpod/GoRouter may be added
when state/routing complexity requires them; initial foundation uses Flutter
Listenable and repository injection to keep the same boundaries testable.

All persistent writes go through server commands, including household creation.
Rules permit narrowly scoped reads; no client writes. Server derives UID, role,
verification and provider from the verified token, never from request fields.
Membership status is read inside each transaction. Child device identities use
distinct custom-auth UIDs and a `scopedChild` claim; active membership and device
revocation checks remain authoritative even if the token claim is stale.

Guardian bootstrap requires verified non-anonymous account AND absence of child
scope. This is not proof of adulthood: reviewed product consent remains a release
gate. Shared-device child mode must sign out guardian and use separate scoped
credentials; no navigation-only gate. Pairing server flow must mint single-use,
hashed, expiring nonces, bind the approved actor, and revoke all paired memberships
on unlink. Child pairing endpoints are not implemented by this decision.

Server transaction command envelope: householdId, entityId, commandId (UUIDv4: 128-bit identifier with 122 random bits), baseVersion and action. Actor comes from token. Idempotency
receipt path is scoped by UID+command ID, includes canonical payload hash and
result; reusing an ID with a changed payload is rejected. Replayed accepted
commands recheck membership before returning receipt. Rate limits are transactional.
No attempt to execute transaction from offline mobile client.

Occurrence update, receipt, activity and notification job writes are atomic.
Stale versions return structured conflicts. Help is a separate request, not Done.
Team completion and five-minute undo follow PRD. Receipt retention must exceed
outbox replay horizon; expired command submissions rejected by protocol version
and maximum age once offline replay is implemented in M12.

Use demo project `demo-chorely` for emulators only. No default live project. Local
development app ID `dev.chorely.chorely` is provisional and not claimed owned.
Production app refuses emulator mode. Staging/prod config must be explicit and
fail closed until authorized. No deployment or billing action is implied.

Interfaces are in `functions/src/contracts.ts`; repository methods accept typed
commands and return accepted/conflict results. Rules tests assert query constraints,
cross-tenant denial, child scope and revoked membership. Rules do not constrain
Admin SDK; every future function must include independent authorization tests.

Sources checked 2026-10-29:
- https://firebase.google.com/docs/functions/callable — authenticated callable context
- https://firebase.google.com/docs/rules/unit-tests — emulated rules tests
- https://firebase.google.com/docs/firestore/manage-data/enable-offline — local cache is not conflict adjudication
- https://docs.flutter.dev/app-architecture/guide — separated UI/data/domain responsibilities
