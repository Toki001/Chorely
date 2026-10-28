# Chorely System Architecture — Proposed Baseline

## Decision principles
Chorely requires trustworthy multi-household, multi-device, guardian-controlled collaboration. An offline-only phone database is inadequate. Use Flutter native clients with a carefully isolated backend. Platform and vendor versions must be pinned only after actual repository/tool discovery.

## Proposed reference stack (validate with ADRs)
- **Mobile:** Flutter stable/Dart, Android + iOS; feature-first code structure.
- **Presentation/state:** Riverpod (or existing justified alternative), GoRouter for navigation. Separate UI/viewmodel/repository/service, keep business logic deterministic.
- **Backend:** Firebase Auth for adult accounts; Firebase Cloud Firestore for household-scoped documents and real-time listeners; Cloud Functions/Admin SDK for privileged role changes, child device pairing, complex transitions, reminder dispatch, idempotent jobs; FCM + platform local notifications.
- **Local:** Firestore cache for relevant documents; encrypted secure storage for session credentials; an explicit outbox (e.g. Drift/SQLite) only if offline commands and durable conflict handling require it. Evaluate app-lock/device access for supervised child profiles.
- **Testing:** Flutter test/widget/integration_test, Firebase Emulator Suite for Rules/Functions/E2E, golden tests, real Android device, iOS simulator and device when available.
- **CI:** GitHub Actions or current CI with pinned Flutter, deterministic dependency installs, checks, emulator-backed tests, artifact retention, security/dependency checks.

## Logical diagram
```text
Flutter iOS/Android (Parent/Adult/Child role-aware UI)
        | secure account/device auth, API/App Check where supported
        v
Authentication -> Household Authorization (Rules + callable/server functions)
        |                          |
        v                          v
Firestore household collections  Cloud Functions (trusted transitions)
        |                          |
  real-time listeners               +-- recurrence & rotation scheduler
        |                            -- invite / device pairing
  offline cache + outbox             -- notification dispatch/dedup
        |                            -- export/delete workflows
        +----------> Audit events <--+
                                     |
                                  FCM/APNs
```

## Domain & Flutter repository layout (proposed, respect existing)
```text
lib/
  app/               # bootstrap, env, router, themes, localization
  core/              # typed errors, clocks, IDs, security, local outbox
  features/
    onboarding/      # presentation/domain/data
    auth/
    households/
    family_members/
    chores/          # templates, occurrences, state transitions
    rotations/
    routines/
    calendar/
    notifications/
    shopping/
    supplies/
    activity/
    settings/
  shared/widgets/    # Chorely design components
functions/           # typed server functions, admin-only mutations, jobs
firestore.rules
firestore.indexes.json
test/                 # unit/widget/golden
integration_test/     # end-to-end Android/iOS
```

## Backend boundaries
- Untrusted client can request commands only; cloud functions validate auth, household ID, role, entity membership, allowed transitions, rate limits and write audit once.
- Reads and simple allowed document writes may be secured via Firestore Rules; privileged operations and nontrivial invariants belong in transactional server functions.
- Never trust client `isAdmin`, `householdId`, `childProfileId`, `approved` fields without server authorization.
- Server processes invite acceptance, role grants, protected approval, rotation modifications, idempotent completion, duplicate command suppression and sensitive data deletion.
- Deployment requires separate dev/staging/prod Firebase projects, rules tests and cost guardrails.

## Offline strategy
Firestore offline cache provides reads and replays but concurrent document edits may resolve last-write-wins. For chore completion and review, use explicit offline command outbox with stable UUIDs and server authoritative transitions/reconciliation, as detailed in `RECURRENCE_AND_SYNC.md`. Surface pending state and rejection reasons. Do not execute server transactions offline and pretend they committed.

## Reliability
- Households + members + child device links must be queryable only if authorized; explicit indexes; paginate events; archive history/retention policies.
- Implement event records (who/what/when) with server timestamps, actor IDs, prior/new states, and stable command IDs. No child geolocation/telemetry.
- Rate-limit invites and commands; stale tokens revocation; limits per household; cost alarms.
- Log no raw invite tokens, child's full name, task notes, unredacted PII or access secrets.

## Architectural decision points
A01 Firebase vs alternative managed backend; A02 child pairing auth scheme; A03 timeline materialization cadence (7/30 days) and DST policy; A04 durable offline command queue; A05 notification mechanisms; A06 data retention/deletion; A07 app store age policy; A08 planned monetization.
