# Chorely Development Progress — Authoritative Tracker

**Project status:** IN PROGRESS. M00 baseline verified; app implementation follows the gates below.

**Current branch:** main (new repository). **Current commit:** see Git log; milestone hashes recorded after each commit.

| Milestone | Status | Commit SHA | Verified on | Evidence | Blockers |
|---|---|---|---|---|---|
| M00 | PASS | 66197519871eb2c037566f9cb52428f32f915555 | 2026-10-29 | `docs/verification/M00.md` | No Android AVD; production configuration absent |
| M01 | PASS | 9a7d5562fc767b2da083e50a676bef2495c322fc | 2026-10-29 | `docs/verification/M01.md` | Runtime gates remain planned |
| M02 | PASS | c607f3f22003ec2185099fc6e35c6c6c893c7c29 | 2026-10-29 | `docs/verification/M02.md` | 3 moderate dev-tool advisories tracked; runtime clean |
| M03 | PASS | f8661f0901a220a7c4527ccc8f21daa8756b947e | 2026-10-29 | `docs/verification/M03.md` | Release asset review remains M16/M18 |
| M04 | PASS | 53af9e0bdd424c79707f84324aa032645e35c99c | 2026-10-29 | `docs/verification/M04.md` | Local demo configuration only; no Android AVD or live signing |
| M05 | PASS | 85f7c0e1761d5ac3d91f0597b40b2bc127e1c9cd | 2026-10-29 | `docs/verification/M05.md` | Verified only on demo emulators; live account/consent review remains |
| M06 | PASS | pending commit | 2026-10-29 | `docs/verification/M06.md` | Physical QR/camera, Android runtime and release credentials unverified |
| M07 | PLANNED | — | — | `docs/verification/M07.md` (to create) | — |
| M08 | PLANNED | — | — | `docs/verification/M08.md` (to create) | — |
| M09 | PLANNED | — | — | `docs/verification/M09.md` (to create) | — |
| M10 | PLANNED | — | — | `docs/verification/M10.md` (to create) | — |
| M11 | PLANNED | — | — | `docs/verification/M11.md` (to create) | — |
| M12 | PLANNED | — | — | `docs/verification/M12.md` (to create) | — |
| M13 | PLANNED | — | — | `docs/verification/M13.md` (to create) | — |
| M14 | PLANNED | — | — | `docs/verification/M14.md` (to create) | — |
| M15 | PLANNED | — | — | `docs/verification/M15.md` (to create) | — |
| M16 | PLANNED | — | — | `docs/verification/M16.md` (to create) | — |
| M17 | PLANNED | — | — | `docs/verification/M17.md` (to create) | — |
| M18 | PLANNED | — | — | `docs/verification/M18.md` (to create) | — |
| M19 | PLANNED | — | — | `docs/verification/M19.md` (to create) | — |

## Handoff rules

- After each verification, update the row, exact evidence and current next milestone.
- The next session must inspect `git status`, `git log`, latest verification, required tools and environment.
- Never claim PASS from a document title, prior chat, or the existence of code alone.
- If a previous run stopped halfway, inspect uncommitted work before continuing; don’t reset.
- After PASS+commit, immediately continue to next eligible milestone if execution still available.
