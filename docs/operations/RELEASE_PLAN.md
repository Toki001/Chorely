# Chorely — CI/CD, Observability and Release Plan

## Environments
Separate development/staging/production backend projects with tenant-aware security. Never point tests to production family data. Use managed secrets and environment-configured IDs, not committed credentials.

## CI checks
Pull request: format → Flutter analyze → unit/widget/golden → backend emulator rules + function tests → secret & dependency scan → Android debug build where available. Main branch: release build and artifact integrity. iOS build on macOS runner if configured. Cache dependencies with lockfile hash, document Flutter/Xcode/JDK versions.

## Release preparation
- App display name Chorely, package/bundle IDs chosen after ownership check; privacy policy / terms / support; privacy manifests/data safety disclosures; screenshots and descriptions with **fictional family data only**.
- Android release signing and Play Console handled by authorized owner. iOS signing/certificates, APNs, TestFlight handled by authorized owner; **do not fabricate verification** when credentials unavailable.
- Permissions: notifications for chore reminders, camera only for optional avatar/QR/photo guidance, photo library optional; no default location/contacts collection.
- Review child audience policies carefully: adult-run family app with child profiles may trigger additional obligations. Whether to choose Kids Category needs actual product/market review.
- Prepare release notes, known limitations, export/delete process, security contact, incident-response ownership, dependency licenses and third-party illustration license manifest.

## Monitoring & incident handling
Track crash and API-error rates without child-sensitive telemetry. Redact PII; explain consent and opt-outs. Log functions failures, queue backlogs, duplicate notifications and permission denials. Establish incident severity/runbook, privacy breach escalation, and configuration rollback. Document data retention and restore strategy (secure tenant isolation).

## Cost controls
Define budget alerts and Firestore per-household quotas, write batching, paginated history and listener design; rate limit invites, FCM jobs, child-device pairing and repeated updates. Cloud usage and app-store fees may require user authorization.

## RC vs published
A verified RC = tests/builds/documentation passed but not necessarily store signed, reviewed or released. Published requires real store approvals and production rollout evidence. Never call partial infrastructure 'fully production ready'.
