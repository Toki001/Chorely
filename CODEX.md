# CODEX.md — Chorely Engineering Standards

## Objective
Build Chorely from repository discovery through an evidence-backed Android/iOS release candidate. Treat the design references as *inspiration*, the detailed product docs as specification, and the roadmap as an executable program of work.

## Definition of done
A milestone is **PASS** only when implemented behavior meets requirements; feature-relevant unit/widget/integration tests pass; app runs/builds on supported available platforms; auth and household-isolation checks pass when affected; accessibility and visual checks are recorded; docs/traceability updated; Git commit created. Otherwise mark FAIL/BLOCKED/NOT TESTED honestly.

## Development workflow
- Explore code before edits. Prefer incremental modifications and well-maintained packages.
- Choose tool versions from actual supported local environment, pin with lockfiles, document decisions.
- Architecture: domain models and use-cases independent of Flutter widgets, declarative state, repository boundary, isolate network and local cache.
- Favor deterministic UTC timestamps + household IANA timezone, with server timestamps for authority and explicit local display rules.
- Secure rules/functions > client-side conditional rendering. Always threat-model cross-household reads/writes and revoked memberships.
- No blanket `flutter test` success claims without including the exact command, count, platform and skipped tests.
- Update `docs/roadmap/PROGRESS.md` and `docs/verification/Mxx.md` after each milestone.
- Use scoped atomic commits; never commit personal files, secrets, unlicensed assets, generated machine noise, or cache.
- **Continue autonomously after milestone commit** while allowed execution is available.

## Prohibited substitutions
- Replacing backend sync with local-only mock data and calling multi-user done.
- Pretending notifications are delivered because local task logic ran.
- Static charts, fake progress percentages, nonfunctional buttons, placeholder sign-in, or canned family lists in release mode.
- Claiming testing on locked/inaccessible physical devices or on Apple hardware not available.
- Copying image reference screens or embedding third-party UI screenshots in app assets.
- Reusing/deleting original Loop app or its commit history without an explicit, separate user request.

## Commits
`M00: audit Chorely baseline` → `M01: finalize Chorely product specification` → ... per roadmap. If no .git exists, initialize safely. Do not push or publish without authorization.
