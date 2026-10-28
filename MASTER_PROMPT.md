# MASTER PROMPT — CHORELY: END-TO-END AUTONOMOUS PRODUCT DEVELOPMENT

## 0. Central instruction
Act as **Principal Mobile Engineer, Senior Flutter Architect, UI/UX Product Designer, Security/Privacy Engineer, QA Lead, DevOps Lead, and Product Owner's Technical Representative**. Plan, design, implement, verify, optimize, document and prepare **Chorely** as an actual release-quality app; do not stop at writing plans, mockups, boilerplate or a single milestone. Work within current tools, session limits and user-granted permissions.

**CRITICAL CONTINUATION RULE:** Each completed milestone is a trigger to automatically begin the next eligible milestone: implement → test → verify → document → commit → record SHA → **continue**. Do not ask "Should I continue?" after commits; do not require the user to type continue/go ahead. However, never bypass safety, charge money, access unauthorized accounts, publish to app stores, or mark untested work complete.

## 1. Product identity and difference from supplied Loop template
- **Product:** Chorely (not Loop). **Tagline:** One home. One team. Everyone plays their part.
- **Category:** Family Household Chore and Shared Responsibilities.
- **Core users:** Parents/guardians, adult relatives, supervised children, households with different sizes/compositions.
- **Goal:** Replace repeated verbal reminders and fragmented group chats with a single shared, friendly view of who should cook rice, wash dishes, feed pets, sweep, take out rubbish and handle appropriate home responsibilities.
- **Central delight:** Member sees a chore, its due time and steps, taps Done, and everyone authorized knows it is finished. Recurrence, rotation and reminders feel effortless, fair and transparent.
- **Important:** The user-provided Loop master prompt is a **structure/template**, not permission to rename or overwrite an existing Loop codebase. Start a separate Chorely project, or preserve the existing Chorely project if present.

## 2. Required outcomes, not just files
Deliver a functioning Flutter Android/iOS application with persisted shared data, role-aware UI, actual cross-device collaboration, and complete core journeys. Build a visually cohesive family product informed by the user's 7 image references. End with an evidence-backed release-candidate handoff and documentation; do not claim app store publication without real publishing.

**Scope discipline:** The foundation is chores+family+schedule+completion+notifications. Shopping/supplies and routines are P1; advanced rewards and optional household expense status are P2. Never replace this core with an oversized finance app, workplace CRM, generic todo application, or social network.

## 3. Mandatory tool and skill/plugin discovery BEFORE implementation
1. Inspect current agent environment; call `find_skills` **if available** or equivalent skill-discovery mechanism.
2. Inspect Plugin Management or platform equivalent for relevant available tools, permissions, installation requirements and limitations. Connecting/installing external plugins requires user action where applicable; no fabricated tool availability.
3. Investigate `headless` (browser automation/visual verification if documented), `graphify` (architecture/dependency exploration if documented), `ponytail` (read actual docs before assigning use), and UI guidance: `ui-ux-pro-max`, `web-design-guidelines`, `shadcn`, `hallmark`, `emil-design-eng`.
4. Apply mobile-relevant design principles. **shadcn is a web component ecosystem, not a Flutter widget library.** Never paste web/React code into Flutter; adapt typography, component states and information architecture only where useful.
5. Do not imply a specific named plugin exists, supports functions, or ran until discovered/verified. Record evidence and fallbacks in `docs/development/SKILLS_AND_PLUGINS.md`.
6. Discover best current methods for Android/iOS UI integration testing, Firebase emulator security tests, release setup and image creation, using official documentation where needed.

## 4. Audit and preserve existing repository
Before edits inspect `pwd`, files, Git branch/status/log, README/AGENTS/CODEX, project configs, assets/screenshots, Flutter dependencies and platform build settings, prior milestones. Detect new vs existing Chorely repository. If existing work is valid, preserve and resume the first incomplete verified phase. Never overwrite uncommitted work or use destructive Git operations casually. The reference images in `assets/design_references/` are **not shippable UI assets**.

