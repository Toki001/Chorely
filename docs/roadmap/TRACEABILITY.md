# Requirements Traceability Matrix

Update this file when features, screens and tests evolve. `Mxx` indicates **planned ownership**, not passing verification.

M02 evidence: AUTH-01, AUTH-02 and server-read SYNC-03 assertions run in
`backend-tests/rules.test.mjs` (6 passing cases). These do not establish function,
pairing, device-cache or full feature acceptance; see `docs/verification/M02.md`.

M04 evidence: native onboarding/adult auth shell in `integration_test/foundation_test.dart`;
five responsive/validation/error/accessibility widget cases in `test/app_test.dart`
and two visual baselines in `test/design_golden_test.dart`. These establish local
foundation behavior; household persistence and full authorization are M05 gates.

M05 evidence: H01/H04 and AUTH-01 use `backend-tests/callable.test.mjs` (real
Auth/Functions/Firestore clients) plus `backend-tests/households.test.mjs` for
transaction/replay/quota/revocation cases. `test/households_test.dart` checks
validation, retry identity, confirmed success and 320dp/200% text. Native creation
and restart checks live in `integration_test/household{,_restart}_test.dart`.

M06 evidence: H02/H03/H04/V04 map to `membership.test.mjs`, real invite/scoped-child
cases in `callable.test.mjs`, `test/family_test.dart` and native `family_test.dart`.
AUTH-04/05 cover recipient binding, expiry/replay/revocation; AUTH-02 covers scoped
identities, read constraints and stale-token denial. No camera hardware result is
inferred from code-entry tests. See M06 verification for exact counts and limits.

| Requirement | Design screen(s) | Milestone | Acceptance/QA |
|---|---|---|---|
| H01 Household setup | S03–S05 | M05 | AUTH-01, restart |
| H02 Invitations | S05, S21 | M06 | AUTH-04 |
| H03 Child profiles/device pairing | S06–S07, S10 | M06 | AUTH-02, AUTH-05 |
| H04 Role authorization | S21–S22 | M05–M06/M16 | AUTH-01–05 |
| C01–02 Chore template / assignment | S11–S14 | M07 | CHORE-01 |
| C03 Time windows | S12–S14 | M07 | CHORE-05 |
| C04 Recurrence | S15 | M08 | CHORE-02, CHORE-05–07 |
| C05 Rotation | S15 | M08 | CHORE-08–09 |
| C06 Completion / idempotency | S10–S14 | M09 | CHORE-02–03, SYNC-02 |
| C07 Approval | S26 | M09 | CHORE-04 |
| C08 Instructions | S14 | M07 | UI-02 |
| C09 Swap/postpone | S27–S28 | M13 | CHORE-09 |
| C10 Routines | S16 | M13 | CHORE-10 |
| C11 Room boards | S11 | M15 | Widget/integration |
| N01–N02 Notifications | S25, S23 | M11 | NOTIF-01–05 |
| V01 Today | S09–S10 | M10 | UI-01–04 |
| V02 Chores | S11–S14 | M07/M10 | UI-01–04 |
| V03 Calendar | S17–S18 | M10 | CHORE-05, UI-03 |
| V04 Family | S21–S22 | M06/M10 | AUTH-01–05 |
| V05 Activity | S24 | M09 | CHORE-03 |
| L01 Shopping | S19 | M14 | LIST-01 |
| L02 Supplies | S20 | M14 | Sync/permission tests |
| L03 Meal duty / L04 Pet care | S14/S16 | M15 | Domain + UX tests |
| R01 Rewards | S39 | P2 optional | Privacy review |
| R02 Recap | S09/S24 | M15 | Actual occurrence counts |
| I01 Localization | All | P2 optional | Pseudolocalization |
| I02 Original illustrations | S02/S34/S35 | M03/M15 | Rights + golden review |
| Privacy export/delete | S30 | M16 | DATA-01–02 |
| Offline sync / conflicts | S31–S32 | M12 | SYNC-01–03 |
| Release | All | M17–M19 | PERF-01, build/store check |

## P0 release gate mapping — M01

All entries are planned tests, not verification claims. Feature priorities come from FEATURES.md.

