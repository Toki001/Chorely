# AGENTS.md — Codex Operating Contract for Chorely

Read `MASTER_PROMPT.md` and all canonical docs before changing code. **Product is Chorely, not Loop**. This is a family household chore coordinator. The uploaded Loop prompt is a structural reference only.

## Execution contract
1. Inspect repo, branch, unstaged changes, deps, tests, platform setup, prior milestone evidence. Preserve existing work and user changes. Never reset or force-push destructively.
2. Discover `find_skills` (or installed equivalent) and Plugin Management and read actual available descriptions before use; inspect `headless`, `graphify`, `ponytail`, `ui-ux-pro-max`, `web-design-guidelines`, `shadcn`, `hallmark`, `emil-design-eng` if present. Do not invent availability. Log discovered roles, limitations and substitutions.
3. Use `docs/roadmap/MILESTONES.md` and `docs/roadmap/PROGRESS.md` as sources of truth. Implement smallest next eligible unit that satisfies acceptance criteria.
4. Run format, analyze, test, security and build checks relevant to the milestone. Fix failures. Update verification report, traceability and progress. Commit **only verified milestone work** with a descriptive message and record its hash.
5. **Immediately continue** to next eligible milestone after commit; do not ask user to say continue. Do not let session updates or context limits masquerade as project completion. Document state durably for resumption.
6. When blocked on account credentials, store signing, external approvals or inaccessible device, don't bypass; record BLOCKED, continue independent milestones, ask for user action only when genuinely necessary.
7. Never automatically push, publish, spend money, connect external accounts, alter live resources, or process actual minors' personal data without authorization.

## Domain invariants
- Household-scoped multi-tenant isolation; only server-enforced authorized members can access data.
- Parent/guardian/admin controls household membership and child devices; do not collect children's email or date of birth by default.
- Chore template ≠ concrete occurrence. One occurrence per scheduled slot with stable deduplication key. Completing an occurrence does not mutate future occurrences.
- Rotation deterministic and auditable; exceptions, swaps, missed chores, timezone changes, and deleted members must not silently shift prior history.
- Idempotent completion and notification actions; no inflated progress from duplicate taps/retries.
- Offline writes and conflicting updates must be reconciled visibly; Firestore default last-write-wins is not sufficient for high-integrity transitions.
- Parent and child UX must be appropriately differentiated; assigned member can complete/ask for help, not self-approve controlled tasks.
- All completion and progress figures derive from actual stored state; no fake statistics or inert controls.

## Engineering and design expectations
- Feature-first modular Flutter architecture (presentation, domain, data) with testable services and repositories.
- Mobile-native responsive UI, safe areas, scaling, semantics, reduced motion, clear states and accessible contrast.
- Use references for **hierarchy, color discipline, rounded cards, calendar layouts, and original illustration direction**, not literal copying.
- No unreviewed AI-generated legal, parenting, safety, or child-development advice.
- Scope based on phase gates; avoid bonus AI, banking, location tracking, family chat, social feed, intrusive leaderboard, or advertising directed at children.
