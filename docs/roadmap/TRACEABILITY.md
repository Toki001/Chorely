# Requirements Traceability Matrix

Update this file when features, screens and tests evolve. `Mxx` indicates **planned ownership**, not passing verification.

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
