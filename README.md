# Chorely — Complete Development Kit

**Product:** Chorely | **Tagline:** One home. One team. Everyone plays their part.
**Target:** Families and shared households, with parent/guardian administration and child-friendly supervised experiences.
**Platform:** Flutter/Dart for Android and iOS. **Status:** Native Flutter app in development, using a real local Firebase emulator backend. Verified milestones and remaining gates are recorded in [`PROGRESS.md`](docs/roadmap/PROGRESS.md). This is not a verified release.

Run the app with [`LOCAL_DEVELOPMENT.md`](docs/development/LOCAL_DEVELOPMENT.md). The supplied product/design kit remains the canonical requirements source.

## Start here

1. Extract this ZIP into a **new Chorely repository** (or copy it to the root of an existing Chorely repository after reviewing changes). **Do not replace or rename any existing Loop application by default**; Loop is the user-supplied *prompt template*, not the target project.
2. Keep `assets/design_references/` available locally for design study, but **do not ship those reference images, trace them, or reuse their proprietary artwork in the app** without proper rights.
3. Open the repository in Codex and paste `MASTER_PROMPT.md` or `prompts/CODEX_LAUNCH_PROMPT.md`.
4. For generating high-fidelity screen designs in Stitch, use `docs/design/STITCH_MASTER_PROMPT.md` and attach the 7 reference images in numbered order.
5. Codex must inspect any current code, detect installed skills/plugins, implement one milestone at a time, verify, commit, and advance automatically while execution continues. If blocked on external actions, record the exact blocker and continue independent tasks.
6. Review docs and decisions with a human before store publication, billing, access to production data, third-party account connections, or creating children's accounts.

## Core documentation map

| Topic | Canonical source |
|---|---|
| Autonomous build instructions | `MASTER_PROMPT.md`, `AGENTS.md`, `CODEX.md` |
| Scope and product behavior | `docs/product/PRD.md`, `FEATURES.md`, `USER_FLOWS.md` |
| Visual direction and illustration requirements | `docs/design/DESIGN_SYSTEM.md`, `REFERENCE_ANALYSIS.md`, `ILLUSTRATION_BRIEF.md` |
| Screen-by-screen instructions for Stitch | `docs/design/STITCH_MASTER_PROMPT.md`, `SCREEN_INVENTORY.md` |
| System, data, recurrence and sync | `docs/architecture/SYSTEM_ARCHITECTURE.md`, `DATA_MODEL.md`, `RECURRENCE_AND_SYNC.md` |
| Roles, child safety and privacy | `docs/security/SECURITY_AND_CHILD_PRIVACY.md` |
| Notifications | `docs/architecture/NOTIFICATION_SPEC.md` |
| Phases and evidence | `docs/roadmap/MILESTONES.md`, `TRACEABILITY.md`, `PROGRESS.md`, `docs/verification/` |
| Tests and release | `docs/testing/TEST_STRATEGY.md`, `docs/operations/RELEASE_PLAN.md` |

## Non-negotiables
- All 5 primary views must correspond to real user journeys: **Today, Chores, Calendar, Lists, Family**.
- Family management is **not a workplace project management clone**; use household terminology, real chore data, helpful illustrations, and inclusive family roles.
- Multi-device collaboration requires an actual authenticated backend. Locally mocked flows can be used only in development tests, never presented as production-complete features.
- Children's profiles must use guardian-controlled onboarding, least privilege, data minimization, and no unnecessary analytics or ads.
- Preserve the ability to use the app without paying. Essentials (assign, remind, complete) must not be paywalled.
- Every required feature must have tests and documented acceptance evidence; don't assert zero bugs or store approval without real verification.

## Bundled inspiration assets
The seven user-supplied reference images are preserved under `assets/design_references/` in the user's original display order. These are for internal inspiration/reference analysis only.

## Licensing and images
Illustration instructions are detailed in `docs/design/ILLUSTRATION_BRIEF.md`. Codex may generate **new, original, properly licensed artwork** using available legitimate asset-generation tools, but must not reuse or ship the attached UI screenshots or extract their artwork into Chorely.