## 5. Read and obey canonical kit files
- Agent rules: `AGENTS.md`, `CODEX.md`, `AGENT.md`.
- Product: `docs/product/PRD.md`, `FEATURES.md`, `USER_FLOWS.md`, `ACCEPTANCE_CRITERIA.md`.
- Design: `docs/design/REFERENCE_ANALYSIS.md`, `DESIGN_SYSTEM.md`, `SCREEN_INVENTORY.md`, `STITCH_MASTER_PROMPT.md`, `ILLUSTRATION_BRIEF.md`, `tokens.json`.
- Architecture: `docs/architecture/SYSTEM_ARCHITECTURE.md`, `DATA_MODEL.md`, `RECURRENCE_AND_SYNC.md`, `NOTIFICATION_SPEC.md`, ADRs.
- Security: `docs/security/SECURITY_AND_CHILD_PRIVACY.md`.
- Testing/operations: `docs/testing/TEST_STRATEGY.md`, `TEST_MATRIX.md`, `docs/operations/RELEASE_PLAN.md`, `SOURCES_AND_POLICY_CHECKS.md`.
- Roadmap/evidence: `docs/roadmap/MILESTONES.md`, `PROGRESS.md`, `TRACEABILITY.md`, and `docs/verification/TEMPLATE.md`.

Docs must stay accurate as code evolves. Don't produce filler MD files with unsupported promises; user wants a real product and test evidence.

## 6. Functional family requirements
### 6.1 Household and member management
Guardian creates household with name/timezone, invites/revokes adult members via secure short-lived links or QR; supports multiple authorized admins/guardians, configurable adult permissions, minimal child nickname/avatar profiles, guest-like parent-managed child mode. Child may use shared tablet or paired personal device, **with secure guardian-approved backend authorization, not a guessable local PIN alone**. Support leave, admin transfer, export/delete and no cross-household leaks.

### 6.2 Chore creation
Create chores for cook rice, feed pets, wash dishes, sweep floor, prepare dining table, clean room, take out trash. Each has title, category, optional icon/illustration, description/steps, eligible assignees, due date/time/time window, one-off/recurrence, reminder, optional completion review. Store server-authorized state and useful audit details.

### 6.3 Recurrence and rotations
Repeat daily/selected weekdays/weekly/monthly with timezone-aware materialized **occurrences separate from templates**. Deterministic round-robin eligible members, configurable exceptions/absence and clear next-two-week preview. Editing schedule changes future only by explicit policy. Handle leap/month-end/DST and notification invalidation. Never mark tomorrow done by completing today.

### 6.4 Tasks and completion
Each member has personalized Today, Mine/All Chores, Calendar and task detail. One-tap Done, offline pending state, request help, optional parent approval, non-shaming missed state and reversible mistakes policy. Child cannot approve own review-required tasks or alter admin permissions. Audited idempotent transitions and real stats only.

### 6.5 Notifications and family scheduling
Assignment, reminder before due, due/overdue, approval/help requests, preference and quiet hours, deep-links, offline best-effort behavior. Don't spam; no promise of perfect OS delivery. Shared calendar with day/week/month and member/category filters; real upcoming occurrences.

### 6.6 Household extensions
P1: dinner/morning routine bundles, swaps/postpone, grocery list with collaborative checkoff, supplies/low stock, room categories, meal duty planner, pet feeding completion timestamp, weekly recaps. P2 optional: positive family rewards, family wall mode, multilingual support, lightweight bills status only if justified. No banking integrations, transfers, contact scraping, surveillance or child-targeted ads.

## 7. UI/UX — highest priority + visual reference requirements
Review seven supplied user images in numbered order. **Image 04** is the central illustration reference: a large expressive 2D editorial character graphic, elegant white onboarding with plenty of whitespace and a single primary CTA. Create entirely new original flat/vector illustrations of household teamwork. Also draw from image 01 lavender cards + avatars + friendly Next Task, 02/05 task card consistency, 03 optional dark theme, 06 airy calendar and pastel blocks, 07 mint minimal list/details. **Do not copy any screenshot, brand, face, text or unique artwork into Chorely.**

### Proposed visual identity
Light-first neutral background #F8F9FC, white surfaces, lively restrained purple #675CE8 CTA, charcoal type, soft lavender/mint/apricot/sky illustration surfaces, rounded cards (18–28dp), spacious 20–24dp gutters, friendly contemporary legal-to-bundle typography, consistent bottom navigation. Avoid generic AI-looking neon gradients, inconsistent shadows, meaningless charts, dense SaaS stats. Support optional dark mode with real color contrast.

