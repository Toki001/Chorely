# ADR-001 — Proposed Flutter + Managed Backend

**Status:** ACCEPTED for local development (2026-10-29); live services not provisioned. See ADR-002 for pinned runtime and boundary decisions.

## Context
Multi-device households with parent/child permissions, real-time chore completion and notifications need server authorization and reliable collaboration. Offline-only storage doesn't support the core need. An enterprise-grade custom backend would increase complexity and operating burden.

## Decision
Start with Flutter/Dart + Firestore/Firebase Auth/Cloud Functions/FCM, with Riverpod/GoRouter/isolated domain and tests. Use explicitly scoped guardian-approved child profiles and device-pairing functions; do not assume Firebase anonymous authentication automatically solves permissions.

## Consequences
Pros: fast cross-platform development, real-time listeners, emulator suite, offline caching. Risks: Firestore last-write-wins, usage fees, vendor lock-in, permission complexity, APNs provisioning and children's privacy. Mitigate with server-mediated state machine, explicit offline outbox, rate limiting, cost alerts and privacy tests.

## Revisit if
Existing repo has a better verified stack; offline-first command protocol is impractical; app-store child targeting policy requires a different architecture; Firebase quotas/cost or country-specific requirements become unsuitable.
