# Coding, Documentation and Dependency Standards

- Dart `analysis_options.yaml`: strict analyzer rules, consistent API naming, lint. Prefer immutable typed domain models, nullable correctness, reusable test fixtures.
- Errors typed by domain (`Unauthorized`, `Conflict`, `OfflinePending`, `NotFound`, `Validation`, `RateLimited`); UI maps to actionable text and safe fallback.
- Testable clock/UUID/randomness injection for recurrence and offline retries.
- User-visible strings localized from day one where practical; avoid hardcoded name/gender/age assumptions; semantics labels for controls.
- Separate repository interfaces and remote adapters; business use-cases can be tested without network or widget tree.
- Riverpod/other state solution should avoid hidden mutable singleton state and unnecessary global provider refreshes.
- Avoid unmaintained dependencies or direct copy of web-only components; inspect licenses and version compatibility.
- Code review checks for traceability ID, requirement, security implications, test proof, new permissions, asset licensing, migration and documentation impact.
- Keep architectural decisions in ADRs, changelog after verified milestone, and never silently prune production features without user intent.
- Security-sensitive functions have threat test; notification handlers never trust deep-link payload's household ownership.