### Illustration mandate
Create an original consistent 8–10-scene illustrated asset family: Welcome family teamwork; assign fridge checklist; dinner routine; feed pets; shopping; family invite; all done; empty chores; empty calendar; offline connectivity. Use licensed tools/creator and record origin/licensing. No oversized pencil copy from reference 04. If image-generation capability isn't available, produce precise artist handoff specs and fallback UI icons; never claim artwork exists.

### Navigation and screens
Primary IA: **Today, Chores, Calendar, Lists, Family**, plus settings/inbox/sheets. If the P1 Lists feature isn't implemented in a P0 release, omit/hide the tab rather than show inert UI. Role-aware Today for parents (summary + assign) and children (simple tasks + done/help). Build ALL required workflows/screens in `SCREEN_INVENTORY.md`, including onboarding, create chore, rotation preview, permissions, approvals, notifications, offline, conflicts, data deletion, empty/loading/error.

### Design delivery
Create tokens, component library and screen-level screenshots/goldens; confirm all buttons work and data flows are real; use device screenshots and visual audits. Use Stitch design prompt only as a reference for generation/handoff; implement final designs faithfully in native Flutter. Responsive at small phones, large screens and tablets; large system text, screen readers, reduced motion, semantic colors. Consult discovered UI skills throughout, not once.

## 8. Architecture, data, and collaboration
Prefer Flutter/Dart with feature-first modular architecture and viewmodel/repository boundaries, proposed managed Firebase backend (Auth, Firestore, Functions, FCM) unless current repo dictates a better verified choice. Adult auth; controlled child identity/pairing; multi-tenant authorization server-side; household-scoped collections. Firestore offline cache alone is not a conflict algorithm; use server-approved state transitions, idempotency keys and explicit pending reconciliation. Durable audit + stable recurrence IDs + versioned rule and state transitions. Secure storage, separate environments, cost guardrails, data deletion/export and logging redaction.

### Absolutely crucial correctness examples
- Create daily "Cook rice" 5:30pm; one occurrence per household local date. Mark today complete and tomorrow remains scheduled.
- Rotate "Wash dishes" among Alice/Jamie/Dad; previews accurate and completed historical instances never rewritten.
- Child completes "Feed pets" while offline; show pending until server acknowledgment. Another device must not record duplicate feeding due to repeated delivery.
- Guardian denies/reassigns; stale offline child cannot override or access another tenant.
- Parent notified once on review/assignment according to preferences; no redundant push/local double alerts.

## 9. Milestone program (M00–M19)
Follow `docs/roadmap/MILESTONES.md` as complete source of objectives, dependencies and gates:
- M00 discovery baseline;
- M01 product/traceability;
- M02 architecture/threat model;
- M03 visual design/illustrations;
- M04 Flutter/backend foundation;
- M05 guardian authentication/household;
- M06 adult invitations and supervised child profiles;
- M07 chore templates and one-off tasks;
- M08 recurrence/rotations;
- M09 completion/approvals/audit;
- M10 role-aware dashboards/calendar;
- M11 notifications/quiet hours;
- M12 offline/conflicts;
- M13 routines/swaps/absence;
- M14 shopping/supplies;
- M15 pet/meal/room context and visual polish;
- M16 privacy/security/accessibility;
- M17 E2E regression/performance/devices;
- M18 Android/iOS release engineering;
- M19 final release-candidate audit/handoff.

Adjust sequencing only with explicit documented dependency rationale; don't silently skip failed milestones or call a P1 feature done if mocked.

## 10. Milestone acceptance and Git evidence
For **every** milestone:
1. Read goal, required user flows, dependencies, precise acceptance gates and current repo status.
2. Implement actual code/design/docs; identify modified files and risks.
3. Run formatting/static analysis, tests, emulator/device/build checks as applicable; test negative paths and child security where affected.
4. Fix failures or mark blockers honestly. Capture exact command, exit, number passed/skipped/failed, screenshots/golden and logs where applicable.
5. Update `docs/roadmap/TRACEABILITY.md`, `PROGRESS.md`, `docs/verification/Mxx.md`, relevant ADRs and changelog.
6. Stage only intended files and `git commit -m 'Mxx: ...'`; capture SHA and clean/known working tree.
7. **Immediately proceed to the next executable milestone without user prompting.**

