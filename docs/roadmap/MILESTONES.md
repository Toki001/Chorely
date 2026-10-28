# Master Milestone Roadmap — M00 to M19

**Execution policy:** Every completed milestone requires verification evidence, documentation update, clean scoped Git commit, commit SHA recorded in `PROGRESS.md`, and **automatic start of the next eligible milestone**. Do not stop to seek ordinary continuation approval. Respect blockers and human-only actions.

**Status is initially `PLANNED` for every milestone.** This kit does not mean app code exists or milestones passed.

| Milestone | Phase | Deliverable | Objective verification |
|---|---|---|---|
| M00 | Discovery and Baseline | Repository, tooling, Git and uploaded assets audit | Existing tracked files preserved; baseline evidence; no destructive changes |
| M01 | Product Definition | Complete Chorely PRD, flow and traceability | Every P0 requirement maps to user flow, feature ID, planned test and screen |
| M02 | Architecture and Threat Model | Security-first multi-user architecture and data schema | Firestore emulator threat test skeleton, decisions recorded and interfaces specified |
| M03 | Design System and Assets | Tokens, illustrations, components, visual review | Design tokens approved; original art licenses; semantic/touch target design audit |
| M04 | Flutter and Backend Foundation | App shell + dev/staging configuration | Clean install, run on supported emulator/device; format/analyze/tests pass |
| M05 | Guardian Auth and Household Setup | Adult sign-in, create household, tenant isolation | Cross-tenant deny tested; real household persists after restart |
| M06 | Family Membership and Child Profiles | Invites, profiles, supervised device access | Invite replay denied; child cannot elevate privileges; parent/child mode tested |
| M07 | Chore Templates and One-off Assignment | Real chore CRUD and task details | Guardian creates Cook Rice task; assignee sees it; saved across devices |
| M08 | Recurrence and Rotation Engine | Reliable schedules and automatic turns | Daily/weekday/monthly/DST and 14-day rotation deterministic; no duplicate instances |
| M09 | Completion, Review and Audit | Correct status transitions and activity | Two-device completion once, child review cannot self-approve, history accurate |
| M10 | Calendar and Family Dashboard | Today, Chores, Calendar, Family experiences | Parent and child can complete essential journey on small phone and tablet |
| M11 | Notifications and Quiet Hours | Assignment, due and overdue notifications | Permission denial graceful; no duplicates; cold-start route tested; platform limits recorded |
| M12 | Offline Collaboration and Recovery | Durable outbox and robust sync reconciliation | Offline command acknowledged or conflicts visibly; no misleading synced success |
| M13 | Routines and Flexible Scheduling | Dinner routines, swap/help, postpone, away | Routine completion independent; swaps auditable; old reminders cancelled |
| M14 | Shared Lists and Supplies | Groceries and household replenishment | Concurrent adds/checks converge; cross-tenant permissions enforced |
| M15 | Polish and Advanced Family Context | Pet, meal, room boards, recaps (within scope) | Only real usage data; workflows run end to end; all artwork original or licensed |
| M16 | Privacy, Security and Accessibility Audit | Hardening and compliance preparation | No known critical/high security flaws; privacy text and deletion tested |
| M17 | End-to-end QA and Performance | Comprehensive regression and devices | All required tests recorded; platform coverage and blockers honestly stated |
| M18 | Release Engineering and Store Materials | Android/iOS RC builds and metadata | Reproducible build where environment permits; secrets not committed |
| M19 | Final Readiness and Handoff | Evidence-backed release-candidate decision | Green gates only if actually verified; final summary, clean repo, commit log |

## Per-milestone contract

1. Read canonical requirements, dependencies, user stories, platform conditions, and past commit evidence.
2. Implement feature/code/config/design in small reviewable units, updating tests before claiming done.
3. Verify in emulator/unit/widget/golden/integration/device as relevant; log commands and counts.
4. Security review and per-member permissions review; child-profile scope checked for impacted features.
5. Record screenshots, logs, CI evidence, known limitations, and traceability links.
6. Commit `Mxx: <clear verified deliverable>`; record SHA and verify working tree.
7. **Start next eligible Mxx automatically** without asking user to type `continue`. If a task is blocked on human credentials, progress independent milestones and document blocked items.

## Dependency order

M00→M01→M02; M03 and M04 may overlap only after core architecture/design tokens are stable. M05→M06→M07→M08→M09 form the reliable core. M10 uses prior core. M11/M12 integrate as technical prerequisites for claiming multi-device reliability. M13–M15 are phase expansions. M16–M19 are hardening and release. Design and security tests run continuously, not only in their own milestones.

## Milestone detail and acceptance

### M00 — Discovery and Baseline
**Deliverable:** Repository, tooling, Git and uploaded assets audit.
**Implementation:** Document current state; run baseline commands; preserve work; record skill/plugin inventory.
**Acceptance gate:** Existing tracked files preserved; baseline evidence; no destructive changes.
**Evidence:** `docs/verification/M00.md` includes commands, exit statuses, test counts, screenshots/logs (as appropriate), unexpected failures, security/privacy review, blockers, code paths, SHA, and next action.