| Requirement | User flow | Screen | Owner | Planned tests |
|---|---|---|---|---|
| H01 | F01/F11/F12 | S04/S23/S29/S30 | M05/M16 | AUTH-01/DATA-01 |
| H02 | F02 | S05/S21 | M06 | AUTH-04 |
| H03 | F03/F09 | S06/S07/S10 | M06/M12 | AUTH-02/AUTH-05/SYNC-03 |
| H04 | F12 | S21/S22/S33 | M05/M06 | AUTH-01/AUTH-02/AUTH-03 |
| C01 | F04 | S11/S12/S13 | M07 | CHORE-01 |
| C02 | F04/F06 | S12/S14 | M07/M09 | CHORE-10/AUTH-03 |
| C03 | F04/F13 | S12/S14/S17 | M07 | CHORE-05/CHORE-07 |
| C04 | F05 | S15 | M08 | CHORE-02/CHORE-05/CHORE-06/CHORE-07 |
| C05 | F05 | S15 | M08 | CHORE-08/CHORE-09 |
| C06 | F06/F07/F14 | S10/S14/S24/S27 | M09 | CHORE-03/CHORE-11/SYNC-02 |
| C07 | F14 | S26 | M09 | CHORE-04/AUTH-02 |
| C08 | F04/F06 | S12/S14 | M07 | UI-02/ASSET-01 |
| N01 | F15 | S08/S25 | M11 | NOTIF-01/NOTIF-02/NOTIF-04/NOTIF-05 |
| N02 | F15 | S23 | M11 | NOTIF-03 |
| V01 | F13 | S09/S10/S34 | M10 | UI-01/UI-02/UI-03/UI-04 |
| V02 | F13 | S11/S14 | M07/M10 | UI-01/UI-02/UI-03 |
| V03 | F13 | S17/S18/S35 | M10 | CHORE-05/UI-01/UI-03 |
| V04 | F02/F03/F12 | S21/S22 | M06/M10 | AUTH-01/AUTH-02/AUTH-05 |
| V05 | F14 | S24 | M09 | CHORE-03/CHORE-04 |
| I02 | F16 | S02/S34/S35 | M03/M15 | ASSET-01/UI-03/UI-04 |
| Offline/conflicts | F09 | S31/S32 | M12 | SYNC-01/SYNC-02/SYNC-03 |
| Privacy lifecycle | F11 | S23/S29/S30 | M16 | DATA-01/DATA-02 |
| Accessible states | F16 | S31/S32/S33/S36/S37/S38 | M03/M16 | UI-01/UI-02/UI-03 |
| Release | F01–F16 | All P0 | M17/M18/M19 | PERF-01/DATA-02 |

M07 implementation evidence (verification gate tracked in M07.md): C01/C02/C03
and text C08 use `functions/src/chores.ts`, `local_time.ts`, `backend-tests/chores.test.mjs`
and the real Cook rice/scoped-assignee case in `callable.test.mjs`. Native UI is
`features/chores` with retry/conflict/large-text/assignee tests in `test/chores_test.dart`.
`integration_test/chores{,_restart}_test.dart` checks guardian creation, child details,
edit, fresh process persistence and cancellation. Completion/review execution is
M09; C08 includes text steps and an optional allowlisted original bundled scene with
an accessible label, per PRD. External uploads are outside the initial slice.
No offline outbox acceptance is claimed here.

M08 evidence: C04/C05/CHORE-05–09 map to `recurrence_engine.ts`,
`recurrence_service.ts`, `recurrence_worker.ts`, scoped callable/rule reads and
11 engine/12 service cases within the 58-case backend suite. Four recurrence
widgets verify preview gating/invalidation, frozen retries, large text and controls.
Native `rotation{,_restart}_test.dart` verifies all fourteen ordered preview turns,
thirty stored dates, fresh-process settings and a future pause with preserved
history. M07 native creation/child-read/edit/restart/cancel also regresses green.
The local loopback timer invokes the same bounded worker as the authored scheduled
entry point. Deployed scheduler/IAM/index rollout, household timezone setting UI,
physical devices and Android runtime are explicitly not verified. See M08.md.

M09 evidence: C06/C07/CHORE-02–04/CHORE-11 map to `completion.ts`, twelve
completion service cases and expanded real two-device/guardian/private-help
coverage within 70 backend tests. Six action widgets verify frozen retries, stored
progress, self-review fencing, private notes and large text. Native
`completion{,_restart}_test.dart` passes help/complete/undo/resubmit, actual callable
self-review denial, guardian acknowledgement/approval and persisted history. The
runner asserts one current contribution, seven accepted events and one private
denial record. Both rotation and one-off native regressions pass. See M09.md for
exact counts, evidence and remaining offline/device/release gates.

M10 implementation evidence: V01–V04/S09–S11/S17–S18/S21 map to
`features/dashboard`, `household_clock.ts`, the scoped range index and live
membership guards. `calendar_dates_test.dart` covers civil dates and
`dashboard_test.dart` covers stored progress, day/member/status filters,
selected-date creation, recovery and parent/child journeys at 320/800dp with
200% text. Four pure clock cases and real bounded child/guardian range queries
extend the backend suite to 74 cases. Native calendar/progress checks extend the
existing completion and restart journeys; phone/tablet journeys and fresh-process reads pass. One-off and rotation native
regressions also pass; 44 Flutter cases and 74 backend cases pass the final
verification script. Exact evidence and release/device limits are in M10.md.

M11 local evidence: N01/N02, S23/S25 and NOTIF-01–05 map to
`notification_{assignment,time,plan,preferences,jobs,worker}.test.mjs`, actual
Auth/Functions/Firestore assertions in `callable.test.mjs`,
`test/{notifications,device_reminders}_test.dart` and native
`integration_test/{notifications,notification_cold_start}_test.dart`. These cover
quiet-hour/DST boundaries, stable logical IDs, re-enabled policies, bounded sweeps,
private child scope, monotonic reads, cancellation, permission-denial fallback,
uncertain retry/restart, identity changes, cold authorized route and deleted-target
fallback. The native cold route injects opaque IDs and still requires persisted
Auth/server access. Provider dispatch/FID rotation, physical OS permission and
terminated/reboot delivery remain unverified external/device gates; M11 is
PARTIAL, never evidence of production push acceptance/delivery. Details and
screenshots are in `docs/verification/M11.md`.