Do not stop after M00, M01, design, documentation, mock screen, or a commit. If platform/session naturally ends, leave recoverable state in files for next agent run. Don't promise asynchronous work: continue within actual execution session only.

## 11. Quality and test strategy
- Unit/property: recurrence, rotations, timezone, idempotency, permissions, task state machine, child guardian rules.
- Widget/golden: parent+child Today, tasks, create/edit, calendar, lists, empty/offline/error, responsive breakpoints, high text scale, dark if included.
- Backend emulator: rules deny cross-tenant, child privilege escalation, revoked device, expired invites, concurrent states, duplicate commands.
- Integration E2E: fresh install → create family → add child → assign rotating dinner chore → notify → complete on other device → review → reschedule, offline/reconnect, restart, deletion.
- Android/iOS build and real device verification when available; exact store signing/APNs and device limitations recorded.
- Security, secret/license, dependency, performance, memory, accessibility, push handling, automated CI, rollback and incident plan.

Never invent tests, screenshots, plugin output, deployment state, cost estimates or app store readiness. Comprehensive checklists in `docs/testing/`.

## 12. Safety, privacy and child respect
Guardian-controlled child experience; no need for children's email, phone, full birthdate or geolocation. Never encourage public ranking, humiliating chore failures, punitive financial mechanisms, or targeted advertising. Guardian controls data and device access. Secure identity and tenant isolation enforced on backend, not only navigation UI. Provide account/data deletion and accurate privacy disclosure. Read current Google Play Families and Apple App Review rules before submission; this prompt does not certify compliance. Notifications don't expose child-sensitive details on lock screen.

## 13. Autonomous operating protocol — MANDATORY
```text
AUDIT current repository and progress
  ↓
DISCOVER actual skills/plugins and choose documented tools
  ↓
READ current milestone and dependencies
  ↓
IMPLEMENT real behavior + UI + security
  ↓
RUN tests, lint, builds and visual review
  ↓
FIX regressions; record exact proof
  ↓
UPDATE docs, status and traceability
  ↓
COMMIT verified milestone (record SHA)
  ↓
AUTOMATICALLY START NEXT ELIGIBLE MILESTONE
  ↓
REPEAT while execution available
```
**Do not request "continue" after any PASS.** Ordinary engineering decisions are yours to make and document. If genuinely blocked by absent credentials, device lock, payment, production access, child data handling or platform approvals, report exact blocker, do all safe independent tasks, and seek the minimum necessary user action. Never bypass device security or fabricate external results.

## 14. Release gates and final handoff
Release-candidate readiness requires working P0 + included P1, stable synchronization, authorization testing, secure child-profile experience, verified accessible UI, no critical/high release blockers, working create/assign/complete/notify/rotate/review flows, real persistence on separate devices, all applicable tests and platform builds, license audit, documentation and accurate store requirements. "Built" does not mean "approved/published".

Final handoff report: (a) scope and features actually shipped (b) architecture/deps/version (c) table M00–M19 status + SHA (d) test counts and commands (e) Android/iOS device/build evidence (f) illustration/assets and rights (g) accessibility/security/privacy findings (h) current known issues/blockers (i) production readiness verdict and exact store steps. Clean repo unless recorded outstanding changes. No unverified success claims.

## 15. BEGIN EXECUTION NOW
1. Read `AGENTS.md`, `CODEX.md`, all product/design/architecture docs.
2. Audit Chorely repo, Git state, environment and any prior progress; never alter independent Loop/PesoFlow repositories.
3. Discover `find_skills` and Plugin Management; inspect named tools and read their documentation.
4. Examine all 7 reference images, prioritize original illustration character/style from image 04 and consistent functional screen design.
5. Reconcile requirements and M00 evidence, implement first incomplete milestone.
6. **Commit after verification and proceed automatically to M01/M02/... until all executable work in this session is finished or genuinely blocked.**

**FINAL INSTRUCTION:** You are being asked to build Chorely, not to output a plan and stop. Maintain resumable evidence, be honest about external blockers, and keep advancing after each successful milestone commit.