### M01 — Product Definition
**Deliverable:** Complete Chorely PRD, flow and traceability.
**Implementation:** Finalize personas, P0/P1/P2, consent/permissions, real-world household scenarios, acceptance criteria.
**Acceptance gate:** Every P0 requirement maps to user flow, feature ID, planned test and screen.
**Evidence:** `docs/verification/M01.md` includes commands, exit statuses, test counts, screenshots/logs (as appropriate), unexpected failures, security/privacy review, blockers, code paths, SHA, and next action.

### M02 — Architecture and Threat Model
**Deliverable:** Security-first multi-user architecture and data schema.
**Implementation:** Choose pinned stack; tenant rules; child pairing design; state machines, timezone & conflict policies; ADRs.
**Acceptance gate:** Firestore emulator threat test skeleton, decisions recorded and interfaces specified.
**Evidence:** `docs/verification/M02.md` includes commands, exit statuses, test counts, screenshots/logs (as appropriate), unexpected failures, security/privacy review, blockers, code paths, SHA, and next action.

### M03 — Design System and Assets
**Deliverable:** Tokens, illustrations, components, visual review.
**Implementation:** Analyze seven references; build tokens and cross-platform UI primitives; commission/generate original illustration assets with rights.
**Acceptance gate:** Design tokens approved; original art licenses; semantic/touch target design audit.
**Evidence:** `docs/verification/M03.md` includes commands, exit statuses, test counts, screenshots/logs (as appropriate), unexpected failures, security/privacy review, blockers, code paths, SHA, and next action.

### M04 — Flutter and Backend Foundation
**Deliverable:** App shell + dev/staging configuration.
**Implementation:** Scaffold Flutter, packages, environments, auth client, router, theming, backend emulator, CI.
**Acceptance gate:** Clean install, run on supported emulator/device; format/analyze/tests pass.
**Evidence:** `docs/verification/M04.md` includes commands, exit statuses, test counts, screenshots/logs (as appropriate), unexpected failures, security/privacy review, blockers, code paths, SHA, and next action.

### M05 — Guardian Auth and Household Setup
**Deliverable:** Adult sign-in, create household, tenant isolation.
**Implementation:** Account sign-in/out, household creation, timezones, role enforcement, initial empty states.
**Acceptance gate:** Cross-tenant deny tested; real household persists after restart.
**Evidence:** `docs/verification/M05.md` includes commands, exit statuses, test counts, screenshots/logs (as appropriate), unexpected failures, security/privacy review, blockers, code paths, SHA, and next action.

### M06 — Family Membership and Child Profiles
**Deliverable:** Invites, profiles, supervised device access.
**Implementation:** Adult invites, revocation, guardian roles; child nickname/avatar, guardian-approved pairing and revocation.
**Acceptance gate:** Invite replay denied; child cannot elevate privileges; parent/child mode tested.
**Evidence:** `docs/verification/M06.md` includes commands, exit statuses, test counts, screenshots/logs (as appropriate), unexpected failures, security/privacy review, blockers, code paths, SHA, and next action.

### M07 — Chore Templates and One-off Assignment
**Deliverable:** Real chore CRUD and task details.
**Implementation:** Presets, category, instructions, due time/window, assignee, completion policy, errors.
**Acceptance gate:** Guardian creates Cook Rice task; assignee sees it; saved across devices.
**Evidence:** `docs/verification/M07.md` includes commands, exit statuses, test counts, screenshots/logs (as appropriate), unexpected failures, security/privacy review, blockers, code paths, SHA, and next action.

### M08 — Recurrence and Rotation Engine
**Deliverable:** Reliable schedules and automatic turns.
**Implementation:** Rule versioning, occurrence materialization, fairness preview, timezone, edge-case tests.
**Acceptance gate:** Daily/weekday/monthly/DST and 14-day rotation deterministic; no duplicate instances.
**Evidence:** `docs/verification/M08.md` includes commands, exit statuses, test counts, screenshots/logs (as appropriate), unexpected failures, security/privacy review, blockers, code paths, SHA, and next action.

### M09 — Completion, Review and Audit
**Deliverable:** Correct status transitions and activity.
**Implementation:** Done/undo, pending approval, help, audit trail, idempotent commands.
**Acceptance gate:** Two-device completion once, child review cannot self-approve, history accurate.
**Evidence:** `docs/verification/M09.md` includes commands, exit statuses, test counts, screenshots/logs (as appropriate), unexpected failures, security/privacy review, blockers, code paths, SHA, and next action.

### M10 — Calendar and Family Dashboard
**Deliverable:** Today, Chores, Calendar, Family experiences.
**Implementation:** Role-aware day overview, calendar views and filters, actual stats, member avatars.
**Acceptance gate:** Parent and child can complete essential journey on small phone and tablet.
**Evidence:** `docs/verification/M10.md` includes commands, exit statuses, test counts, screenshots/logs (as appropriate), unexpected failures, security/privacy review, blockers, code paths, SHA, and next action.

### M11 — Notifications and Quiet Hours
**Deliverable:** Assignment, due and overdue notifications.
**Implementation:** FCM/APNs setup, local best-effort reminders, dedup, deep links, preferences.
**Acceptance gate:** Permission denial graceful; no duplicates; cold-start route tested; platform limits recorded.
**Evidence:** `docs/verification/M11.md` includes commands, exit statuses, test counts, screenshots/logs (as appropriate), unexpected failures, security/privacy review, blockers, code paths, SHA, and next action.

### M12 — Offline Collaboration and Recovery
**Deliverable:** Durable outbox and robust sync reconciliation.
**Implementation:** Cache, pending states, conflict resolutions, process termination and revoked access tests.
**Acceptance gate:** Offline command acknowledged or conflicts visibly; no misleading synced success.
**Evidence:** `docs/verification/M12.md` includes commands, exit statuses, test counts, screenshots/logs (as appropriate), unexpected failures, security/privacy review, blockers, code paths, SHA, and next action.

### M13 — Routines and Flexible Scheduling
**Deliverable:** Dinner routines, swap/help, postpone, away.
**Implementation:** Grouped steps, schedule changes, reassign requests, guardian review, exception handling.
**Acceptance gate:** Routine completion independent; swaps auditable; old reminders cancelled.
**Evidence:** `docs/verification/M13.md` includes commands, exit statuses, test counts, screenshots/logs (as appropriate), unexpected failures, security/privacy review, blockers, code paths, SHA, and next action.

### M14 — Shared Lists and Supplies
**Deliverable:** Groceries and household replenishment.
**Implementation:** Synced lists, quantities, checked status, supply thresholds and basic inventory.
**Acceptance gate:** Concurrent adds/checks converge; cross-tenant permissions enforced.
**Evidence:** `docs/verification/M14.md` includes commands, exit statuses, test counts, screenshots/logs (as appropriate), unexpected failures, security/privacy review, blockers, code paths, SHA, and next action.

### M15 — Polish and Advanced Family Context
**Deliverable:** Pet, meal, room boards, recaps (within scope).
**Implementation:** Context views, genuine recaps, icons/illustrations, refine accessible flow.
**Acceptance gate:** Only real usage data; workflows run end to end; all artwork original or licensed.
**Evidence:** `docs/verification/M15.md` includes commands, exit statuses, test counts, screenshots/logs (as appropriate), unexpected failures, security/privacy review, blockers, code paths, SHA, and next action.

### M16 — Privacy, Security and Accessibility Audit
**Deliverable:** Hardening and compliance preparation.
**Implementation:** Abuse suite, guardian delete/export, permissions, screen reader/large text, no child ads.
**Acceptance gate:** No known critical/high security flaws; privacy text and deletion tested.
**Evidence:** `docs/verification/M16.md` includes commands, exit statuses, test counts, screenshots/logs (as appropriate), unexpected failures, security/privacy review, blockers, code paths, SHA, and next action.

### M17 — End-to-end QA and Performance
**Deliverable:** Comprehensive regression and devices.
**Implementation:** Automation, screenshots, memory/performance, interrupted lifecycle, data migrations.
**Acceptance gate:** All required tests recorded; platform coverage and blockers honestly stated.
**Evidence:** `docs/verification/M17.md` includes commands, exit statuses, test counts, screenshots/logs (as appropriate), unexpected failures, security/privacy review, blockers, code paths, SHA, and next action.

### M18 — Release Engineering and Store Materials
**Deliverable:** Android/iOS RC builds and metadata.
**Implementation:** CI/CD, signing paths, store screenshots with fictional data, licenses, rollout and rollback.
**Acceptance gate:** Reproducible build where environment permits; secrets not committed.
**Evidence:** `docs/verification/M18.md` includes commands, exit statuses, test counts, screenshots/logs (as appropriate), unexpected failures, security/privacy review, blockers, code paths, SHA, and next action.

### M19 — Final Readiness and Handoff
**Deliverable:** Evidence-backed release-candidate decision.
**Implementation:** Final traceability audit, documentation, demo walkthrough, remaining blockers, next steps.
**Acceptance gate:** Green gates only if actually verified; final summary, clean repo, commit log.
**Evidence:** `docs/verification/M19.md` includes commands, exit statuses, test counts, screenshots/logs (as appropriate), unexpected failures, security/privacy review, blockers, code paths, SHA, and next action.

## Handling blocked milestones

Never commit a milestone marked PASS when essential steps are unverified. Mark it `BLOCKED`/`PARTIAL` with exact reason and committed verified independent work if safe. Do not misrepresent locked devices, missing Apple signing, unavailable APNs credentials, missing paid services, or store submission as complete.

## Scope control

Product owner can revise P1/P2 features before implementation. Do not silently delete P0 requirements. P2 features are not required for the initial RC unless promoted with documented decision.
